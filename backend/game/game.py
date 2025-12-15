import asyncio
import contextlib
import dataclasses
import datetime

import asyncpg

import config
import game.universe as universe
import game.chat
from game.chat import ChatSystem
from game.logger import gl_log
from game.utils import Timer, AsyncReentrantLock
from lstypes.chat import ChatType, ChatInterfaceType, ChatInterface, ChatSegmentOut
from game.system import System
from lstypes.error import error, ServiceError
from lstypes.game import GameStatus, GameOut, StateOut
from lstypes.player import PlayerOut
from lstypes.user import UserOut
from lstypes.message import MessageKind


@dataclasses.dataclass
class GameEvent:
    game_id: int


@dataclasses.dataclass
class GameStatusEvent(GameEvent):
    new_status: GameStatus


@dataclasses.dataclass
class GameSettingsUpdateEvent(GameEvent):
    public: bool
    name: str
    max_players: int


@dataclasses.dataclass
class GameChatEvent(GameEvent):
    chat_id: int
    owner_id: int | None
    event: game.chat.ChatEvent


@dataclasses.dataclass
class PlayerJoinedEvent(GameEvent):
    player: PlayerOut


@dataclasses.dataclass
class PlayerLeftEvent(GameEvent):
    player: PlayerOut


@dataclasses.dataclass
class PlayerKickedEvent(GameEvent):
    player: PlayerOut


@dataclasses.dataclass
class PlayerPromotedEvent(GameEvent):
    old_host: int | None
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
    user: UserOut
    is_joined: bool
    is_ready: bool
    is_spectator: bool
    joined_at: datetime.datetime
    kick_timer: Timer
    kick_task: asyncio.Task | None
    character_chat: ChatSystem | None
    advice_chat: ChatSystem | None
    player_chat: ChatSystem | None

    def get_player_out(self, host_id: int) -> PlayerOut:
        return PlayerOut(
            user=self.user,
            is_joined=self.is_joined,
            is_ready=self.is_ready,
            is_host=self.user.id == host_id,
            is_spectator=self.is_spectator,
            joined_at=self.joined_at,
        )


class GameSystem(System[GameEvent]):

    @staticmethod
    async def create_new(conn: asyncpg.Connection, g: GameOut) -> "GameSystem":
        status = GameStatus.WAITING
        room_chat = await ChatSystem.create_or_load(conn, g.id, ChatType.ROOM, None)

        host_id = None
        num_non_spectators = 0
        player_states: dict[int, Player] = {}

        for player in g.players:
            player_states[player.user.id] = Player(
                user=player.user,
                is_joined=True,
                is_ready=player.is_ready,
                is_spectator=player.is_spectator,
                joined_at=datetime.datetime.now(),
                kick_timer=Timer(config.KICK_PLAYER_AFTER_SECONDS),
                kick_task=None,
                character_chat=None,
                advice_chat=None,
                player_chat=None,
            )
            if player.is_host:
                host_id = player.user.id
            if not player.is_spectator:
                num_non_spectators += 1

        game_system = GameSystem(
            g.id,
            status,
            g.public,
            g.max_players,
            host_id,
            num_non_spectators,
            player_states,
            room_chat,
        )

        for player in game_system.player_states.values():
            await game_system.update_chats_for_player(conn, player)

        return game_system

    def __init__(
        self,
        id_: int,
        status: GameStatus,
        public: bool,
        max_players: int,
        host_id: int | None,
        num_not_spectators: int,
        player_states: dict[int, Player],
        room_chat: ChatSystem,
    ):
        super().__init__(id_)
        self.status = status
        self.public = public
        self.max_players = max_players
        self.host_id = host_id
        self.num_non_spectators = num_not_spectators
        self.player_states = player_states
        self.lock = AsyncReentrantLock()
        self.terminating = False
        self.game_loop_task = None
        self.game_chat = room_chat
        self.add_pipe(self.forward_chat_events(self.game_chat, None))

    async def forward_chat_events(self, chat_: ChatSystem, owner_id: int | None):
        async for event in chat_.listen():
            self.emit(GameChatEvent(self.id, owner_id, event))

    def _find_chat(self, chat_id: int) -> tuple[ChatSystem | None, int | None]:
        if chat_id == self.game_chat.id:
            return self.game_chat, None

        for uid, p in self.player_states.items():
            for c in (p.character_chat, p.player_chat, p.advice_chat):
                if c is not None and c.id == chat_id:
                    return c, uid

        return None, None

    async def send_message(
        self,
        conn: asyncpg.Connection,
        sender_id: int,
        chat_id: int,
        message: str,
        special: str | None = None,
        metadata: dict | None = None,
        log=gl_log,
    ):
        if sender_id not in self.player_states:
            return await error("PlayerNotInGame", "Player not in game", log=log)

        chat, owner_id = self._find_chat(chat_id)
        if chat is None:
            return await error("ChatNotFound", "Chat not found", log=log)

        if owner_id is not None and owner_id != sender_id:
            return await error("CannotAccessChat", "Cannot access chat", log=log)

        text = (message or "").strip()
        if not text:
            return await error("EmptyMessage", "Message is empty", log=log)

        if chat.interface_type in (
            ChatInterfaceType.READONLY,
            ChatInterfaceType.FOREIGN,
            ChatInterfaceType.FOREIGN_TIMED,
        ):
            return await error("CannotAccessChat", "Chat is not writable", log=log)

        return await chat.send_message(
            conn=conn,
            message_kind=MessageKind.PLAYER,
            text=text,
            sender_id=sender_id,
            special=special,
            metadata=metadata,
            log=log,
        )

    async def get_chat_segment(
        self,
        conn: asyncpg.Connection,
        requester_id: int,
        chat_id: int,
        limit: int = 50,
        before: int | None = None,
        after: int | None = None,
        log=gl_log,
    ) -> ChatSegmentOut | ServiceError:
        if requester_id not in self.player_states:
            return await error("PlayerNotInGame", "Player not in game", log=log)

        chat, owner_id = self._find_chat(chat_id)
        if chat is None:
            return await error("ChatNotFound", "Chat not found", log=log)

        if owner_id is not None and owner_id != requester_id:
            return await error("CannotAccessChat", "Cannot access chat", log=log)

        limit = min(max(limit, 1), 500)

        return await chat.get_messages(
            conn,
            limit,
            before_message_id=before,
            after_message_id=after,
            log=log,
        )

    async def game_loop(self):
        raise NotImplementedError("game_loop")

    async def get_state(
        self,
        conn: asyncpg.Connection,
        requester_id: int,
        log=gl_log,
    ) -> StateOut | ServiceError:
        if requester_id not in self.player_states:
            return await error("PLAYER_NOT_FOUND", "Player not found", log=log)

        player = self.player_states[requester_id]
        game = universe.Universe.of(None).get_game(conn, self.id, requester_id=requester_id, log=log)

        num_messages = 50

        return StateOut(
            game=game,
            status=self.status,
            character_creation_chat=await player.character_chat.get_messages(conn, num_messages, log=log),
            game_chat=await player.player_chat.get_messages(conn, num_messages, log=log),
            player_chats=[
                await p.player_chat.get_messages(conn, num_messages, log=log)
                for p in self.player_states.values() if not p.is_spectator
            ],
            advice_chats=[
                await p.advice_chat.get_messages(conn, num_messages, log=log)
                for p in self.player_states.values() if not p.is_spectator
            ],
        )
