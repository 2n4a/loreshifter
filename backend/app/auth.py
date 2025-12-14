import abc
import dataclasses
import typing
import json
import base64
import urllib.parse

import httpx
from fastapi import HTTPException
from fastapi.encoders import jsonable_encoder
from jose import jwt
from fastapi import APIRouter
from fastapi.responses import JSONResponse
from starlette.requests import Request
from starlette.responses import RedirectResponse

import config
import game.user
from app.dependencies import Conn
from lstypes.error import (
    ServiceCode,
    ServiceError,
    raise_for_service_error,
    raise_service_error,
)

router = APIRouter()


SELF_URL = "http://localhost:8000"


def generate_jwt(payload: dict[str, typing.Any]):
    return jwt.encode(payload, config.JWT_SECRET, algorithm="HS256")


@dataclasses.dataclass
class UserData:
    auth_id: int
    name: str
    email: str


class AuthProvider(abc.ABC):
    def get_login_url(self, state: dict[str, typing.Any]): ...

    @property
    @abc.abstractmethod
    def provider_name(self): ...

    def redirect_url(self):
        return f"{SELF_URL}/api/v0/login/callback/{self.provider_name}"

    async def extract_state(self, data: dict[str, str]) -> dict[str, typing.Any]: ...

    async def exchange_for_token(self, data: dict[str, str]) -> str: ...

    async def fetch_user(self, token: str) -> UserData: ...


class GithubAuthProvider(AuthProvider):
    auth_url = "https://github.com/login/oauth/authorize"
    token_url = "https://github.com/login/oauth/access_token"
    user_api = "https://api.github.com/user"

    def __init__(self, *, client_id: str, client_secret: str):
        self.client_id = client_id
        self.client_secret = client_secret

    @property
    def provider_name(self):
        return "github"

    def get_login_url(self, state: dict[str, typing.Any]):
        state = base64.b64encode(json.dumps(state).encode()).decode()
        return (
            f"{self.auth_url}?"
            f"client_id={self.client_id}&"
            f"redirect_uri={urllib.parse.quote(self.redirect_url())}&"
            f"scope={urllib.parse.quote('read:user user:email')}&"
            f"state={urllib.parse.quote(state)}"
        )

    async def extract_state(self, data: dict[str, str]) -> dict[str, typing.Any]:
        state = data["state"]
        return json.loads(base64.b64decode(state).decode())

    async def exchange_for_token(self, data: dict[str, str]) -> str:
        code = data["code"]

        async with httpx.AsyncClient() as client:
            headers = {"Accept": "application/json"}
            payload = {
                "client_id": self.client_id,
                "client_secret": self.client_secret,
                "code": code,
                "redirect_uri": self.redirect_url(),
            }

            token_resp = await client.post(
                self.token_url, data=payload, headers=headers
            )

        if token_resp.status_code != 200:
            raise HTTPException(status_code=400, detail="Failed to obtain access token")

        data = token_resp.json()
        return data.get("access_token")

    async def fetch_user(self, token: str) -> UserData:
        async with httpx.AsyncClient() as client:
            headers = {"Authorization": f"Bearer {token}"}
            user_resp = await client.get(self.user_api, headers=headers)

        if user_resp.status_code != 200:
            raise HTTPException(
                status_code=400, detail="Failed to fetch GitHub profile"
            )

        data = user_resp.json()
        return UserData(
            auth_id=data["id"],
            name=data["name"],
            email=data["email"],
        )


AUTH_PROVIDERS = [
    GithubAuthProvider(
        client_id=config.OAUTH2_GITHUB_CLIENT_ID,
        client_secret=config.OAUTH2_GITHUB_CLIENT_SECRET,
    )
]


@router.get("/api/v0/login")
def login(provider: str, to: str | None = None, redirect: bool = False):
    for p in AUTH_PROVIDERS:
        if p.provider_name == provider:
            state = {}
            if to is not None:
                state["to"] = to
            login_url = p.get_login_url(state)
            if redirect:
                return RedirectResponse(login_url)
            return {"url": login_url}
    else:
        raise_service_error(400, ServiceCode.INVALID_PROVIDER, "Invalid provider")


@router.get("/api/v0/login/callback/{provider}")
async def login_callback(request: Request, conn: Conn, provider: str):
    for p in AUTH_PROVIDERS:
        if p.provider_name == provider:
            params = {k: v for k, v in request.query_params.items()}
            token = await p.exchange_for_token(params)
            state = await p.extract_state(params)
            profile = await p.fetch_user(token)
            user = await game.user.get_or_create_user(
                conn, profile.name, profile.email, profile.auth_id
            )
            if isinstance(user, ServiceError):
                raise_for_service_error(user)

            jwt_token = generate_jwt(
                {
                    "auth_id": profile.auth_id,
                    "id": user.id,
                }
            )

            secure = config.ENVIRONMENT == "prod"
            if "to" in state:
                response = RedirectResponse(state["to"])
                response.set_cookie("session", jwt_token, secure=secure, httponly=True)
                return response

            response = JSONResponse(
                {"token": jwt_token, "user": jsonable_encoder(user)}
            )
            response.set_cookie("session", jwt_token, secure=secure, httponly=True)
            return response
    else:
        raise_service_error(400, ServiceCode.INVALID_PROVIDER, "Invalid provider")


@router.get("/api/v0/logout")
def logout():
    response = JSONResponse({})
    response.delete_cookie("session")
    return response


@router.get("/api/v0/test-login")
async def test_login(
    conn: Conn, name: str | None = None, email: str | None = None, to: str | None = None
):
    user = await game.user.create_test_user(conn, name, email)
    jwt_token = generate_jwt(
        {
            "auth_id": None,
            "id": user.id,
            "test": True,
        }
    )
    secure = config.ENVIRONMENT == "prod"
    if to is not None:
        response = RedirectResponse(to)
        response.set_cookie("session", jwt_token, secure=secure, httponly=True)
        return response
    else:
        response = JSONResponse({"token": jwt_token, "user": jsonable_encoder(user)})
        response.set_cookie("session", jwt_token, secure=secure, httponly=True)
        return response
