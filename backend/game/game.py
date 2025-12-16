import asyncio
import contextlib
import dataclasses
import datetime
from mimetypes import guess_all_extensions

import asyncpg

import config
import game.universe as universe
import game.chat
from game.chat import ChatSystem
from game.logger import gl_log
from game.utils import Timer, AsyncReentrantLock
from lstypes.chat import ChatType, ChatInterfaceType
from game.system import System
from lstypes.error import ServiceCode, ServiceError, error
from lstypes.game import GameStatus, GameOut, StateOut
from lstypes.player import PlayerOut
from lstypes.user import UserOut


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
    async def create_new(
        conn: asyncpg.Connection,
        g: GameOut,
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
        self.add_pipe(self.forward_chat_events(self.game_chat, None))

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
                self.add_pipe(self.forward_chat_events(player.character_chat, None))
            if player.player_chat is None:
                player.player_chat = await ChatSystem.create_or_load(
                    conn,
                    self.id,
                    ChatType.GAME,
                    player.user.id,
                    ChatInterfaceType.FOREIGN,
                    log=log,
                )
                self.add_pipe(self.forward_chat_events(player.player_chat, None))
            if player.advice_chat is None:
                player.advice_chat = await ChatSystem.create_or_load(
                    conn,
                    self.id,
                    ChatType.ADVICE,
                    player.user.id,
                    ChatInterfaceType.FOREIGN,
                    log=log,
                )
                self.add_pipe(self.forward_chat_events(player.advice_chat, None))
        return player

    async def stop(self):
        await self.game_chat.stop()
        for player in self.player_states.values():
            if player.character_chat is not None:
                await player.character_chat.stop()
            if player.player_chat is not None:
                await player.player_chat.stop()
            if player.advice_chat is not None:
                await player.advice_chat.stop()
        await super().stop()

    async def forward_chat_events(self, chat_: ChatSystem, owner_id: int | None):
        async for event in chat_.listen():
            self.emit(GameChatEvent(
                game_id=self.id, chat_id=chat_.id, owner_id=owner_id, event=event
            ))

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

            await log.ainfo("Removed player from the game")

            self.emit(
                PlayerLeftEvent(self.id, player=player.get_player_out(self.host_id))
            )

            async def kick_task(dont_wait: bool = False):
                nonlocal log

                if not dont_wait:
                    await player.kick_timer.wait()

                with contextlib.suppress(asyncio.CancelledError):
                    async with self.lock:
                        player.kick_task = None

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

            if kick_immediately:
                await kick_task(dont_wait=True)
            else:
                player.kick_task = asyncio.Task(
                    kick_task(), name=f"kick_task_player{player_id}_game{self.id}"
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
                await self.disconnect_player(conn, player.user.id, log=log)
                player.kick_timer.trigger_early()

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

    async def game_loop(self):
        try:
            while True:
                await asyncio.sleep(3600)
        except asyncio.CancelledError:
            return
