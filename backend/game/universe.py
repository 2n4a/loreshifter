import dataclasses
import datetime
import random
import typing
from typing import Literal

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
        return await conn.fetchval(
            "SELECT EXISTS (SELECT 1 FROM worlds WHERE id = $1)",
            world_id
        )

    @staticmethod
    async def check_world_exists_not_deleted(conn: asyncpg.Connection, world_id: int):
        return await conn.fetchval(
            "SELECT EXISTS (SELECT 1 FROM worlds WHERE id = $1 AND NOT deleted)",
            world_id
        )

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

                now = datetime.datetime.now()

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
                    now,
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

                host = UserOut(
                    id=row["host_id"],
                    name=row["host_name"],
                    created_at=row["host_created_at"],
                    deleted=row["host_deleted"],
                )

                game = GameOut(
                    id=id_,
                    code=code,
                    public=public,
                    name=name,
                    world=Universe.row_to_short_world_out(row),
                    host_id=host_id,
                    players=[
                        PlayerOut(
                            user=host,
                            is_ready=False,
                            is_host=True,
                            is_spectator=False,
                            is_joined=True,
                            joined_at=now,
                        )
                    ],
                    created_at=now,
                    max_players=max_players,
                    status=GameStatus.WAITING,
                )

                game_system = await GameSystem.create_new(
                    conn,
                    game,
                )

                self.add_game(game_system)
                game_system.emit(GameStatusEvent(id_, GameStatus.WAITING))

                return game

        except asyncpg.DeadlockDetectedError as e:
            return await error(
                "SERVER_ERROR",
                "Failed to create the game due to transaction failure",
                cause=e,
                log=log,
            )

    @staticmethod
    async def get_worlds(
            conn: asyncpg.Connection,
            limit: int,
            offset: int,
            sort: Literal["asc", "desc"],
            # order: Literal["lastUpdatedAt"] = "lastUpdatedAt",
            # search: str | None = None,
            public: bool = False,
            # filter_: str | None = None,
            requester_id: int | None = None,
            log = gl_log,

    ) -> list[WorldOut] | ServiceError:
        log = log.bind(limit=limit, offset=offset, sort=sort)
        rows = await conn.fetch(
            f"""
            SELECT
                w.id, w.name, w.owner_id, w.public, w.description, w.created_at, w.last_updated_at, w.deleted,
                o.name as owner_name, o.created_at as owner_created_at, o.deleted as owner_deleted
            FROM worlds AS w
            JOIN users AS o ON w.owner_id = o.id
            WHERE w.public OR (w.owner_id = $3 AND NOT $4) AND NOT w.deleted
            ORDER BY last_updated_at {'ASC' if sort == 'asc' else 'DESC'}
            LIMIT $1 OFFSET $2
            """,
            limit,
            offset,
            requester_id if requester_id is not None else -1,
            public,
        )

        await log.ainfo("Fetching worlds: got %s worlds", len(rows))

        worlds = []
        for row in rows:
            worlds.append(WorldOut(
                id=row["id"],
                name=row["name"],
                public=row["public"],
                owner=UserOut(
                    id=row["owner_id"],
                    name=row["owner_name"],
                    created_at=row["owner_created_at"],
                    deleted=row["owner_deleted"],
                ),
                description=row["description"],
                data=None,
                created_at=row["created_at"],
                last_updated_at=row["last_updated_at"],
                deleted=row["deleted"],
            ))

        return worlds

    @staticmethod
    async def get_world(
            conn: asyncpg.Connection,
            id_: int,
            requester_user_id: int | None = None,
            log = gl_log,
    ) -> WorldOut | ServiceError:
        log = log.bind(id=id_)

        row = await conn.fetchrow(
            f"""
            SELECT
                w.id, w.name, w.owner_id, w.public, w.description, w.created_at, w.last_updated_at, w.deleted,
                w.data,
                o.name as owner_name, o.created_at as owner_created_at, o.deleted as owner_deleted
            FROM worlds AS w
            JOIN users AS o ON w.owner_id = o.id
            WHERE w.id = $1 AND (w.public OR w.owner_id = $2) AND NOT w.deleted
            """,
            id_,
            requester_user_id if requester_user_id is not None else -1,
        )

        if row is None:
            return await error(
                "WORLD_NOT_FOUND",
                "World with given id not found",
                id=id_,
                log=log,
            )

        await log.ainfo("Fetched world with id %s", id_)

        return WorldOut(
            id=row["id"],
            name=row["name"],
            public=row["public"],
            owner=UserOut(
                id=row["owner_id"],
                name=row["owner_name"],
                created_at=row["owner_created_at"],
                deleted=row["owner_deleted"],
            ),
            description=row["description"],
            data=row["data"],
            created_at=row["created_at"],
            last_updated_at=row["last_updated_at"],
            deleted=row["deleted"],
        )

    @staticmethod
    def game_from_row(row) -> GameOut:
        return GameOut(
            id=row["id"],
            code=row["code"],
            public=row["public"],
            name=row["name"],
            world=Universe.row_to_short_world_out(row),
            host_id=row["host_id"],
            players=[PlayerOut(
                user=UserOut(
                    id=p["user"]["id"],
                    name=p["user"]["name"],
                    created_at=p["user"]["created_at"],
                    deleted=p["user"]["deleted"],
                ),
                is_ready=p["is_ready"],
                is_host=p["is_host"],
                is_spectator=p["is_spectator"],
                is_joined=p["is_joined"],
                joined_at=datetime.datetime.fromisoformat(p["joined_at"]),
            ) for p in (row["players"] or [])],
            created_at=row["created_at"],
            max_players=row["max_players"],
            status=row["status"],
        )

    @staticmethod
    def row_to_short_world_out(row) -> ShortWorldOut:
        return ShortWorldOut(
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
        )

    @staticmethod
    async def get_games(
            conn: asyncpg.Connection,
            limit: int,
            offset: int,
            order: Literal["createdAt"] = "createdAt",
            sort: Literal["asc", "desc"] = "desc",
            public: bool = False,
            requester_id: int | None = None,
            include_archived: bool = False,
            log=gl_log,
    ) -> list[GameOut] | ServiceError:
        log = log.bind(limit=limit, offset=offset, sort=sort, order=order, public=public, requester_id=requester_id)

        rows = await conn.fetch(
            f"""
            SELECT
                g.id, g.code, g.public, g.name, g.host_id, g.max_players, g.status, g.created_at,
                w.id as world_id, w.name as world_name, w.public as world_public, w.description as world_description,
                w.created_at as world_created_at, w.last_updated_at as world_last_updated_at, w.deleted as world_deleted,
                wo.id as world_owner_id, wo.name as world_owner_name,
                wo.created_at as world_owner_created_at, wo.deleted as world_owner_deleted,
                gp.players
            FROM games AS g
            JOIN worlds AS w ON g.world_id = w.id
            JOIN users AS wo ON w.owner_id = wo.id
            LEFT JOIN game_players_agg_view AS gp ON g.id = gp.game_id
            WHERE
                (g.public IS TRUE OR (g.id IN (SELECT game_id FROM game_players WHERE user_id = $3)))
                AND (g.public OR NOT $4)
                AND (g.status != 'archived' OR $5)
            ORDER BY g.created_at {'ASC' if sort == 'asc' else 'DESC'}
            LIMIT $1 OFFSET $2
            """,
            limit,
            offset,
            requester_id if requester_id is not None else -1,
            public,
            include_archived,
        )

        await log.ainfo("Fetching games: got %s games", len(rows))

        games = []
        for row in rows:
            games.append(Universe.game_from_row(row))

        return games

    @staticmethod
    async def get_game(
            conn: asyncpg.Connection,
            game_id: int,
            requester_id: int | None = None,
            log=gl_log,
    ) -> GameOut | ServiceError:
        log = log.bind(game_id=game_id, requester_id=requester_id)

        row = await conn.fetchrow(
            f"""
            SELECT
                g.id, g.code, g.public, g.name, g.host_id, g.max_players, g.status, g.created_at,
                w.id as world_id, w.name as world_name, w.public as world_public, w.description as world_description,
                w.created_at as world_created_at, w.last_updated_at as world_last_updated_at, w.deleted as world_deleted,
                wo.id as world_owner_id, wo.name as world_owner_name,
                wo.created_at as world_owner_created_at, wo.deleted as world_owner_deleted,
                gp.players
            FROM games AS g
            JOIN worlds AS w ON g.world_id = w.id
            JOIN users AS wo ON w.owner_id = wo.id
            LEFT JOIN game_players_agg_view AS gp ON g.id = gp.game_id
            WHERE
                g.id = $1
                AND (g.public IS TRUE OR (g.id IN (SELECT game_id FROM game_players WHERE user_id = $2)))
            """,
            game_id,
            requester_id if requester_id is not None else -1,
        )

        if row is None:
            return await error(
                "GAME_NOT_FOUND",
                "Game with given id not found",
                game_id=game_id,
                log=log,
            )

        await log.ainfo("Fetching game: got 1 game")

        return Universe.game_from_row(row)

    @staticmethod
    async def get_game_by_code(
            conn: asyncpg.Connection,
            game_code: str,
            requester_id: int | None = None,
            log=gl_log,
    ) -> GameOut | ServiceError:
        log = log.bind(game_code=game_code, requester_id=requester_id)

        row = await conn.fetchrow(
            f"""
            SELECT
                g.id, g.code, g.public, g.name, g.host_id, g.max_players, g.status, g.created_at,
                w.id as world_id, w.name as world_name, w.public as world_public, w.description as world_description,
                w.created_at as world_created_at, w.last_updated_at as world_last_updated_at, w.deleted as world_deleted,
                wo.id as world_owner_id, wo.name as world_owner_name,
                wo.created_at as world_owner_created_at, wo.deleted as world_owner_deleted,
                gp.players
            FROM games AS g
            JOIN worlds AS w ON g.world_id = w.id
            JOIN users AS wo ON w.owner_id = wo.id
            LEFT JOIN game_players_agg_view AS gp ON g.id = gp.game_id
            WHERE
                g.code = $1
                AND g.status != 'archived'
            """,
            game_code,
        )

        if row is None:
            return await error(
                "GAME_NOT_FOUND",
                "Game with given code not found",
                game_code=game_code,
                log=log,
            )

        await log.ainfo("Fetching game by code: got 1 game %s", row["id"])

        return Universe.game_from_row(row)
