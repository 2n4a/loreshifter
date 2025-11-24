import datetime
import enum
import dataclasses

import asyncpg
import random

import game.chat as chat
from game.chat import ChatSystem, ChatType
from game.system import System
from game.utils import PgEnum

class GameStatus(enum.Enum, metaclass=PgEnum):
    __pg_enum_name__ = "game_status"
    WAITING = "waiting"
    PLAYING = "playing"
    FINISHED = "finished"
    ARCHIVED = "archived"


@dataclasses.dataclass
class GameEvent:
    game_id: int

@dataclasses.dataclass
class GameStatusEvent(GameEvent):
    game_id: int
    new_status: GameStatus

@dataclasses.dataclass
class GameChatEvent(GameEvent):
    chat_type: ChatType
    owner_id: int | None
    event: chat.ChatEvent

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
    def __init__(self, id_: int, room_chat: ChatSystem):
        super().__init__()
        self.id = id_
        self.room_chat: ChatSystem = room_chat
        self.add_pipe(self.forward_chat_events, self.room_chat, ChatType.ROOM, None)

    async def stop(self):
        await self.room_chat.stop()
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
        with conn.transaction(isolation="serializable"):
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
                WITH create_game AS (
                    INSERT INTO games (host_id, world_id, name, public, max_players, code, status, created_at)
                        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
                        RETURNING id
                )
                INSERT INTO game_players (game_id, user_id, is_ready, is_host, is_spectator, is_joined, joined_at)
                    VALUES (create_game.id, $1, false, true, false, true, $8)
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
