import asyncio
import contextlib
import dataclasses
import datetime
import json
import time

import asyncpg

import config
import game.universe as universe
import game.chat
from game.logic import (
    CHARACTER_QUESTIONS,
    ActionSummary,
    CharacterCreationSession,
    CharacterProfile,
    PlayerAction,
    advance_character_session,
    build_advice_response,
    default_character_profile,
    ensure_game_state,
    resolve_turn,
    suggest_actions,
    summarize_action,
)
from game.chat import ChatSystem
from game.inference import (
    CHARACTER_MODEL,
    DM_MODEL,
    PLAYER_MODEL,
    CHARACTER_PROFILE_TOOL,
    DM_RESOLVE_TOOL,
    create_chat_completion,
    extract_tool_call_args,
    extract_tool_calls,
)
from game.logger import gl_log
from game.utils import Timer, AsyncReentrantLock, get_conn
from lstypes.chat import ChatType, ChatInterfaceType
from game.system import System
from lstypes.error import ServiceCode, ServiceError, error
from lstypes.game import GameStatus, GameOut, StateOut
from lstypes.player import PlayerOut
from lstypes.user import UserOut
from lstypes.message import MessageKind
from tooling.process_runner import ToolError
from tooling.tool_manager import ToolManager


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


@dataclasses.dataclass
class PendingAction:
    player_id: int
    text: str
    is_auto: bool = False
    received_at: float = dataclasses.field(default_factory=time.monotonic)


ACTION_BATCH_SECONDS = 1.0
AUTO_ACTION_INTERVAL = 30.0
PLAYER_MEMORY_LIMIT = 20
LLM_MEMORY_CONTEXT = 6

CHARACTER_SYSTEM_PROMPT = (
    "You are a character creation assistant for a fantasy RPG. "
    "Collect the following fields: name, concept, strength (1-10), "
    "dexterity (1-10), intelligence (1-10), lore. "
    "Ask concise questions for missing info, one question at a time. "
    "If a stat is given in words, map it to 1-10. "
    "When you have enough info, call submit_character_profile with all fields. "
    "Respond in the same language as the player."
)
CHARACTER_OPENING_PROMPT = (
    "Let's create your character. Start with their name and role."
)
PLAYER_ACTION_SYSTEM_PROMPT = (
    "You are the player's personal narrator. "
    "Write a short report for the Dungeon Master. "
    "Use only the player's memory and stats. "
    "Do not invent new world facts. "
    "Use third-person and include success or failure. "
    "Keep it to one sentence."
)
DM_SYSTEM_PROMPT = (
    "You are the Dungeon Master. You see the full world state and player reports. "
    "Decide consequences and update the world. "
    "If tools are available and needed to change the world, call them first. "
    "Call resolve_turn with a short summary, optional world_update, "
    "and a consequence text for each player_id after tool results. "
    "Match the dominant language of the player reports."
)
PLAYER_NARRATIVE_SYSTEM_PROMPT = (
    "You are the player's personal narrator. "
    "Rewrite the DM consequence into a vivid second-person narrative. "
    "Use only the player's memory and the provided consequence. "
    "Keep it to 1-3 sentences and match the player's language."
)


