import datetime
import typing
from typing import Literal, Annotated

from fastapi import APIRouter
from fastapi.params import Query
from pydantic import BaseModel

from app.dependencies import Conn, AuthDep, U, Log, UserDep
from lstypes.error import ServiceCode, raise_service_error, unwrap
from lstypes.user import UserOut
from lstypes.world import WorldOut

router = APIRouter()


class WorldIn(BaseModel):
    name: str = "Untitled world"
    public: bool = True
    description: str | None = None
    data: typing.Any = None


class WorldUpdateIn(BaseModel):
    name: str | None = None
    public: bool | None = None
    description: str | None = None
    data: typing.Any = None


@router.post("/api/v0/world")
async def post_world(
    conn: Conn,
    universe: U,
    user: AuthDep,
    log: Log,
    world: WorldIn,
) -> WorldOut:
    return unwrap(
        await universe.create_world(
            conn,
            world.name,
            user.id,
            world.public,
            world.description,
            world.data,
            log=log,
        )
    )


@router.get("/api/v0/world")
async def get_worlds(
    conn: Conn,
    universe: U,
    user: UserDep,
    log: Log,
    limit: Annotated[int, Query(ge=1, le=100)] = 25,
    offset: int = 0,
    sort: Literal["lastUpdatedAt"] = "lastUpdatedAt",
    order: Literal["asc", "desc"] = "asc",
    search: Annotated[str, Query(max_length=50)] | None = None,
    public: bool | None = None,
    filter_: Annotated[str, Query(max_length=50)] | None = None,
) -> list[WorldOut]:
    _ = sort
    _ = search
    return unwrap(
        await universe.get_worlds(
            conn,
            limit,
            offset,
            order,
            public=(public is True),
            filter_=filter_,
            requester_id=user.id if user else None,
            log=log,
        )
    )


@router.get("/api/v0/world/{id_}")
async def get_world(
    conn: Conn,
    universe: U,
    user: UserDep,
    log: Log,
    id_: int,
) -> WorldOut:
    return unwrap(
        await universe.get_world(
            conn,
            id_,
            requester_user_id=user.id if user else None,
            log=log,
        )
    )


async def _get_world_row(conn: Conn, world_id: int):
    return await conn.fetchrow(
        """
        SELECT
            w.id, w.name, w.owner_id, w.public, w.description, w.data,
            w.created_at, w.last_updated_at, w.deleted,
            o.name as owner_name, o.created_at as owner_created_at, o.deleted as owner_deleted
        FROM worlds AS w
        JOIN users AS o ON w.owner_id = o.id
        WHERE w.id = $1 AND NOT w.deleted
        """,
        world_id,
    )


def _world_out_from_row(row) -> WorldOut:
    return WorldOut(
        id=row["id"],
        name=row["name"],
        owner=UserOut(
            id=row["owner_id"],
            name=row["owner_name"],
            created_at=row["owner_created_at"],
            deleted=row["owner_deleted"],
        ),
        public=row["public"],
        description=row["description"],
        data=row["data"],
        created_at=row["created_at"],
        last_updated_at=row["last_updated_at"],
        deleted=row["deleted"],
    )


@router.put("/api/v0/world/{id_}")
async def put_world(
    id_: int,
    conn: Conn,
    user: AuthDep,
    log: Log,
    world: WorldUpdateIn,
) -> WorldOut:
    _ = log
    row = await _get_world_row(conn, id_)
    if row is None:
        raise_service_error(404, ServiceCode.WORLD_NOT_FOUND, "World not found")

    if row["owner_id"] != user.id:
        if not row["public"]:
            raise_service_error(404, ServiceCode.WORLD_NOT_FOUND, "World not found")
        raise_service_error(401, ServiceCode.UNAUTHORIZED, "Not enough permissions")

    patch = world.model_dump(exclude_unset=True)
    if not patch:
        return _world_out_from_row(row)

    now = datetime.datetime.now()
    updated_row = await conn.fetchrow(
        """
        WITH updated AS (
            UPDATE worlds
            SET
                name = $2,
                public = $3,
                description = $4,
                data = $5,
                last_updated_at = $6
            WHERE id = $1
            RETURNING id, name, owner_id, public, description, data, created_at, last_updated_at, deleted
        )
        SELECT
            updated.*,
            o.name as owner_name, o.created_at as owner_created_at, o.deleted as owner_deleted
        FROM updated
        JOIN users AS o ON updated.owner_id = o.id
        """,
        id_,
        patch.get("name", row["name"]),
        patch.get("public", row["public"]),
        patch.get("description", row["description"]),
        patch.get("data", row["data"]),
        now,
    )
    if updated_row is None:
        raise_service_error(500, ServiceCode.SERVER_ERROR, "Failed to update world")
    return _world_out_from_row(updated_row)


@router.delete("/api/v0/world/{id_}")
async def delete_world(
    id_: int,
    conn: Conn,
    user: AuthDep,
    log: Log,
) -> WorldOut:
    _ = log
    row = await _get_world_row(conn, id_)
    if row is None:
        raise_service_error(404, ServiceCode.WORLD_NOT_FOUND, "World not found")

    if row["owner_id"] != user.id:
        if not row["public"]:
            raise_service_error(404, ServiceCode.WORLD_NOT_FOUND, "World not found")
        raise_service_error(401, ServiceCode.UNAUTHORIZED, "Not enough permissions")

    now = datetime.datetime.now()
    deleted_row = await conn.fetchrow(
        """
        WITH deleted_world AS (
            UPDATE worlds
            SET deleted = TRUE,
                last_updated_at = $2
            WHERE id = $1
            RETURNING id, name, owner_id, public, description, data, created_at, last_updated_at, deleted
        )
        SELECT
            deleted_world.*,
            o.name as owner_name, o.created_at as owner_created_at, o.deleted as owner_deleted
        FROM deleted_world
        JOIN users AS o ON deleted_world.owner_id = o.id
        """,
        id_,
        now,
    )
    if deleted_row is None:
        raise_service_error(500, ServiceCode.SERVER_ERROR, "Failed to delete world")
    return _world_out_from_row(deleted_row)


@router.post("/api/v0/world/{id_}/copy")
async def copy_world(
    id_: int,
    conn: Conn,
    universe: U,
    user: AuthDep,
    log: Log,
) -> WorldOut:
    original = unwrap(
        await universe.get_world(conn, id_, requester_user_id=user.id, log=log)
    )
    return unwrap(
        await universe.create_world(
            conn,
            original.name,
            user.id,
            original.public,
            original.description,
            original.data,
            log=log,
        )
    )
