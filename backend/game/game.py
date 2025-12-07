import dataclasses

import asyncpg

import game.chat
from game.chat import ChatSystem
from game.logger import gl_log
from lstypes.chat import ChatType
from game.system import System
from lstypes.error import error, ServiceError
from lstypes.game import GameStatus
from lstypes.user import UserOut


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


@dataclasses.dataclass
class Player:
    id: int
    user: UserOut
    is_joined: bool
    is_ready: bool
    is_spectator: bool


class GameSystem(System[GameEvent]):
    def __init__(
            self,
            id_: int,
            host: Player,
            room_chat: ChatSystem,
    ):
        super().__init__(id_)
        self.status = GameStatus.WAITING
        self.room_chat = room_chat
        self.add_pipe(self.forward_chat_events(room_chat, ChatType.ROOM, None))

        self.host_id: int = host.id
        self.player_states: dict[int, Player] = {}

    async def stop(self):
        await self.room_chat.stop()
        await super().stop()

    async def forward_chat_events(self, chat_: ChatSystem, type_: ChatType, owner_id: int | None):
        async for event in chat_.listen():
            self.emit(GameChatEvent(self.id, type_, owner_id, event))

    async def connect_player(
            self,
            conn: asyncpg.Connection,
            player_id: int,
            log=gl_log,
    ) -> None | ServiceError:
        # game is 'archived' -> no-op?
        # player in game_players, is_joined -> no-op
        # game is 'waiting', player not in game_players, players < max_players -> join as player
        # game is 'waiting', player not in game_players, players >= max_players -> join as spectator
        # game is 'waiting', player in game_players, !is_joined -> is_joined = true
        # game is 'playing' | 'finished', player not in game_players -> join as spectator
        # game is 'playing' | 'finished', player in game_players, is_joined -> is_joined = true
        # ???
        if self.stopped:
            return

        if player_id in self.player_states:
            return

        should_add = False
        as_spectator = False
        match self.status:
            case GameStatus.WAITING:
                ...



    async def disconnect_player(
            self,
            conn: asyncpg.Connection,
            player_id: int,
            log=gl_log,
    ) -> None | ServiceError:
        ...

    async def start_game(
            self,
            conn: asyncpg.Connection,
            log=gl_log,
    ) -> None | ServiceError:
        ...

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
