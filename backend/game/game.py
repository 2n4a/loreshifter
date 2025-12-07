import dataclasses

import asyncpg

import game.chat
from game.chat import ChatSystem
from game.logger import gl_log
from lstypes.chat import ChatType
from game.system import System
from lstypes.error import error, ServiceError
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

    async def set_ready(
            self,
            conn: asyncpg.Connection,
            user_id: int,
            ready: bool,
            log = gl_log
    ) -> None | ServiceError:
        log = log.bind(game_id=self.id, user_id=user_id)
        async with conn.transaction():
            await log.ainfo("Setting ready status", ready=ready)

            game_id = await conn.fetchval(
                """
                UPDATE game_players
                SET is_ready = $3
                WHERE user_id = $1 AND game_id = $2
                RETURNING game_id
                """,
                user_id,
                self.id,
                ready,
            )

            if game_id is None:
                return await error('PLAYER_NOT_FOUND', "Player not found", log=log)

            self.emit(PlayerReadyEvent(game_id=game_id, player_id=user_id, ready=ready))

            return None
