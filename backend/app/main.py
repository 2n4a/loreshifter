import dotenv
from starlette.middleware.cors import CORSMiddleware
from starlette.responses import HTMLResponse
import typing
from starlette.routing import Match

import config
from jose import jwt
from app.dependencies import livespan, state



dotenv.load_dotenv()

from app.auth import router as auth_router
from app.user import router as user_router
from app.game import router as game_router
from app.world import router as world_router
from fastapi import FastAPI
from fastapi.responses import JSONResponse
from starlette.requests import Request
import uvicorn
from pathlib import Path

from app.dependencies import livespan
from lstypes.error import ServiceErrorException
import config

app = FastAPI(lifespan=livespan)




app.include_router(auth_router)
app.include_router(user_router)
app.include_router(game_router)
app.include_router(world_router)

def _route_key(request: Request) -> str:
    """
    Нормализуем ключ как: 'METHOD /api/v0/game/{game_id}/chat/{chat_id}/send'
    Чтобы не плодить бакеты на каждый конкретный game_id.
    """
    scope = request.scope
    for r in app.router.routes:
        match, _child = r.matches(scope)
        if match == Match.FULL:
            path_tmpl = getattr(r, "path", request.url.path)
            return f"{request.method} {path_tmpl}"
    return f"{request.method} {request.url.path}"


def _user_id_from_request(request: Request) -> int | None:
    if not config.JWT_SECRET:
        return None

    tokens: list[str] = []

    auth = request.headers.get("authorization")
    if auth:
        a = auth.strip()
        if a.lower().startswith("bearer "):
            a = a[7:].strip()
        if a:
            tokens.append(a)

    authentication = request.headers.get("authentication")
    if authentication:
        a = authentication.strip()
        if a:
            tokens.append(a)

    session = request.cookies.get("session")
    if session:
        tokens.append(session)

    for token in tokens:
        try:
            payload = jwt.decode(token, config.JWT_SECRET, algorithms=["HS256"])
            uid = payload.get("id")
            if isinstance(uid, int):
                return uid
            if isinstance(uid, str) and uid.isdigit():
                return int(uid)
        except Exception:
            continue

    return None

@app.middleware("http")
async def rate_limit_middleware(request: Request, call_next):
    if state is None:
        return await call_next(request)

    route_key = _route_key(request)
    user_id = _user_id_from_request(request)

    ok = await state.limiter.check_and_consume(route_key=route_key, user_id=user_id)
    if not ok:
        return JSONResponse(
            status_code=429,
            content={
                "code": "TOO_MANY_REQUESTS",
                "message": "Too Many Requests",
                "details": {"route": route_key, "user_id": user_id},
            },
        )

    return await call_next(request)



@app.exception_handler(ServiceErrorException)
async def service_error_exception_handler(
    _request: Request, exc: ServiceErrorException
):
    return JSONResponse(
        status_code=exc.status_code, content=exc.error.model_dump(mode="json")
    )


app.add_middleware(
    CORSMiddleware,
    allow_origins=config.CORS_ALLOW_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/api/v0/liveness")
def liveness():
    return {}


@app.get("/playtest")
def playtest(players: int = 1):
    return HTMLResponse(content=Path("static/playtest.html").read_text("utf-8"))


def main():
    uvicorn.run(app, host="0.0.0.0", port=8000)


if __name__ == "__main__":
    main()
