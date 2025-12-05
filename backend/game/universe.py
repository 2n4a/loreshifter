import dataclasses
import datetime
import random
import typing

import asyncpg

from game.chat import ChatSystem
from lstypes.chat import ChatType
from game.game import GameSystem, GameEvent, GameStatusEvent
from lstypes.game import GameStatus, GameOut
from lstypes.player import PlayerOut
from lstypes.user import UserOut
from lstypes.world import WorldOut, ShortWorldOut
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


class Universe(System[UniverseEvent, None]):
    def __init__(self):
        super().__init__(None)
        self.games = []

    async def stop(self):
        for game in self.games:
            await game.stop()
        await super().stop()

    def add_game(self, game: GameSystem):
        async def forward_game_events():
            async for event in game.listen():
                self.emit(UniverseGameEvent(event))

        self.games.append(game)
        self.add_pipe(forward_game_events())

    async def create_world(
            self,
            conn: asyncpg.Connection,
            name: str,
            owner_id: int,
            public: bool,
            description: str | None = None,
            data: typing.Any = None,
    ) -> WorldOut:
        if data is None:
            data = {"initialState": {}}

        now = datetime.datetime.now()

        row = await conn.fetchrow(
            """
            WITH owner AS (
                SELECT id, name, created_at, deleted
                FROM users
                WHERE id = $3
            ), new_world AS (
                INSERT INTO worlds (
                    name, public, owner_id, description, data,
                    created_at, last_updated_at, deleted
                ) VALUES 
                      ($1, $2, $3, $4, $5, $6, $6, false)
                RETURNING id
            ) SELECT
                new_world.id, owner.id as owner_id, owner.name as owner_name,
                owner.created_at as owner_created_at, owner.deleted as owner_deleted
            FROM new_world, owner
            """,
            name,
            public,
            owner_id,
            description,
            data,
            now,
        )

        world = WorldOut(
            id=row["id"],
            name=name,
            owner=UserOut(
                id=row["owner_id"],
                name=row["owner_name"],
                created_at=row["owner_created_at"],
                deleted=row["owner_deleted"],
            ),
            public=public,
            description=description,
            data=data,
            created_at=now,
            last_updated_at=now,
            deleted=False,
        )
        self.emit(UniverseNewWorldEvent(world))
        return world

    async def create_game(
            self,
            conn: asyncpg.Connection,
            host_id: int,
            world_id: int,
            name: str,
            public: bool,
            max_players: int,
    ) -> GameOut | None:
        try:
            async with conn.transaction(isolation="serializable"):
                while True:
                    code: str = "".join(random.choices("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789", k=4))
                    old_game_id = await conn.fetchval(
                        """
                        SELECT id FROM games WHERE code = $1 AND status != 'archived'
                        """,
                        code,
                    )
                    if old_game_id is None:
                        break

                row = await conn.fetchrow(
                    """
                    WITH w AS (
                        SELECT
                            id, name, owner_id, public, description,
                            created_at, last_updated_at, deleted,
                            data->'initialState' as initial_state
                        FROM worlds
                        WHERE id = $2
                    ), h AS (
                        SELECT id, name, created_at, deleted
                        FROM users
                        WHERE id = $1
                    ), wo AS (
                        SELECT id, name, created_at, deleted
                        FROM users
                        WHERE id = (SELECT owner_id FROM w)
                    ), create_game AS (
                        INSERT INTO games
                            (host_id, world_id, name, public, max_players, code, status, created_at, state)
                        SELECT $1, $2, $3, $4, $5, $6, $7, $8, w.initial_state
                        FROM w
                        RETURNING id
                    ), create_player AS (
                        INSERT INTO game_players
                            (game_id, user_id, is_ready, is_host, is_spectator, is_joined, joined_at)
                            SELECT create_game.id, $1, false, true, false, true, $8 FROM create_game
                    )
                    SELECT
                        create_game.id as game_id,
                        
                        wo.id as world_owner_id, wo.name as world_owner_name,
                        wo.created_at as world_owner_created_at, wo.deleted as world_owner_deleted,
                        
                        w.id as world_id, w.name as world_name,
                        w.public as world_public, w.description as world_description,
                        w.created_at as world_created_at, w.last_updated_at as world_last_updated_at,
                        w.deleted as world_deleted,
                        
                        h.id as host_id, h.name as host_name,
                        h.created_at as host_created_at, h.deleted as host_deleted

                    FROM create_game, h, w, wo
                    """,
                    host_id,
                    world_id,
                    name,
                    public,
                    max_players,
                    code,
                    GameStatus.WAITING,
                    datetime.datetime.now(),
                )

                if row is None:
                    return None

                id_ = row["game_id"]

                room_chat = await ChatSystem.create_new(conn, id_, ChatType.ROOM)

                game = GameSystem(id_, room_chat)
                self.add_game(game)
                game.emit(GameStatusEvent(id_, GameStatus.WAITING))

                return GameOut(
                    id=id_,
                    code=code,
                    public=public,
                    name=name,
                    world=ShortWorldOut(
                        id=row["world_id"],
                        name=row["world_name"],
                        owner=UserOut(
                            id=row["world_owner_id"],
                            name=row["world_owner_name"],
                            created_at=row["world_owner_created_at"],
                            deleted=row["world_owner_deleted"],
                        ),
                        public=row["world_public"],
                        description=row["world_description"],
                        created_at=row["world_created_at"],
                        last_updated_at=row["world_last_updated_at"],
                        deleted=row["world_deleted"],
                    ),
                    host_id=host_id,
                    players=[
                        PlayerOut(
                            user=UserOut(
                                id=row["host_id"],
                                name=row["host_name"],
                                created_at=row["host_created_at"],
                                deleted=row["host_deleted"],
                            ),
                            is_ready=False,
                            is_host=True,
                            is_spectator=False,
                        )
                    ],
                    created_at=datetime.datetime.now(),
                    max_players=max_players,
                    status=GameStatus.WAITING,
                )
        except asyncpg.DeadlockDetectedError as e:
            print("Failed to create game due to transaction failure:", e)
            return None



# row = await conn.fetchrow(
#     """
#     WITH world AS (
#         SELECT
#             id,
#             name,
#             owner_id,
#             public,
#             description,
#             created_at,
#             last_updated_at,
#             deleted,
#             data->'initialState' as initial_state,
#         FROM worlds
#         where id = $2
#     )
#     """,
#     host_id,
#     world_id,
#     name,
#     public,
#     max_players,
#     code,
#     GameStatus.WAITING,
#     datetime.datetime.now(),
# )