class GameSystem(System[GameEvent]):
    @staticmethod
    async def create_new(
        conn: asyncpg.Connection,
        g: GameOut,
        *,
        db_pool: asyncpg.Pool | None = None,
    ) -> GameSystem:
        status = g.status
        public = g.public
        game_name = g.name
        max_players = g.max_players

        room_chat = await ChatSystem.create_or_load(conn, g.id, ChatType.ROOM, None)

        host_id: int | None = g.host_id
        num_non_spectators = 0
        player_states: dict[int, Player] = {}
        for player in g.players:
            player_states[player.user.id] = Player(
                user=player.user,
                is_joined=player.is_joined,
                is_spectator=player.is_spectator,
                is_ready=player.is_ready,
                joined_at=player.joined_at,
                kick_timer=Timer(config.KICK_PLAYER_AFTER_SECONDS),
                kick_task=None,
                character_chat=None,
                advice_chat=None,
                player_chat=None,
            )
            if not player.is_spectator:
                num_non_spectators += 1

        raw_state = await conn.fetchval("SELECT state FROM games WHERE id = $1", g.id)
        game_state = ensure_game_state(raw_state)

        game_system = GameSystem(
            g.id,
            status,
            public,
            game_name,
            max_players,
            host_id,
            num_non_spectators,
            player_states,
            room_chat,
            game_state,
            db_pool=db_pool,
        )

        for player in game_system.player_states.values():
            await game_system.update_chats_for_player(conn, player)

        return game_system

    def __init__(
        self,
        id_: int,
        status: GameStatus,
        public: bool,
        game_name: str,
        max_players: int,
        host_id: int | None,
        num_not_spectators: int,
        player_states: dict[int, Player],
        room_chat: ChatSystem,
        state: dict,
        *,
        db_pool: asyncpg.Pool | None = None,
    ):
        super().__init__(id_)
        self.status = status
        self.public = public
        self.game_name = game_name
        self.max_players = max_players
        self.host_id = host_id
        self.num_non_spectators = num_not_spectators
        self.player_states = player_states
        self.lock = AsyncReentrantLock()
        self.terminating = False
        self.game_loop_task = None
        self.game_chat = room_chat
        self.state = state
        self.db_pool = db_pool
        self.character_sessions: dict[int, CharacterCreationSession] = {}
        self.pending_actions: list[PendingAction] = []
        self.action_event = asyncio.Event()
        self.action_lock = asyncio.Lock()
        self._tool_manager: ToolManager | None = None
        self._tool_defs: list[dict[str, object]] = []
        self._tool_names: set[str] = set()
        self._tooling_error: str | None = None
        self.add_pipe(
            self.forward_chat_events(self.game_chat, ChatType.ROOM, None),
            name=f"forward_room_chat_game{self.id}",
        )

    async def update_chats_for_player(
        self,
        conn: asyncpg.Connection,
        player: Player,
        force_stop: bool = False,
        log=gl_log,
    ) -> Player:
        if force_stop or player.is_spectator:
            if player.character_chat is not None:
                await player.character_chat.stop()
            if player.player_chat is not None:
                await player.player_chat.stop()
            if player.advice_chat is not None:
                await player.advice_chat.stop()
            player.character_chat = None
            player.player_chat = None
            player.advice_chat = None
        else:
            if player.character_chat is None:
                player.character_chat = await ChatSystem.create_or_load(
                    conn,
                    self.id,
                    ChatType.CHARACTER_CREATION,
                    player.user.id,
                    ChatInterfaceType.FOREIGN,
                    log=log,
                )
                self.add_pipe(
                    self.forward_chat_events(
                        player.character_chat,
                        ChatType.CHARACTER_CREATION,
                        player.user.id,
                    ),
                    name=f"forward_character_chat_game{self.id}_player{player.user.id}",
                )
                await self._maybe_start_character_creation(
                    conn, player, chat=player.character_chat, log=log
                )
            if player.player_chat is None:
                player.player_chat = await ChatSystem.create_or_load(
                    conn,
                    self.id,
                    ChatType.GAME,
                    player.user.id,
                    ChatInterfaceType.FOREIGN,
                    log=log,
                )
                self.add_pipe(
                    self.forward_chat_events(
                        player.player_chat, ChatType.GAME, player.user.id
                    ),
                    name=f"forward_game_chat_game{self.id}_player{player.user.id}",
                )
            if player.advice_chat is None:
                player.advice_chat = await ChatSystem.create_or_load(
                    conn,
                    self.id,
                    ChatType.ADVICE,
                    player.user.id,
                    ChatInterfaceType.FOREIGN,
                    log=log,
                )
                self.add_pipe(
                    self.forward_chat_events(
                        player.advice_chat, ChatType.ADVICE, player.user.id
                    ),
                    name=f"forward_advice_chat_game{self.id}_player{player.user.id}",
                )
        return player

    async def stop(self):
        if self.game_loop_task is not None:
            self.game_loop_task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await self.game_loop_task
        await self.game_chat.stop()
        for player in self.player_states.values():
            if player.character_chat is not None:
                await player.character_chat.stop()
            if player.player_chat is not None:
                await player.player_chat.stop()
            if player.advice_chat is not None:
                await player.advice_chat.stop()
        await super().stop()

    async def forward_chat_events(
        self,
        chat_: ChatSystem,
        chat_type: ChatType,
        owner_id: int | None,
    ):
        async for event in chat_.listen():
            self.emit(
                GameChatEvent(
                    game_id=self.id,
                    chat_id=chat_.id,
                    owner_id=owner_id,
                    event=event,
                )
            )

            if self.db_pool is None or not isinstance(
                event, game.chat.ChatMessageSentEvent
            ):
                continue

            message = event.message.msg
            if message.kind != MessageKind.PLAYER or message.sender_id is None:
                continue

            if chat_type == ChatType.CHARACTER_CREATION:
                asyncio.create_task(
                    self._handle_character_message(
                        message.sender_id, message.text, chat_, owner_id
                    ),
                    name=f"character_message_game{self.id}_player{message.sender_id}",
                )
            elif chat_type == ChatType.ADVICE:
                asyncio.create_task(
                    self._handle_advice_message(
                        message.sender_id, message.text, chat_, owner_id
                    ),
                    name=f"advice_message_game{self.id}_player{message.sender_id}",
                )
            elif chat_type == ChatType.GAME:
                await self._queue_action(message.sender_id, message.text)

    async def connect_player(
        self,
        conn: asyncpg.Connection,
        player_id: int,
        log=gl_log,
    ) -> None | ServiceError:
        if self.stopped:
            return None

        log = log.bind(
            game_id=self.id,
            player_id=player_id,
            status=self.status,
            max_players=self.max_players,
            player_count=len(self.player_states),
            non_specators_count=self.num_non_spectators,
        )

        async with self.lock:
            now = datetime.datetime.now()

            if player_id in self.player_states:
                player = self.player_states[player_id]
                if player.is_joined:
                    await log.ainfo("Player already joined")
                    return None

                result = await conn.fetchval(
                    """
                    UPDATE game_players SET
                        is_joined = TRUE,
                        joined_at = $3
                    WHERE
                        game_id = $1 AND user_id = $2
                    RETURNING TRUE as success
                    """,
                    self.id,
                    player_id,
                    now,
                )

                if not result:
                    return await error(
                        ServiceCode.SERVER_ERROR,
                        "Mismatch between server state and DB state. Player not found",
                        log=log,
                    )

                player.is_joined = True
                player.joined_at = now
                if player.kick_task is not None:
                    player.kick_task.cancel("Player rejoined")
                    player.kick_task = None

                self.emit(
                    PlayerJoinedEvent(self.id, player.get_player_out(self.host_id))
                )
                await log.ainfo("Player rejoined")
                return None

            allow_entry = False
            match self.status:
                case GameStatus.WAITING:
                    if self.num_non_spectators < self.max_players:
                        await log.ainfo("Letting player join")
                        allow_entry = True
                    else:
                        await log.ainfo(
                            "Letting player join as spectator as game is full"
                        )
                        allow_entry = False
                case GameStatus.PLAYING | GameStatus.FINISHED:
                    await log.ainfo(
                        "Letting player join as spectator as game is already going"
                    )
                    allow_entry = False

            row = await conn.fetchrow(
                """
                WITH insert_game_players AS (
                    INSERT INTO game_players (
                        game_id, user_id, is_ready, is_spectator, is_joined, joined_at
                    ) VALUES (
                        $1, $2, FALSE, $3, TRUE, $4
                    ) RETURNING user_id
                )
                SELECT id, name, created_at, deleted
                FROM users
                WHERE id = (SELECT user_id FROM insert_game_players)
                """,
                self.id,
                player_id,
                not allow_entry,
                now,
            )

            if not row:
                return await error(
                    ServiceCode.SERVER_ERROR,
                    "Mismatch between server state and DB state. Failed to insert player",
                )

            self.num_non_spectators += allow_entry
            player = Player(
                user=UserOut(
                    id=row["id"],
                    name=row["name"],
                    created_at=row["created_at"],
                    deleted=row["deleted"],
                ),
                is_joined=True,
                is_ready=False,
                is_spectator=not allow_entry,
                joined_at=now,
                kick_timer=Timer(config.KICK_PLAYER_AFTER_SECONDS),
                kick_task=None,
                character_chat=None,
                advice_chat=None,
                player_chat=None,
            )
            await self.update_chats_for_player(conn, player, log=log)
            self.player_states[player_id] = player
            self.emit(PlayerJoinedEvent(self.id, player.get_player_out(self.host_id)))
            await log.ainfo("Player joined")
            return None

    async def kick_task(self, player: Player, dont_wait: bool = False, log=gl_log):
        if not dont_wait:
            await player.kick_timer.wait()

        with contextlib.suppress(asyncio.CancelledError):
            async with get_conn() as conn, self.lock:
                player.kick_task = None
                player_id = player.user.id

                row = await conn.fetchrow(
                    """
                    WITH delete_player AS (
                        DELETE FROM game_players WHERE
                            game_id = $1 AND user_id = $2
                        RETURNING user_id AS id, game_id
                    )
                    SELECT delete_player.id = g.host_id AS was_host FROM delete_player
                    JOIN games AS g ON g.id = delete_player.game_id
                    """,
                    self.id,
                    player_id,
                )
                if not row:
                    await error(
                        ServiceCode.SERVER_ERROR,
                        "Mismatch between server state and DB state. Failed to remove player",
                        log=log,
                    )

                await log.ainfo("Player removed from the game")
                self.player_states.pop(player_id)
                self.num_non_spectators -= 1
                await self.update_chats_for_player(
                    conn, player, force_stop=True, log=log
                )

                if len(self.player_states) == 0:
                    await log.ainfo("Terminating game because last player left")
                    await self.terminate(conn, log=log)
                    return

                if row["was_host"]:
                    for p in self.player_states.values():
                        if p.is_joined:
                            new_host_id = p.user.id
                            break
                    else:
                        await log.ainfo(
                            "Terminating game because host left and all players are disconnected"
                        )
                        await self.terminate(conn, log=log)
                        return

                    await log.ainfo(
                        "Promoting new host because old one quit",
                        new_host_id=new_host_id,
                    )
                    await self.make_host(conn, new_host_id, log=log)

    async def disconnect_player(
        self,
        conn: asyncpg.Connection,
        player_id: int,
        kick_immediately: bool = False,
        requester_id: int | None = None,
        log=gl_log,
    ) -> None | ServiceError:
        if self.stopped:
            return None

        if (
            requester_id is not None
            and requester_id != self.host_id
            and requester_id != player_id
        ):
            return await error(
                ServiceCode.NOT_HOST, "Only host can kick players", log=log
            )

        log = log.bind(game_id=self.id, player_id=player_id)

        async with self.lock:
            if player_id not in self.player_states:
                return None

            player = self.player_states[player_id]

            if not player.is_joined:
                return None

            if player.is_spectator:
                success = await conn.fetchval(
                    """
                    DELETE FROM game_players WHERE
                        game_id = $1 AND user_id = $2 AND is_spectator = TRUE
                    RETURNING TRUE AS success
                    """,
                    self.id,
                    player_id,
                )
                if not success:
                    return await error(
                        ServiceCode.SERVER_ERROR,
                        "Mismatch between server state and DB state. Failed to remove spectator",
                        log=log,
                    )

                self.player_states.pop(player_id)
                await log.ainfo("Player left as spectator")
                return None

            success = await conn.fetchval(
                """
                UPDATE game_players 
                SET is_joined = FALSE
                WHERE
                    game_id = $1 AND user_id = $2 AND is_joined = TRUE
                RETURNING TRUE AS success
                """,
                self.id,
                player_id,
            )

            if not success:
                return await error(
                    ServiceCode.SERVER_ERROR,
                    "Mismatch between server state and DB state. Failed to remove player",
                )

            await log.ainfo("Marked player as not joined")

            self.emit(
                PlayerLeftEvent(self.id, player=player.get_player_out(self.host_id))
            )

            if kick_immediately:
                await self.kick_task(player, dont_wait=True, log=log)
            else:
                player.kick_task = asyncio.Task(
                    self.kick_task(player, log=log),
                    name=f"kick_task_player{player_id}_game{self.id}",
                )

        return None

    async def make_spectator(
        self,
        conn: asyncpg.Connection,
        player_id: int,
        spectate: bool = True,
        requester_id: int | None = None,
        log=gl_log,
    ) -> None | ServiceError:
        if self.stopped:
            return None

        log = log.bind(
            game_id=self.id,
            player_id=player_id,
            spectate=spectate,
            requester_id=requester_id,
        )

        if (
            requester_id is not None
            and requester_id != self.host_id
            and requester_id != player_id
        ):
            return await error(
                ServiceCode.NOT_HOST,
                "Only host can force players to be spectators/players",
                log=log,
            )

        async with self.lock:
            if player_id not in self.player_states:
                return await error(
                    ServiceCode.PLAYER_NOT_FOUND, "Player not found", log=log
                )

            player = self.player_states[player_id]
            if player.is_spectator == spectate:
                return None

            if spectate:
                success = await conn.fetchval(
                    """
                    UPDATE game_players 
                    SET is_spectator = TRUE
                    WHERE user_id = $1 AND game_id = $2
                    RETURNING TRUE AS success
                    """,
                    player_id,
                    self.id,
                )
                if not success:
                    return await error(
                        ServiceCode.SERVER_ERROR,
                        "Mismatch between server state and DB state. Failed to make player spectator",
                        log=log,
                    )

                player.is_spectator = True
                await self.update_chats_for_player(conn, player, log=log)
                self.num_non_spectators -= 1
                self.emit(PlayerSpectatorEvent(self.id, player_id, True))
            else:
                if self.num_non_spectators >= self.max_players:
                    return await error(ServiceCode.GAME_FULL, "Game is full", log=log)

                success = await conn.fetchval(
                    """
                    UPDATE game_players 
                    SET is_spectator = FALSE
                    WHERE user_id = $1 AND game_id = $2
                    RETURNING TRUE AS success
                    """,
                    player_id,
                    self.id,
                )
                if not success:
                    return await error(
                        ServiceCode.SERVER_ERROR,
                        "Mismatch between server state and DB state. Failed to make player not spectator",
                        log=log,
                    )

                player.is_spectator = False
                await self.update_chats_for_player(conn, player, log=log)
                self.num_non_spectators += 1
                self.emit(PlayerSpectatorEvent(self.id, player_id, False))

            return None

    async def make_host(
        self,
        conn: asyncpg.Connection,
        player_id: int,
        requester_id: int | None = None,
        log=gl_log,
    ):
        log = log.bind(
            new_host_id=player_id, old_host=self.host_id, requester_id=requester_id
        )
        old_host = self.host_id

        if requester_id is not None and requester_id != old_host:
            return await error(
                ServiceCode.NOT_HOST, "Only host can promote other players", log=log
            )

        async with self.lock:
            if player_id not in self.player_states:
                return await error(
                    ServiceCode.PLAYER_NOT_FOUND, "Player not found", log=log
                )

            success = await conn.fetchval(
                """
                UPDATE games SET host_id = $1 WHERE id = $2 RETURNING TRUE AS success
                """,
                player_id,
                self.id,
            )
            if not success:
                return await error(
                    ServiceCode.SERVER_ERROR,
                    "Mismatch between server state and DB state. Failed to promote player to host",
                    log=log,
                )
            self.host_id = player_id
            self.emit(PlayerPromotedEvent(self.id, old_host, self.host_id))
            await log.ainfo("New host promoted")

            return None

    async def update_settings(
        self,
        conn: asyncpg.Connection,
        *,
        public: bool | None = None,
        name: str | None = None,
        max_players: int | None = None,
        log=gl_log,
    ) -> None | ServiceError:
        if self.stopped:
            return None

        async with self.lock:
            new_public = self.public if public is None else public
            new_name = self.game_name if name is None else name
            new_max_players = self.max_players if max_players is None else max_players

            success = await conn.fetchval(
                """
                UPDATE games
                SET public = $2,
                    name = $3,
                    max_players = $4
                WHERE id = $1
                RETURNING TRUE AS success
                """,
                self.id,
                new_public,
                new_name,
                new_max_players,
            )
            if not success:
                return await error(
                    ServiceCode.SERVER_ERROR,
                    "Mismatch between server state and DB state. Failed to update game settings",
                    log=log,
                )

            self.public = new_public
            self.game_name = new_name
            self.max_players = new_max_players
            self.emit(
                GameSettingsUpdateEvent(
                    self.id,
                    public=new_public,
                    name=new_name,
                    max_players=new_max_players,
                )
            )
            await log.ainfo("Game settings updated")
            return None

    async def start_game(
        self,
        conn: asyncpg.Connection,
        force: bool = False,
        requester_id: int | None = None,
        log=gl_log,
    ) -> None | ServiceError:
        log = log.bind(force=force, game_id=self.id, requester_id=requester_id)
        if self.status != GameStatus.WAITING:
            return await error(
                ServiceCode.GAME_ALREADY_STARTED, "Game already started", log=log
            )

        if requester_id is not None:
            if requester_id != self.host_id:
                return await error(
                    ServiceCode.NOT_HOST, "Only host can start the game", log=log
                )

        async with self.lock:
            not_ready_ids: list[int] = [
                p.user.id
                for p in self.player_states.values()
                if p.is_joined and not p.is_spectator and not p.is_ready
            ]
            if not_ready_ids:
                if force:
                    for player_id in not_ready_ids:
                        result = await self.make_spectator(conn, player_id, log=log)
                        if result is not None:
                            return result
                else:
                    return await error(
                        ServiceCode.PLAYER_NOT_READY,
                        "Not all players are ready for a game yet",
                        playerIds=not_ready_ids,
                        log=log,
                    )

            success = await conn.fetchval(
                """
                UPDATE games SET status = 'playing' WHERE id = $1 RETURNING TRUE AS success
                """,
                self.id,
            )
            if not success:
                return await error(
                    ServiceCode.SERVER_ERROR,
                    "Mismatch between server state and DB state. Failed to update game status",
                    log=log,
                )

            self.status = GameStatus.PLAYING
            self.emit(GameStatusEvent(self.id, GameStatus.PLAYING))

            await log.ainfo("Game started")

            self.state = ensure_game_state(self.state)
            await self._announce_game_start(conn)

            self.game_loop_task = asyncio.create_task(
                self.game_loop(), name=f"game_loop_game{self.id}"
            )

            return None

    async def terminate(
        self,
        conn: asyncpg.Connection,
        log=gl_log,
    ) -> None | ServiceError:
        if self.terminating:
            return None
        self.terminating = True
        if self.game_loop_task:
            self.game_loop_task.cancel()

        async with self.lock:
            for player in self.player_states.values():
                await self.disconnect_player(
                    conn, player.user.id, kick_immediately=True, log=log
                )

            self.status = GameStatus.ARCHIVED
            success = await conn.fetchval(
                """
                UPDATE games SET status = 'archived' WHERE id = $1 RETURNING TRUE AS success
                """,
                self.id,
            )
            if not success:
                return await error(
                    ServiceCode.SERVER_ERROR,
                    "Mismatch between server state and DB state. Failed to update game status",
                    log=log,
                )
            await log.ainfo("Game terminated")
            self.emit(GameStatusEvent(self.id, GameStatus.ARCHIVED))
            return None

    async def set_ready(
        self, conn: asyncpg.Connection, user_id: int, ready: bool, log=gl_log
    ) -> None | ServiceError:
        log = log.bind(game_id=self.id, user_id=user_id)

        if user_id not in self.player_states:
            return await error(
                ServiceCode.PLAYER_NOT_FOUND, "Player not found", log=log
            )

        async with self.lock:
            if ready:
                err = await self._require_character_on_ready(conn, user_id, log=log)
                if err is not None:
                    return err

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
                return await error(
                    ServiceCode.SERVER_ERROR, "Player not found", log=log
                )

            await log.ainfo("Setting ready status", ready=ready)
            self.player_states[user_id].is_ready = ready
            self.emit(PlayerReadyEvent(game_id=game_id, player_id=user_id, ready=ready))

            return None

    async def get_player(
        self,
        conn: asyncpg.Connection,
        user_id: int,
        log=gl_log,
    ) -> PlayerOut | ServiceError:
        log = log.bind(user_id=user_id)
        if user_id not in self.player_states:
            return await error(
                ServiceCode.PLAYER_NOT_FOUND, "Player not found", log=log
            )
        return self.player_states[user_id].get_player_out(self.host_id)

    async def get_state(
        self,
        conn: asyncpg.Connection,
        requester_id: int,
        log=gl_log,
    ) -> StateOut | ServiceError:
        if (
            requester_id not in self.player_states
            or not self.player_states[requester_id].is_joined
        ):
            return await error(
                ServiceCode.PLAYER_NOT_FOUND, "Player not found", log=log
            )

        game = await universe.Universe.get_game(
            conn, self.id, requester_id=requester_id, log=log
        )
        if isinstance(game, ServiceError):
            return game

        player = self.player_states[requester_id]

        num_messages = 50

        game_chat = await self.game_chat.get_messages(conn, num_messages, log=log)
        if isinstance(game_chat, ServiceError):
            return game_chat

        character_creation_chat = None
        if player.character_chat is not None:
            character_creation_chat = await player.character_chat.get_messages(
                conn, num_messages, log=log
            )
            if isinstance(character_creation_chat, ServiceError):
                return character_creation_chat

        player_chats: list = []
        advice_chats: list = []
        if self.status != GameStatus.WAITING:
            for p in game.players:
                state = self.player_states.get(p.user.id)
                if (
                    state is None
                    or state.is_spectator
                    or state.player_chat is None
                    or state.advice_chat is None
                ):
                    continue

                pc = await state.player_chat.get_messages(conn, num_messages, log=log)
                if isinstance(pc, ServiceError):
                    return pc
                player_chats.append(pc)

                ac = await state.advice_chat.get_messages(conn, num_messages, log=log)
                if isinstance(ac, ServiceError):
                    return ac
                advice_chats.append(ac)

        return StateOut(
            game=game,
            status=self.status,
            character_creation_chat=character_creation_chat,
            game_chat=game_chat,
            player_chats=player_chats,
            advice_chats=advice_chats,
        )

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
        chat_system = ChatSystem.of(chat_id)
        if chat_system is None:
            return await error(
                ServiceCode.SERVER_ERROR,
                "Chat system not loaded",
                chat_id=chat_id,
                log=log,
            )

        result = await chat_system.send_message(
            conn,
            game.chat.MessageKind.PLAYER,
            message,
            sender_id,
            special=special,
            metadata=metadata,
            log=log,
        )
        if isinstance(result, ServiceError):
            return result
        return None

    def _ensure_player_state(self, player_id: int):
        players = self.state.setdefault("players", {})
        players.setdefault(str(player_id), {"memory": []})

    def _get_character(self, player_id: int) -> CharacterProfile | None:
        data = self.state.get("characters", {}).get(str(player_id))
        if not data:
            return None
        return CharacterProfile.from_dict(data)

    def _set_character(self, player_id: int, profile: CharacterProfile):
        self.state.setdefault("characters", {})[str(player_id)] = profile.to_dict()
        self._ensure_player_state(player_id)

    def _remember_for_player(self, player_id: int, text: str):
        self._ensure_player_state(player_id)
        memory = self.state["players"][str(player_id)].setdefault("memory", [])
        memory.append(text)
        if len(memory) > PLAYER_MEMORY_LIMIT:
            del memory[:-PLAYER_MEMORY_LIMIT]

    def _llm_enabled(self) -> bool:
        return config.LLM_ENABLED

    def _init_tooling(self) -> None:
        if self._tool_manager is not None or self._tooling_error is not None:
            return

        tools_cfg = self.state.get("tools")
        if not isinstance(tools_cfg, dict):
            world_cfg = self.state.get("world")
            if isinstance(world_cfg, dict):
                tools_cfg = world_cfg.get("tools")
        if not isinstance(tools_cfg, dict):
            self._tooling_error = "tools config missing"
            return

        manifest = tools_cfg.get("manifest")
        if isinstance(manifest, str):
            try:
                manifest = json.loads(manifest)
            except json.JSONDecodeError as exc:
                self._tooling_error = f"invalid manifest: {exc}"
                gl_log.warning("Tool manifest is invalid JSON", error=str(exc))
                return

        if not isinstance(manifest, dict):
            self._tooling_error = "manifest missing"
            return

        raw_sources = tools_cfg.get("lua_sources") or tools_cfg.get("lua_source")
        if isinstance(raw_sources, str):
            lua_sources = [raw_sources]
        elif isinstance(raw_sources, list):
            lua_sources = [str(src) for src in raw_sources if src]
        else:
            lua_sources = []

        if not lua_sources:
            self._tooling_error = "lua_sources missing"
            return

        timeout_ms = tools_cfg.get("timeout_ms", 100)
        memory_limit_mb = tools_cfg.get("memory_limit_mb", 64)
        start_method = tools_cfg.get("start_method", "spawn")

        try:
            self._tool_manager = ToolManager(
                lua_sources=lua_sources,
                manifest=manifest,
                timeout_ms=int(timeout_ms),
                memory_limit_mb=int(memory_limit_mb),
                start_method=str(start_method),
            )
        except Exception as exc:
            self._tooling_error = str(exc)
            gl_log.warning("ToolManager init failed", error=str(exc))
            return

        tool_defs, tool_names = self._build_tool_defs(manifest)
        self._tool_defs = tool_defs
        self._tool_names = tool_names

    def _build_tool_defs(
        self, manifest: dict[str, object]
    ) -> tuple[list[dict[str, object]], set[str]]:
        tools = manifest.get("tools")
        if not isinstance(tools, dict):
            return [], set()

        tool_defs: list[dict[str, object]] = []
        tool_names: set[str] = set()
        for tool_name, spec in tools.items():
            if not isinstance(tool_name, str) or not tool_name:
                continue
            if tool_name in {"resolve_turn", "submit_character_profile"}:
                continue
            if not isinstance(spec, dict):
                continue
            description = spec.get("description")
            if not isinstance(description, str):
                description = ""
            parameters = spec.get("input_schema")
            if not isinstance(parameters, dict):
                parameters = {"type": "object"}
            tool_defs.append(
                {
                    "type": "function",
                    "function": {
                        "name": tool_name,
                        "description": description,
                        "parameters": parameters,
                    },
                }
            )
            tool_names.add(tool_name)
        return tool_defs, tool_names

    def _get_tooling(
        self,
    ) -> tuple[ToolManager, list[dict[str, object]], set[str]] | None:
        self._init_tooling()
        if self._tool_manager is None:
            return None
        return self._tool_manager, self._tool_defs, self._tool_names

    async def _run_lua_tool(
        self,
        tool_name: str,
        llm_params: dict[str, object],
    ) -> dict[str, object]:
        tooling = self._get_tooling()
        if tooling is None:
            return {"error": "Tooling is not configured"}
        manager, _, _ = tooling

        world_state = self.state.get("world")
        if not isinstance(world_state, dict):
            world_state = {}
            self.state["world"] = world_state

        try:
            new_world_state, output = await manager.run_tool(
                tool_name=tool_name,
                world_state=world_state,
                llm_params=llm_params,
            )
        except ToolError as exc:
            gl_log.warning("Lua tool failed", tool=tool_name, error=str(exc))
            return {"error": str(exc)}

        if isinstance(new_world_state, dict):
            world_state.update(new_world_state)
            self.state["world"] = world_state
        else:
            new_world_state = world_state

        if not isinstance(output, dict):
            output = {"output": output}

        return {"world_state": new_world_state, "output": output}

    def _tool_call_message(
        self, tool_calls: list[dict[str, object]], content: str | None
    ) -> dict[str, object]:
        serialized = []
        for call in tool_calls:
            tool_id = call.get("id")
            name = call.get("name")
            args = call.get("arguments")
            if not isinstance(name, str) or not name:
                continue
            serialized.append(
                {
                    "id": tool_id,
                    "type": "function",
                    "function": {"name": name, "arguments": args or "{}"},
                }
            )
        return {
            "role": "assistant",
            "content": content or "",
            "tool_calls": serialized,
        }

    def _append_llm_log(
        self,
        *,
        scope: str,
        model: str,
        prompt: list[dict[str, str]],
        response: str | dict | None,
        player_id: int | None = None,
        turn: int | None = None,
        error_text: str | None = None,
    ):
        logs = self.state.setdefault("llm_logs", [])
        entry = {
            "scope": scope,
            "model": model,
            "prompt": prompt,
            "response": response,
            "player_id": player_id,
            "turn": turn if turn is not None else int(self.state.get("turn", 0)),
        }
        if error_text:
            entry["error"] = error_text
        logs.append(entry)
        limit = max(0, config.LLM_LOG_LIMIT)
        if limit and len(logs) > limit:
            del logs[:-limit]

    def _format_player_memory(self, player_id: int) -> str:
        self._ensure_player_state(player_id)
        memory = self.state["players"][str(player_id)].get("memory", [])
        if not memory:
            return "None."
        recent = memory[-LLM_MEMORY_CONTEXT:]
        return "\n".join(f"- {item}" for item in recent)

    def _character_card(self, character: CharacterProfile) -> str:
        return (
            f"{character.name} ({character.concept}). "
            f"STR {character.strength}, DEX {character.dexterity}, "
            f"INT {character.intelligence}. Lore: {character.lore}"
        )

    def _character_suggestions_from_text(self, text: str) -> list[str]:
        lowered = text.lower()
        if "name" in lowered:
            return CHARACTER_QUESTIONS[0].suggestions
        if any(word in lowered for word in ("role", "concept", "archetype")):
            return CHARACTER_QUESTIONS[1].suggestions
        if "strength" in lowered or "strong" in lowered or "power" in lowered:
            return CHARACTER_QUESTIONS[2].suggestions
        if "dexterity" in lowered or "agile" in lowered or "quick" in lowered:
            return CHARACTER_QUESTIONS[3].suggestions
        if "intelligence" in lowered or "clever" in lowered or "smart" in lowered:
            return CHARACTER_QUESTIONS[4].suggestions
        if "lore" in lowered or "backstory" in lowered or "history" in lowered:
            return CHARACTER_QUESTIONS[5].suggestions
        return ["Surprise me", "Not sure yet", "Let me think"]

    async def _persist_state(self, conn: asyncpg.Connection):
        await conn.execute(
            "UPDATE games SET state = $2 WHERE id = $1", self.id, self.state
        )

    async def _require_character_on_ready(
        self,
        conn: asyncpg.Connection,
        user_id: int,
        log=gl_log,
    ):
        if self._get_character(user_id) is not None:
            return None

        player = self.player_states.get(user_id)
        if player is None:
            return None

        if player.character_chat is not None:
            await player.character_chat.send_message(
                conn,
                MessageKind.CHARACTER_CREATION,
                "Finish character creation before marking ready.",
                sender_id=None,
                metadata={"needs_character": True},
                log=log,
            )
        return await error(
            ServiceCode.CHARACTER_NOT_READY,
            "Character is not ready",
            log=log,
        )

    async def _maybe_start_character_creation(
        self,
        conn: asyncpg.Connection,
        player: Player,
        *,
        chat: ChatSystem,
        log=gl_log,
    ):
        if self.db_pool is None:
            return
        if self._get_character(player.user.id) is not None:
            return

        session = self.character_sessions.get(player.user.id)
        if session is None:
            session = CharacterCreationSession(use_llm=self._llm_enabled())
            self.character_sessions[player.user.id] = session

        if session.completed or chat.index.index:
            return

        if session.use_llm and self._llm_enabled():
            if not session.messages:
                session.messages = [
                    {"role": "system", "content": CHARACTER_SYSTEM_PROMPT},
                    {"role": "assistant", "content": CHARACTER_OPENING_PROMPT},
                ]
                await chat.clear_suggestions()
                for suggestion in self._character_suggestions_from_text(
                    CHARACTER_OPENING_PROMPT
                ):
                    await chat.add_suggestion(suggestion)
                await chat.send_message(
                    conn,
                    MessageKind.CHARACTER_CREATION,
                    CHARACTER_OPENING_PROMPT,
                    sender_id=None,
                    log=log,
                )
            return

        question = CHARACTER_QUESTIONS[session.step]
        await chat.clear_suggestions()
        for suggestion in question.suggestions:
            await chat.add_suggestion(suggestion)
        await chat.send_message(
            conn,
            MessageKind.CHARACTER_CREATION,
            question.prompt,
            sender_id=None,
            log=log,
        )

    async def _handle_character_message(
        self,
        player_id: int,
        message: str,
        chat: ChatSystem,
        owner_id: int | None,
    ):
        if owner_id is not None and owner_id != player_id:
            return

        player = self.player_states.get(player_id)
        if player is None or self.db_pool is None:
            return

        lower = message.strip().lower()
        async with self.db_pool.acquire() as conn:
            async with self.lock:
                session = self.character_sessions.get(player_id)
                restart_requested = "restart" in lower
                if session is None or (session.completed and restart_requested):
                    session = CharacterCreationSession(use_llm=self._llm_enabled())
                    self.character_sessions[player_id] = session
                    if restart_requested:
                        await chat.clear_suggestions()
                        if session.use_llm and self._llm_enabled():
                            session.messages = [
                                {"role": "system", "content": CHARACTER_SYSTEM_PROMPT},
                                {
                                    "role": "assistant",
                                    "content": CHARACTER_OPENING_PROMPT,
                                },
                            ]
                            for suggestion in self._character_suggestions_from_text(
                                CHARACTER_OPENING_PROMPT
                            ):
                                await chat.add_suggestion(suggestion)
                            await chat.send_message(
                                conn,
                                MessageKind.CHARACTER_CREATION,
                                CHARACTER_OPENING_PROMPT,
                                sender_id=None,
                            )
                        else:
                            question = CHARACTER_QUESTIONS[session.step]
                            for suggestion in question.suggestions:
                                await chat.add_suggestion(suggestion)
                            await chat.send_message(
                                conn,
                                MessageKind.CHARACTER_CREATION,
                                question.prompt,
                                sender_id=None,
                            )
                        return

                if session.completed:
                    await chat.send_message(
                        conn,
                        MessageKind.CHARACTER_CREATION,
                        "Character already created. Send 'restart' to rebuild it.",
                        sender_id=None,
                    )
                    return

                if session.use_llm and self._llm_enabled():
                    handled = await self._handle_character_message_llm(
                        conn,
                        player,
                        session,
                        message,
                        chat,
                    )
                    if handled:
                        return

                result = advance_character_session(session, message, player.user.name)
                self.character_sessions[player_id] = result.session

                if result.character is not None:
                    self._set_character(player_id, result.character)
                    await self._persist_state(conn)
                    await chat.clear_suggestions()
                    await chat.send_message(
                        conn,
                        MessageKind.CHARACTER_CREATION,
                        "Character complete. You can now mark ready.",
                        sender_id=None,
                        metadata={"character": result.character.to_dict()},
                    )
                    return

                if result.next_question is not None:
                    await chat.clear_suggestions()
                    for suggestion in result.next_question.suggestions:
                        await chat.add_suggestion(suggestion)
                    await chat.send_message(
                        conn,
                        MessageKind.CHARACTER_CREATION,
                        result.next_question.prompt,
                        sender_id=None,
                    )

    async def _character_messages_from_chat(
        self,
        conn: asyncpg.Connection,
        chat: ChatSystem,
        limit: int = 30,
    ) -> list[dict[str, str]]:
        history = [{"role": "system", "content": CHARACTER_SYSTEM_PROMPT}]
        segment = await chat.get_messages(conn, limit, log=gl_log)
        if isinstance(segment, ServiceError):
            return history

        for msg in segment.messages:
            if not msg.text:
                continue
            role = "user" if msg.kind == MessageKind.PLAYER else "assistant"
            history.append({"role": role, "content": msg.text})
        return history

    async def _handle_character_message_llm(
        self,
        conn: asyncpg.Connection,
        player: Player,
        session: CharacterCreationSession,
        message: str,
        chat: ChatSystem,
    ) -> bool:
        if not session.messages:
            session.messages = await self._character_messages_from_chat(conn, chat)
            last = session.messages[-1] if session.messages else None
            if (
                not last
                or last.get("role") != "user"
                or last.get("content") != message.strip()
            ):
                session.messages.append({"role": "user", "content": message.strip()})
        else:
            session.messages.append({"role": "user", "content": message.strip()})

        try:
            response = await create_chat_completion(
                model=CHARACTER_MODEL,
                messages=session.messages,
                tools=[CHARACTER_PROFILE_TOOL],
                tool_choice="auto",
                temperature=0.4,
            )
        except Exception as exc:
            self._append_llm_log(
                scope="character_creation",
                model=CHARACTER_MODEL,
                prompt=list(session.messages),
                response=None,
                player_id=player.user.id,
                error_text=str(exc),
            )
            await self._persist_state(conn)
            session.use_llm = False
            session.messages = []
            return False

        msg = response.choices[0].message
        tool_args = extract_tool_call_args(msg, "submit_character_profile")
        response_text = (msg.content or "").strip() or None

        self._append_llm_log(
            scope="character_creation",
            model=CHARACTER_MODEL,
            prompt=list(session.messages),
            response=tool_args or response_text,
            player_id=player.user.id,
        )

        if tool_args:

            def _safe_int(value: object, fallback: int) -> int:
                try:
                    return int(value)
                except (TypeError, ValueError):
                    return fallback

            profile = CharacterProfile(
                name=str(tool_args.get("name") or player.user.name or "Unnamed"),
                concept=str(tool_args.get("concept") or "Wanderer"),
                strength=max(1, min(10, _safe_int(tool_args.get("strength"), 5))),
                dexterity=max(1, min(10, _safe_int(tool_args.get("dexterity"), 5))),
                intelligence=max(
                    1, min(10, _safe_int(tool_args.get("intelligence"), 5))
                ),
                lore=str(tool_args.get("lore") or "A story yet to be written."),
            )
            session.completed = True
            self.character_sessions[player.user.id] = session
            self._set_character(player.user.id, profile)
            await self._persist_state(conn)
            await chat.clear_suggestions()
            await chat.send_message(
                conn,
                MessageKind.CHARACTER_CREATION,
                "Character complete. You can now mark ready.",
                sender_id=None,
                metadata={"character": profile.to_dict()},
            )
            return True

        if response_text:
            session.messages.append({"role": "assistant", "content": response_text})
            await chat.clear_suggestions()
            for suggestion in self._character_suggestions_from_text(response_text):
                await chat.add_suggestion(suggestion)
            await chat.send_message(
                conn,
                MessageKind.CHARACTER_CREATION,
                response_text,
                sender_id=None,
            )
            await self._persist_state(conn)
            return True

        fallback = "Tell me more about your character."
        session.messages.append({"role": "assistant", "content": fallback})
        await chat.clear_suggestions()
        for suggestion in self._character_suggestions_from_text(fallback):
            await chat.add_suggestion(suggestion)
        await chat.send_message(
            conn,
            MessageKind.CHARACTER_CREATION,
            fallback,
            sender_id=None,
        )
        await self._persist_state(conn)
        return True

    async def _handle_advice_message(
        self,
        player_id: int,
        message: str,
        chat: ChatSystem,
        owner_id: int | None,
    ):
        if owner_id is not None and owner_id != player_id:
            return

        if self.db_pool is None:
            return

        character = self._get_character(player_id)
        response = build_advice_response(message, self.state, character)
        suggestions = suggest_actions(self.state, character)
        async with self.db_pool.acquire() as conn:
            await chat.send_message(
                conn,
                MessageKind.GENERAL_INFO,
                response,
                sender_id=None,
            )
        await chat.clear_suggestions()
        for suggestion in suggestions:
            await chat.add_suggestion(suggestion)

    async def _notify_game_not_started(self, player_id: int):
        if self.db_pool is None:
            return
        player = self.player_states.get(player_id)
        if player is None or player.player_chat is None:
            return
        async with self.db_pool.acquire() as conn:
            await player.player_chat.send_message(
                conn,
                MessageKind.SYSTEM,
                "The game has not started yet.",
                sender_id=None,
            )

    async def _queue_action(self, player_id: int, text: str):
        if self.status != GameStatus.PLAYING:
            await self._notify_game_not_started(player_id)
            return

        async with self.action_lock:
            self.pending_actions = [
                action
                for action in self.pending_actions
                if action.player_id != player_id
            ]
            self.pending_actions.append(PendingAction(player_id=player_id, text=text))
            self.action_event.set()

    async def _collect_actions(self) -> list[PendingAction]:
        async with self.action_lock:
            actions = list(self.pending_actions)
            self.pending_actions.clear()
            self.action_event.clear()
        return actions

    def _build_auto_actions(self, existing_ids: set[int]) -> list[PendingAction]:
        actions: list[PendingAction] = []
        for player in self.player_states.values():
            if player.is_spectator or player.user.id in existing_ids:
                continue
            if player.is_joined:
                continue
            actions.append(
                PendingAction(
                    player_id=player.user.id,
                    text="holds position and keeps watch",
                    is_auto=True,
                )
            )
        return actions

    async def _resolve_actions(
        self,
        conn: asyncpg.Connection,
        actions: list[PendingAction],
    ):
        if not actions:
            return

        async with self.lock:
            self.state = ensure_game_state(self.state)
            inputs: list[PlayerAction] = []
            for action in actions:
                player = self.player_states.get(action.player_id)
                if player is None or player.is_spectator:
                    continue
                character = self._get_character(action.player_id)
                if character is None:
                    character = default_character_profile(player.user.name)
                    self._set_character(action.player_id, character)
                inputs.append(
                    PlayerAction(
                        player_id=action.player_id,
                        player_name=player.user.name,
                        text=action.text,
                        character=character,
                        is_auto=action.is_auto,
                    )
                )

            if not inputs:
                return

            summaries = [summarize_action(action, self.state) for action in inputs]
            if self._llm_enabled():
                resolved = await self._resolve_actions_with_llm(
                    conn,
                    inputs,
                    summaries,
                )
                if resolved:
                    return
            resolution = resolve_turn(summaries, self.state)
            self.state = resolution.world_state

            for summary in resolution.summaries:
                player = self.player_states.get(summary.player_id)
                if player is None or player.player_chat is None:
                    continue
                narrative = resolution.player_narratives.get(summary.player_id, "")
                metadata = {
                    "roll": summary.roll,
                    "target": summary.target,
                    "stat": summary.stat_used,
                    "success": summary.success,
                    "auto": summary.is_auto,
                }
                await player.player_chat.send_message(
                    conn,
                    MessageKind.PRIVATE_INFO,
                    narrative,
                    sender_id=None,
                    metadata=metadata,
                )
                self._remember_for_player(summary.player_id, narrative)

            await self.game_chat.send_message(
                conn,
                MessageKind.PUBLIC_INFO,
                resolution.turn_summary,
                sender_id=None,
            )
            await self._persist_state(conn)

    async def _resolve_actions_with_llm(
        self,
        conn: asyncpg.Connection,
        actions: list[PlayerAction],
        summaries: list[ActionSummary],
    ) -> bool:
        next_turn = int(self.state.get("turn", 0)) + 1
        reports = []
        action_map = {action.player_id: action for action in actions}
        for action, summary in zip(actions, summaries):
            report = await self._local_llm_action_report(
                action,
                summary,
                turn=next_turn,
            )
            if not report:
                report = summary.dm_summary()
            reports.append(
                {
                    "player_id": summary.player_id,
                    "player_name": summary.player_name,
                    "report": report,
                }
            )

        dm_result = await self._dm_resolve_turn_llm(reports, turn=next_turn)
        if not dm_result:
            return False

        summary_text = str(dm_result.get("summary", "")).strip()
        if not summary_text:
            return False

        world_update = dm_result.get("world_update") or {}
        if not isinstance(world_update, dict):
            world_update = {}

        world = self.state.setdefault("world", {})
        scene = world_update.get("scene")
        if scene:
            world["scene"] = str(scene)
        location = world_update.get("location")
        if location:
            world["location"] = str(location)
        if "threat" in world_update:
            try:
                world["threat"] = max(0, min(5, int(world_update["threat"])))
            except (TypeError, ValueError):
                pass
        npcs = world_update.get("npcs")
        if isinstance(npcs, list):
            world["npcs"] = [str(npc) for npc in npcs if npc]

        self.state["turn"] = next_turn
        timeline = self.state.setdefault("timeline", [])
        timeline.append({"turn": next_turn, "summary": summary_text})

        consequences: dict[int, str] = {}
        raw_consequences = dm_result.get("player_consequences") or []
        if isinstance(raw_consequences, list):
            for item in raw_consequences:
                if not isinstance(item, dict):
                    continue
                try:
                    player_id = int(item.get("player_id"))
                except (TypeError, ValueError):
                    continue
                text = str(item.get("text") or "").strip()
                if text:
                    consequences[player_id] = text

        for summary in summaries:
            player = self.player_states.get(summary.player_id)
            if player is None or player.player_chat is None:
                continue
            action = action_map.get(summary.player_id)
            consequence = consequences.get(summary.player_id)
            narrative = None
            if action is not None and consequence:
                narrative = await self._local_llm_narrative(
                    action,
                    consequence,
                    turn=next_turn,
                )
            if not narrative:
                narrative = self._fallback_narrative(summary)

            metadata = {
                "roll": summary.roll,
                "target": summary.target,
                "stat": summary.stat_used,
                "success": summary.success,
                "auto": summary.is_auto,
            }
            await player.player_chat.send_message(
                conn,
                MessageKind.PRIVATE_INFO,
                narrative,
                sender_id=None,
                metadata=metadata,
            )
            self._remember_for_player(summary.player_id, narrative)

        await self.game_chat.send_message(
            conn,
            MessageKind.PUBLIC_INFO,
            summary_text,
            sender_id=None,
        )
        await self._persist_state(conn)
        return True

    async def _local_llm_action_report(
        self,
        action: PlayerAction,
        summary: ActionSummary,
        *,
        turn: int,
    ) -> str | None:
        memory = self._format_player_memory(action.player_id)
        prompt = (
            f"Player: {action.player_name} (id {action.player_id})\n"
            f"Character: {self._character_card(action.character)}\n"
            f"Known memory:\n{memory}\n"
            f"Action: {action.text}\n"
            f"Outcome: {'success' if summary.success else 'failure'}, "
            f"stat={summary.stat_used}, roll={summary.roll}, target={summary.target}."
        )
        if action.is_auto:
            prompt += "\nThis was an auto action."

        messages = [
            {"role": "system", "content": PLAYER_ACTION_SYSTEM_PROMPT},
            {"role": "user", "content": prompt},
        ]
        try:
            response = await create_chat_completion(
                model=PLAYER_MODEL,
                messages=messages,
                temperature=0.6,
            )
        except Exception as exc:
            self._append_llm_log(
                scope="player_action",
                model=PLAYER_MODEL,
                prompt=messages,
                response=None,
                player_id=action.player_id,
                turn=turn,
                error_text=str(exc),
            )
            return None

        msg = response.choices[0].message
        text = (msg.content or "").strip()
        self._append_llm_log(
            scope="player_action",
            model=PLAYER_MODEL,
            prompt=messages,
            response=text or None,
            player_id=action.player_id,
            turn=turn,
        )
        return text or None

    async def _dm_resolve_turn_llm(
        self,
        reports: list[dict[str, str | int]],
        *,
        turn: int,
    ) -> dict | None:
        world = self.state.get("world", {})
        timeline = self.state.get("timeline", [])
        recent_timeline = timeline[-3:] if timeline else []
        timeline_text = (
            "\n".join(
                f"- Turn {item.get('turn')}: {item.get('summary')}"
                for item in recent_timeline
                if isinstance(item, dict)
            )
            or "None."
        )

        reports_text = "\n".join(
            f"- [{item['player_id']} {item['player_name']}]: {item['report']}"
            for item in reports
        )

        raw_npcs = world.get("npcs") or []
        if isinstance(raw_npcs, list):
            npcs = [str(npc) for npc in raw_npcs if npc]
        else:
            npcs = [str(raw_npcs)]

        prompt = (
            "World state:\n"
            f"- Title: {world.get('title', '')}\n"
            f"- Scene: {world.get('scene', '')}\n"
            f"- Location: {world.get('location', '')}\n"
            f"- Threat: {world.get('threat', '')}\n"
            f"- NPCs: {', '.join(npcs)}\n"
            "Recent timeline:\n"
            f"{timeline_text}\n"
            "Player reports:\n"
            f"{reports_text}"
        )

        messages = [
            {"role": "system", "content": DM_SYSTEM_PROMPT},
            {"role": "user", "content": prompt},
        ]
        tooling = self._get_tooling()
        lua_tool_defs: list[dict[str, object]] = []
        lua_tool_names: set[str] = set()
        if tooling is not None:
            _, lua_tool_defs, lua_tool_names = tooling

        tools = [DM_RESOLVE_TOOL] + lua_tool_defs
        tool_choice: dict[str, object] | str | None
        if lua_tool_defs:
            tool_choice = "auto"
        else:
            tool_choice = {"type": "function", "function": {"name": "resolve_turn"}}

        max_steps = 4
        for _ in range(max_steps):
            try:
                response = await create_chat_completion(
                    model=DM_MODEL,
                    messages=messages,
                    tools=tools,
                    tool_choice=tool_choice,
                    temperature=0.7,
                )
            except Exception as exc:
                self._append_llm_log(
                    scope="dm",
                    model=DM_MODEL,
                    prompt=messages,
                    response=None,
                    turn=turn,
                    error_text=str(exc),
                )
                return None

            msg = response.choices[0].message
            tool_calls = extract_tool_calls(msg)
            if not tool_calls:
                response_text = (msg.content or "").strip() or None
                self._append_llm_log(
                    scope="dm",
                    model=DM_MODEL,
                    prompt=messages,
                    response=response_text,
                    turn=turn,
                )
                return None

            resolve_call = None
            other_calls: list[dict[str, object]] = []
            for call in tool_calls:
                name = call.get("name")
                if name == "resolve_turn":
                    resolve_call = call
                else:
                    other_calls.append(call)

            if resolve_call is not None and not other_calls:
                tool_args = resolve_call.get("args")
                if not isinstance(tool_args, dict):
                    return None
                self._append_llm_log(
                    scope="dm",
                    model=DM_MODEL,
                    prompt=messages,
                    response=tool_args,
                    turn=turn,
                )
                return tool_args

            self._append_llm_log(
                scope="dm",
                model=DM_MODEL,
                prompt=messages,
                response={
                    "tool_calls": [
                        {"name": call.get("name"), "args": call.get("args")}
                        for call in tool_calls
                    ]
                },
                turn=turn,
            )

            messages.append(self._tool_call_message(tool_calls, msg.content))

            for call in other_calls:
                name = call.get("name")
                if not isinstance(name, str) or not name:
                    continue
                params = call.get("args")
                if not isinstance(params, dict):
                    params = {}

                if name not in lua_tool_names:
                    tool_result: dict[str, object] = {"error": f"Unknown tool: {name}"}
                else:
                    tool_result = await self._run_lua_tool(name, params)

                tool_call_id = call.get("id")
                if not tool_call_id:
                    continue
                messages.append(
                    {
                        "role": "tool",
                        "tool_call_id": tool_call_id,
                        "content": json.dumps(tool_result, ensure_ascii=False),
                    }
                )

            if resolve_call is not None:
                continue

        return None

    async def _local_llm_narrative(
        self,
        action: PlayerAction,
        consequence: str,
        *,
        turn: int,
    ) -> str | None:
        memory = self._format_player_memory(action.player_id)
        prompt = (
            f"Player: {action.player_name} (id {action.player_id})\n"
            f"Character: {self._character_card(action.character)}\n"
            f"Known memory:\n{memory}\n"
            f"DM consequence: {consequence}"
        )
        messages = [
            {"role": "system", "content": PLAYER_NARRATIVE_SYSTEM_PROMPT},
            {"role": "user", "content": prompt},
        ]
        try:
            response = await create_chat_completion(
                model=PLAYER_MODEL,
                messages=messages,
                temperature=0.7,
            )
        except Exception as exc:
            self._append_llm_log(
                scope="player_narrative",
                model=PLAYER_MODEL,
                prompt=messages,
                response=None,
                player_id=action.player_id,
                turn=turn,
                error_text=str(exc),
            )
            return None

        msg = response.choices[0].message
        text = (msg.content or "").strip()
        self._append_llm_log(
            scope="player_narrative",
            model=PLAYER_MODEL,
            prompt=messages,
            response=text or None,
            player_id=action.player_id,
            turn=turn,
        )
        return text or None

    def _fallback_narrative(self, summary: ActionSummary) -> str:
        if summary.success:
            outcome = "You steady your breath and act. The attempt works in your favor."
        else:
            outcome = "You move, but the attempt slips. The danger tightens its grip."
        return f"You attempt: {summary.text}. {outcome}"

    async def _announce_game_start(self, conn: asyncpg.Connection):
        world = self.state.get("world", {})
        intro = f"Game started. {world.get('scene', '')}".strip()
        await self.game_chat.send_message(
            conn,
            MessageKind.SYSTEM,
            "The game has begun.",
            sender_id=None,
        )
        for player in self.player_states.values():
            if player.is_spectator or player.player_chat is None:
                continue
            await player.player_chat.send_message(
                conn,
                MessageKind.PUBLIC_INFO,
                intro,
                sender_id=None,
            )
            suggestions = suggest_actions(
                self.state, self._get_character(player.user.id)
            )
            await player.player_chat.clear_suggestions()
            for suggestion in suggestions:
                await player.player_chat.add_suggestion(suggestion)

    async def game_loop(self):
        if self.db_pool is None:
            return

        next_auto = time.monotonic() + AUTO_ACTION_INTERVAL

        try:
            while True:
                timeout = max(0.0, next_auto - time.monotonic())
                try:
                    await asyncio.wait_for(self.action_event.wait(), timeout=timeout)
                    await asyncio.sleep(ACTION_BATCH_SECONDS)
                except asyncio.TimeoutError:
                    pass

                actions = await self._collect_actions()
                existing_ids = {action.player_id for action in actions}
                actions.extend(self._build_auto_actions(existing_ids))

                if actions:
                    async with self.db_pool.acquire() as conn:
                        await self._resolve_actions(conn, actions)

                next_auto = time.monotonic() + AUTO_ACTION_INTERVAL
        except asyncio.CancelledError:
            return
