import asyncio
import contextlib
import dataclasses
import json
import typing
from contextlib import asynccontextmanager
from typing import Annotated

import asyncpg
import structlog
from fastapi import Depends, FastAPI
from fastapi.params import Cookie, Header
from structlog import BoundLogger

import config
import game.user
from app.ws import WebSocketController
from game.logger import gl_log
from lstypes.error import ServiceCode, ServiceError, raise_service_error
from lstypes.user import FullUserOut
from game.universe import Universe

from jose import jwt

from lstypes.utils import PgEnum


@dataclasses.dataclass
class AppState:
    pg_pool: asyncpg.Pool
    universe: Universe
    ws_controller: WebSocketController
    log: structlog.BoundLogger


state: AppState | None = None


async def get_conn():
    if state is None:
        raise Exception("State is not initialized")
    async with state.pg_pool.acquire() as conn:
        yield conn


Conn = Annotated[asyncpg.Connection, Depends(get_conn)]


async def get_universe():
    if state is None:
        raise Exception("State is not initialized")
    return state.universe


async def get_ws_controller():
    if state is None:
        raise Exception("State is not initialized")
    return state.ws_controller

U = Annotated[Universe, Depends(get_universe)]
W = Annotated[WebSocketController, Depends(get_ws_controller)]


async def get_jwt(
    session: Annotated[str | None, Cookie()] = None,
    authorization: Annotated[str | None, Header()] = None,
    authentication: Annotated[str | None, Header()] = None,
) -> dict[str, typing.Any] | None:
    if not config.JWT_SECRET:
        return None

    tokens: list[str] = []
    if session is not None:
        tokens.append(session)
    if authorization is not None:
        auth = authorization.strip()
        if auth.lower().startswith("bearer "):
            auth = auth[7:].strip()
        if auth:
            tokens.append(auth)
    if authentication is not None:
        auth = authentication.strip()
        if auth:
            tokens.append(auth)

    for token in tokens:
        try:
            return jwt.decode(token, config.JWT_SECRET, algorithms=["HS256"])
        except jwt.JWTError:
            continue
    return None


async def get_user(
    conn: Conn, jwt_: Annotated[dict[str, typing.Any] | None, Depends(get_jwt)]
) -> FullUserOut | None:
    if not jwt_:
        return None
    user = await game.user.get_user(conn, jwt_["id"], deleted_ok=False)
    if isinstance(user, ServiceError):
        return None
    return user


async def get_user_or_401(
    conn: Conn, jwt_: Annotated[dict[str, typing.Any] | None, Depends(get_jwt)]
) -> FullUserOut:
    if not jwt_:
        raise_service_error(401, ServiceCode.UNAUTHORIZED, "Not authenticated")
    user = await game.user.get_user(conn, jwt_["id"], deleted_ok=False)
    if isinstance(user, ServiceError):
        raise_service_error(401, ServiceCode.UNAUTHORIZED, "Not authenticated")
    return user


UserDep = Annotated[FullUserOut | None, Depends(get_user)]
AuthDep = Annotated[FullUserOut, Depends(get_user_or_401)]


async def get_log(
    user: UserDep,
    x_request_id: Annotated[str | None, Header()] = None,
) -> BoundLogger:
    if user is not None:
        return gl_log.bind(requester_id=user.id)
    if x_request_id is not None:
        return gl_log.bind(request_id=x_request_id)
    return state.log


Log = Annotated[BoundLogger, Depends(get_log)]


async def init_connection(conn: asyncpg.Connection):
    await conn.set_type_codec(
        "json", encoder=json.dumps, decoder=json.loads, schema="pg_catalog"
    )
    await conn.set_type_codec(
        "jsonb", encoder=json.dumps, decoder=json.loads, schema="pg_catalog"
    )
    await PgEnum.register_all(conn)


@asynccontextmanager
async def livespan(_app: FastAPI):
    global state
    log = gl_log.bind()
    async with asyncpg.create_pool(
        dsn=config.POSTGRES_URL, init=init_connection
    ) as pg_pool:
        universe = Universe()
        ws_controller = WebSocketController(pg_pool)
        async with asyncio.TaskGroup() as bg_tasks:
            bg_tasks.create_task(ws_controller.listen(universe))

            state = AppState(
                pg_pool=pg_pool,
                universe=universe,
                ws_controller=ws_controller,
                log=log,
            )

            yield

            await universe.stop()
            state = None
