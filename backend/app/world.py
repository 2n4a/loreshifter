import typing
from typing import Literal, Annotated

from fastapi import APIRouter
from fastapi.params import Query
from pydantic import BaseModel

from app.dependencies import Conn, AuthDep, U, Log, UserDep
from lstypes.error import ServiceError
from lstypes.world import WorldOut

router = APIRouter()


class WorldIn(BaseModel):
    name: str = "Untitled world"
    public: bool = True
    description: str | None = None
    data: typing.Any = None


@router.post("/api/v0/world")
async def post_world(
        conn: Conn,
        universe: U,
        user: AuthDep,
        log: Log,
        world: WorldIn,
) -> WorldOut | ServiceError:
    return await universe.create_world(
        conn,
        world.name,
        user.id,
        world.public,
        world.description,
        world.data,
        log=log,
    )


@router.get("/api/v0/world")
async def get_worlds(
        conn: Conn,
        universe: U,
        log: Log,
        limit: Annotated[int, Query(ge=1, le=100)] = 25,
        offset: int = 0,
        sort: Literal["lastUpdatedAt"] = "lastUpdatedAt",
        order: Literal["asc", "desc"] = "asc",
        search: Annotated[str, Query(max_length=50)] | None = None,
        public: bool | None = None,
        filter_: Annotated[str, Query(max_length=50)] | None = None,
) -> list[WorldOut] | ServiceError:
    _ = sort
    _ = public
    _ = search
    _ = filter_
    return await universe.get_worlds(
        conn, limit, offset, order, log=log
    )


@router.get("/api/v0/world/{id_}")
async def get_world(
        conn: Conn,
        universe: U,
        user: UserDep,
        log: Log,
        id_: int,
) -> WorldOut | ServiceError:
    return await universe.get_world(
        conn,
        user.id if user else None,
        id_,
        log=log
    )
