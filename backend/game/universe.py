import dataclasses
import datetime
import random
import typing

import asyncpg

from game.chat import ChatSystem
from game.logger import gl_log
from game.user import check_user_exists
from lstypes.chat import ChatType
from game.game import GameSystem, GameEvent, GameStatusEvent
from lstypes.error import ServiceError, error
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
            log = gl_log,
    ) -> WorldOut | ServiceError:
        log = log.bind(world_name=name, world_owner_id=owner_id, world_public=public)

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

        if row is None:
            if check_user_exists(conn, owner_id):
                return await error(
                    "USER_NOT_FOUND",
                    "User not found",
                    log=log,
                )
            return await error(
                "SERVER_ERROR",
                "Failed to create the world",
                log=log,
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

    @staticmethod
    async def check_world_exists(conn: asyncpg.Connection, world_id: int):
        return await conn.fetchval("SELECT EXISTS (SELECT 1 FROM worlds WHERE id = $1)", world_id)

    async def create_game(
            self,
            conn: asyncpg.Connection,
            host_id: int,
            world_id: int,
            name: str,
            public: bool,
            max_players: int,
            log=gl_log,
    ) -> GameOut | ServiceError:
        log = log.bind(
            game_host_id=host_id, game_world_id=world_id, game_name=name,
            game_public=public, game_max_players=max_players
        )
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
                        await log.ainfo("Creating new world with code %s", code)
                        break
                log = log.bind(game_code=code)

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
                        SELECT h.id, w.id, $3, $4, $5, $6, $7, $8, w.initial_state
                        FROM w, h
                        RETURNING id
                    ), create_player AS (
                        INSERT INTO game_players
                            (game_id, user_id, is_ready, is_spectator, is_joined, joined_at)
                            SELECT create_game.id, $1, false, false, true, $8 FROM create_game
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
                    if not await check_user_exists(conn, host_id):
                        return await error(
                            "USER_NOT_FOUND",
                            "Host user not found",
                            user_id=host_id,
                            log=log,
                        )
                    if not await self.check_world_exists(conn, world_id):
                        return await error(
                            "WORLD_NOT_FOUND",
                            "World not found",
                            world_id=world_id,
                            log=log,
                        )
                    return await error(
                        "SERVER_ERROR",
                        "Failed to create the game",
                        log=log,
                    )

                id_ = row["game_id"]
                log = log.bind(game_id=id_)

                await log.ainfo("Created new game")

                room_chat = await ChatSystem.create_new(conn, id_, ChatType.ROOM, log=log)

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
            return await error(
                "SERVER_ERROR",
                "Failed to create the game due to transaction failure",
                cause=e,
                log=log,
            )
