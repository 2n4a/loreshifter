import dataclasses
import datetime
import typing

import asyncpg

from game.game import GameEvent
from types.world import WorldOut
from game.system import System


@dataclasses.dataclass
class UniverseEvent:
    ...

@dataclasses.dataclass()
class UniverseGameEvent(UniverseEvent):
    event: GameEvent

@dataclasses.dataclass()
class UniverseNewWorldEvent(UniverseEvent):
    world: WorldOut

@dataclasses.dataclass()
class UniverseWorldUpdateEvent(UniverseEvent):
    world: WorldOut


class Universe(System[UniverseEvent]):
    def __init__(self):
        super().__init__()

    async def stop(self):
        await super().stop()

    async def create_world(
            self,
            conn: asyncpg.Connection,
            name: str,
            owner_id: int,
            public: bool,
            description: str | None = None,
            data: typing.Any = None,
    ) -> WorldOut:
        id_ = await conn.fetchval(
            """
            INSERT
            INTO worlds (
                name, public, owner_id, description, data,
                created_at, last_updated_at, deleted
            )
            VALUES ($1, $2, $3, $4, $5, $6, $6, false)
            RETURNING id
            """,
            name,
            public,
            owner_id,
            description,
            data,
            datetime.datetime.now()
        )

        world = WorldOut(
            id=id_,
            name=name,
            owner_id=owner_id,
            public=public,
            description=description,
            data=data,
            created_at=datetime.datetime.now(),
            last_updated_at=datetime.datetime.now(),
            deleted=False,
        )
        self.emit(UniverseNewWorldEvent(world))
        return world

    async def set_ready(self, conn: asyncpg.Connection, user_id: int, ready: bool) -> bool:
        ...
