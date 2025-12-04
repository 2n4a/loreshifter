import asyncio
import dataclasses
import os
import typing
from contextlib import asynccontextmanager
from typing import Annotated

import asyncpg
from fastapi import Depends, FastAPI, HTTPException
from fastapi.params import Cookie, Header

import game.user
from app.events import WebSocketController
from game.user import UserOut
from game.universe import Universe

from jose import jwt

from types.utils import PgEnum

PG_DSN = os.environ.get("POSTGRES_URL", "postgres://devuser:devpass@localhost:5432/devdb")
JWT_SECRET = os.environ.get("JWT_SECRET")


@dataclasses.dataclass
class AppState:
    pg_pool: asyncpg.Pool
    universe: Universe
    ws_controller: WebSocketController


state: AppState | None = None


async def get_db():
    if state is None:
        raise Exception("State is not initialized")
    async with state.pg_pool.acquire() as conn:
        yield conn


Conn = Annotated[asyncpg.Connection, Depends(get_db)]


async def get_universe():
    if state is None:
        raise Exception("State is not initialized")
    return state.universe


U = Annotated[Universe, Depends(get_universe)]


async def get_jwt(
        session: Annotated[str | None, Cookie()] = None,
        authentication: Annotated[str | None, Header()] = None,
) -> dict[str, typing.Any] | None:
    if session is not None:
        try:
            return jwt.decode(session, JWT_SECRET, algorithms=["HS256"])
        except jwt.JWTError:
            pass
    if authentication is not None:
        try:
            return jwt.decode(authentication, JWT_SECRET, algorithms=["HS256"])
        except jwt.JWTError:
            pass
    return None


async def get_user(
        conn: Conn,
        jwt_: Annotated[dict[str, typing.Any] | None, Depends(get_jwt)]
) -> UserOut | None:
    if not jwt_:
        return None
    return await game.user.get_user_by_auth_id(conn, jwt_["auth_id"])


async def get_user_or_401(
        conn: Conn,
        jwt_: Annotated[dict[str, typing.Any] | None, Depends(get_jwt)]
) -> UserOut:
    if not jwt_:
        raise HTTPException(status_code=401, detail="Not authenticated")
    user = await game.user.get_user_by_auth_id(conn, jwt_["auth_id"])
    if user is None:
        raise HTTPException(status_code=401, detail="Not authenticated")
    return user


UserDep = Annotated[UserOut | None, Depends(get_user)]
AuthDep = Annotated[UserOut, Depends(get_user_or_401)]


async def init_connection(conn: asyncpg.Connection):
    await PgEnum.register_all(conn)


@asynccontextmanager
async def livespan(_app: FastAPI):
    global state
    async with asyncpg.create_pool(dsn=PG_DSN, init=init_connection) as pg_pool:
        universe = Universe()
        ws_controller = WebSocketController()
        async with asyncio.TaskGroup() as bg_tasks:
            bg_tasks.create_task(ws_controller.listen(universe))

            state = AppState(
                pg_pool=pg_pool,
                universe=universe,
                ws_controller=ws_controller,
            )

            yield

            await universe.stop()
            state = None
