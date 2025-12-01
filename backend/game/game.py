import datetime
import dataclasses

import asyncpg
import random

import game.chat as chat
import types.chat
from types.chat import ChatType
from events.chat import ChatSystem
from game.system import System
from types.game import GameStatus


@dataclasses.dataclass
class GameEvent:
    game_id: int

@dataclasses.dataclass
class GameStatusEvent(GameEvent):
    new_status: GameStatus

@dataclasses.dataclass
class GameChatEvent(GameEvent):
    chat_type: ChatType
    owner_id: int | None
    event: types.chat.ChatEvent

@dataclasses.dataclass
class PlayerJoinedEvent(GameEvent):
    player_id: int

@dataclasses.dataclass
class PlayerLeftEvent(GameEvent):
    player_id: int

@dataclasses.dataclass
class PlayerKickedEvent(GameEvent):
    player_id: int

@dataclasses.dataclass
class PlayerPromotedEvent(GameEvent):
    old_host: int
    new_host: int

@dataclasses.dataclass
class PlayerReadyEvent(GameEvent):
    player_id: int
    ready: bool

@dataclasses.dataclass
class PlayerSpectatorEvent(GameEvent):
    player_id: int
    spectator: bool


class Game(System[GameEvent]):
    games_by_id = {}

    def __init__(self, id_: int):
        super().__init__()
        self.id = id_
        Game.games_by_id[id_] = self

    @staticmethod
    def get_by_id(id_: int) -> Game | None:
        return Game.games_by_id.get(id_)

    async def stop(self):
        await super().stop()

    async def forward_chat_events(self, chat_: ChatSystem, type_: ChatType, owner_id: int | None):
        async for event in chat_.listen():
            self.emit(GameChatEvent(self.id, type_, owner_id, event))

    @staticmethod
    async def create_game(
            conn: asyncpg.Connection,
            host_id: int,
            world_id: int,
            name: str,
            public: bool,
            max_players: int,
    ) -> Game | None:
        async with conn.transaction(isolation="serializable"):
            while True:
                code: str = "".join(random.choices("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789", k=4))

                if await conn.fetchval(
                    """
                    SELECT id
                    FROM games
                    WHERE code = $1
                    """,
                    code,
                ) is None:
                    break

            id_ = await conn.fetchval(
                """
                SE
                WITH create_game AS (
                    INSERT INTO games (host_id, world_id, name, public, max_players, code, status, created_at, state)
                        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
                        RETURNING id
                )
                INSERT INTO game_players (game_id, user_id, is_ready, is_host, is_spectator, joined_at)
                    SELECT id, $1, false, true, false, $8 FROM create_game
                    RETURNING id 
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

            if id_ is None:
                return None

            room_chat = await ChatSystem.create_new(conn, id_, ChatType.ROOM)

            game = Game(id_, room_chat)
            game.emit(GameStatusEvent(id_, GameStatus.WAITING))
            return game

    @staticmethod
    async def set_ready(conn: asyncpg.Connection, user_id: int, ready: bool) -> bool:
        with conn.transaction():
            game_id = await conn.fetchval(
                """
                UPDATE game_players
                SET is_ready = $2
                WHERE user_id = $1
                RETURNING game_id
                """,
                user_id,
                ready,
            )

            if game_id is None:
                return False

            Game.get_by_id(game_id).emit(PlayerReadyEvent(game_id=game_id, player_id=user_id, ready=ready))

            return True
