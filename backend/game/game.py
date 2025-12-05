import dataclasses

import asyncpg

import game.chat
from game.chat import ChatSystem
from lstypes.chat import ChatType
from game.system import System
from lstypes.game import GameStatus


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
    event: game.chat.ChatEvent


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


class GameSystem(System[GameEvent]):
    def __init__(
            self,
            id_: int,
            room_chat: ChatSystem,
    ):
        super().__init__(id_)
        self.room_chat = room_chat
        self.add_pipe(self.forward_chat_events(room_chat, ChatType.ROOM, None))

    async def stop(self):
        await self.room_chat.stop()
        await super().stop()

    async def forward_chat_events(self, chat_: ChatSystem, type_: ChatType, owner_id: int | None):
        async for event in chat_.listen():
            self.emit(GameChatEvent(self.id, type_, owner_id, event))

    @staticmethod
    async def set_ready(conn: asyncpg.Connection, user_id: int, ready: bool) -> bool:
        async with conn.transaction():
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

            GameSystem.of(game_id).emit(PlayerReadyEvent(game_id=game_id, player_id=user_id, ready=ready))

            return True
