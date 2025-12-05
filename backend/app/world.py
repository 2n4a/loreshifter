import typing

from fastapi import APIRouter
from pydantic import BaseModel

from app.dependencies import Conn, AuthDep, U
from lstypes.world import WorldOut

router = APIRouter()


class WorldIn(BaseModel):
    name: str = "Untitled world"
    public: bool = True
    description: str | None = None
    data: typing.Any = None


@router.post("/api/v0/world")
async def post_world(conn: Conn, universe: U, user: AuthDep, world: WorldIn) -> WorldOut:
    return await universe.create_world(
        conn, world.name, user.id, world.public, world.description, world.data
    )
