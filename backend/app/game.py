import typing
from typing import Literal, Annotated

from fastapi import APIRouter, Query
from pydantic import BaseModel, ConfigDict, Field

from app.dependencies import Conn, AuthDep, U, UserDep, Log
from game.chat import ChatSystem
from lstypes.error import ServiceCode, raise_for_service_error, raise_service_error, unwrap
from lstypes.player import PlayerOut
from game.game import GameSystem
from lstypes.chat import ChatSegmentOut
from lstypes.game import GameOut, GameStatus, StateOut
from lstypes.message import MessageKind, MessageOut

router = APIRouter()


class GameIn(BaseModel):
    public: bool = False
    name: str | None = None
    world_id: int
    max_players: int = 1


class GameUpdateIn(BaseModel):
    public: bool | None = None
    name: str | None = None
    host_id: int | None = None
    max_players: int | None = Field(default=None, ge=1)


class MessageIn(BaseModel):
    text: str
    special: str | None = None
    metadata: typing.Any = None


class PlayerIdIn(BaseModel):
    id: int


@router.post("/api/v0/game")
async def post_game(
        conn: Conn,
        user: AuthDep,
        universe: U,
        log: Log,
        game: GameIn,
) -> GameOut:
    return unwrap(await universe.create_game(
        conn,
        user.id,
        game.world_id,
        game.name or "Untitled game",
        game.public,
        game.max_players,
        log=log
    ))


@router.get("/api/v0/game")
async def get_games(
        conn: Conn,
        user: UserDep,
        universe: U,
        log: Log,
        limit: Annotated[int, Query(le=50, ge=1)] = 25,
        offset: int = 0,
        sort: Literal["createdAt"] = "createdAt",
        order: Literal["asc", "desc"] = "desc",
        public: bool = False,
        joined: bool = False,
        filter_: str | None = None,
        search: str | None = None,
        include_archived: bool = False,
) -> list[GameOut]:
    _ = filter_
    _ = search

    return unwrap(await universe.get_games(
        conn,
        limit,
        offset,
        sort=sort,
        order=order,
        public=public,
        joined_only=joined,
        requester_id=user.id if user else None,
        include_archived=include_archived,
        log=log,
    ))


@router.get("/api/v0/game/{game_id}")
async def get_game(
        conn: Conn,
        user: UserDep,
        universe: U,
        log: Log,
        game_id: int,
) -> GameOut:
    return unwrap(await universe.get_game(
        conn,
        game_id,
        requester_id=user.id if user else None,
        log=log,
    ))


@router.get("/api/v0/game/code/{game_code}")
async def get_game_by_code(
        conn: Conn,
        user: UserDep,
        universe: U,
        log: Log,
        game_code: str,
) -> GameOut:
    return unwrap(await universe.get_game_by_code(
        conn,
        game_code,
        requester_id=user.id if user else None,
        log=log,
    ))


@router.put("/api/v0/game/{game_id}")
async def put_game(
        game_id: int,
        conn: Conn,
        user: AuthDep,
        universe: U,
        log: Log,
        update: GameUpdateIn,
) -> GameOut:
    game = unwrap(await universe.get_game(conn, game_id, requester_id=user.id, log=log))
    if game.host_id != user.id:
        raise_service_error(401, ServiceCode.UNAUTHORIZED, "Not enough permissions")

    if game.status != GameStatus.WAITING:
        raise_service_error(400, ServiceCode.GAME_ALREADY_STARTED, "Game already started")

    patch = update.model_dump(exclude_unset=True)
    if "host_id" in patch and patch["host_id"] is not None:
        if patch["host_id"] not in {p.user.id for p in game.players}:
            raise_service_error(400, ServiceCode.GAME_NEW_HOST_NOT_FOUND, "Player not found")

    if "max_players" in patch and patch["max_players"] is not None:
        joined_non_spectators = [p for p in game.players if p.is_joined and not p.is_spectator]
        if patch["max_players"] < len(joined_non_spectators):
            raise_service_error(
                400,
                ServiceCode.GAME_MAX_PLAYERS_TOO_SMALL,
                "max_players cannot be less than the number of joined players",
            )

    game_system = await _get_or_load_game_system(universe, conn, game)

    settings_error = await game_system.update_settings(
        conn,
        public=patch.get("public"),
        name=patch.get("name"),
        max_players=patch.get("max_players"),
        log=log,
    )
    if settings_error is not None:
        raise_for_service_error(settings_error)

    if "host_id" in patch and patch["host_id"] is not None and patch["host_id"] != game_system.host_id:
        host_err = await game_system.make_host(conn, patch["host_id"], requester_id=user.id, log=log)
        if host_err is not None:
            raise_for_service_error(host_err)

    return unwrap(await universe.get_game(conn, game_id, requester_id=user.id, log=log))


class ReadyIn(BaseModel):
    ready: bool = True


@router.post("/api/v0/game/{game_id}/ready")
async def ready(
        game_id: int,
        conn: Conn,
        user: AuthDep,
        universe: U,
        log: Log,
        ready: ReadyIn | None = None,
) -> PlayerOut:
    game_out = unwrap(await universe.get_game(conn, game_id, requester_id=user.id, log=log))
    game = await _get_or_load_game_system(universe, conn, game_out)
    ready = ready.ready if ready else True
    result = await game.set_ready(conn, user.id, ready, log=log)
    if result is not None:
        raise_for_service_error(result)
    return unwrap(await game.get_player(conn, user.id, log=log))


async def _get_or_load_game_system(
        universe: U,
        conn: Conn,
        game: GameOut,
) -> GameSystem:
    game_system = GameSystem.of(game.id)
    if game_system is not None:
        return game_system

    game_system = await GameSystem.create_new(conn, game)
    universe.add_game(game_system)
    return game_system


def _require_joined_player(game_system: GameSystem, user_id: int):
    player = game_system.player_states.get(user_id)
    if player is None or not player.is_joined:
        raise_service_error(400, ServiceCode.PLAYER_NOT_IN_GAME, "Player not in game")
    return player


def _require_host(game_system: GameSystem, user_id: int):
    if game_system.host_id != user_id:
        raise_service_error(401, ServiceCode.NOT_HOST, "Only host can perform this action")


async def _get_chat_info(conn: Conn, game_id: int, chat_id: int):
    return await conn.fetchrow(
        "SELECT id, owner_id FROM chats WHERE id = $1 AND game_id = $2",
        chat_id,
        game_id,
    )


@router.get("/api/v0/game/{game_id}/state")
async def get_game_state(
        game_id: int,
        conn: Conn,
        user: AuthDep,
        universe: U,
        log: Log,
) -> StateOut:
    game = unwrap(await universe.get_game(conn, game_id, requester_id=user.id, log=log))
    game_system = await _get_or_load_game_system(universe, conn, game)
    _require_joined_player(game_system, user.id)
    return unwrap(await game_system.get_state(conn, requester_id=user.id, log=log))


@router.get("/api/v0/game/{game_id}/chat/{chat_id}")
async def get_game_chat_segment(
        game_id: int,
        chat_id: int,
        conn: Conn,
        user: AuthDep,
        universe: U,
        log: Log,
        before: int | None = None,
        after: int | None = None,
        limit: Annotated[int, Query(ge=1, le=500)] = 50,
) -> ChatSegmentOut:
    game = unwrap(await universe.get_game(conn, game_id, requester_id=user.id, log=log))
    game_system = await _get_or_load_game_system(universe, conn, game)
    _require_joined_player(game_system, user.id)

    chat_info = await _get_chat_info(conn, game_id, chat_id)
    if chat_info is None:
        raise_service_error(404, ServiceCode.CHAT_NOT_FOUND, "Chat not found")

    is_host = user.id == game_system.host_id
    if chat_info["owner_id"] is not None and chat_info["owner_id"] != user.id and not is_host:
        raise_service_error(401, ServiceCode.CANNOT_ACCESS_CHAT, "Cannot access chat")

    chat_system = unwrap(await ChatSystem.load_by_id(conn, chat_id, log=log))
    return unwrap(await chat_system.get_messages(
        conn,
        limit,
        before_message_id=before,
        after_message_id=after,
        log=log,
    ))


@router.post("/api/v0/game/{game_id}/chat/{chat_id}/send")
async def send_game_chat_message(
        game_id: int,
        chat_id: int,
        message: MessageIn,
        conn: Conn,
        user: AuthDep,
        universe: U,
        log: Log,
) -> MessageOut:
    game = unwrap(await universe.get_game(conn, game_id, requester_id=user.id, log=log))
    game_system = await _get_or_load_game_system(universe, conn, game)
    _require_joined_player(game_system, user.id)

    chat_info = await _get_chat_info(conn, game_id, chat_id)
    if chat_info is None:
        raise_service_error(404, ServiceCode.CHAT_NOT_FOUND, "Chat not found")

    is_host = user.id == game_system.host_id
    if chat_info["owner_id"] is not None and chat_info["owner_id"] != user.id and not is_host:
        raise_service_error(401, ServiceCode.CANNOT_ACCESS_CHAT, "Cannot access chat")

    chat_system = unwrap(await ChatSystem.load_by_id(conn, chat_id, log=log))
    sent = unwrap(await chat_system.send_message(
        conn,
        MessageKind.PLAYER,
        message.text,
        sender_id=user.id,
        special=message.special,
        metadata=message.metadata,
        log=log,
    ))
    return sent.msg


@router.post("/api/v0/game/{game_id}/kick")
async def kick_player(
        game_id: int,
        body: PlayerIdIn,
        conn: Conn,
        user: AuthDep,
        universe: U,
        log: Log,
) -> PlayerOut:
    game = unwrap(await universe.get_game(conn, game_id, requester_id=user.id, log=log))
    game_system = await _get_or_load_game_system(universe, conn, game)
    _require_joined_player(game_system, user.id)
    _require_host(game_system, user.id)

    target = game_system.player_states.get(body.id)
    if target is None or not target.is_joined:
        raise_service_error(404, ServiceCode.PLAYER_NOT_FOUND, "Player not found")

    kicked_player = unwrap(await game_system.get_player(conn, body.id, log=log))
    err = await game_system.disconnect_player(conn, body.id, kick_immediately=True, requester_id=user.id, log=log)
    if err is not None:
        raise_for_service_error(err)
    return kicked_player


@router.post("/api/v0/game/{game_id}/promote")
async def promote_player(
        game_id: int,
        body: PlayerIdIn,
        conn: Conn,
        user: AuthDep,
        universe: U,
        log: Log,
) -> PlayerOut:
    game = unwrap(await universe.get_game(conn, game_id, requester_id=user.id, log=log))
    game_system = await _get_or_load_game_system(universe, conn, game)
    _require_joined_player(game_system, user.id)
    _require_host(game_system, user.id)

    target = game_system.player_states.get(body.id)
    if target is None or not target.is_joined:
        raise_service_error(404, ServiceCode.PLAYER_NOT_FOUND, "Player not found")

    err = await game_system.make_host(conn, body.id, requester_id=user.id, log=log)
    if err is not None:
        raise_for_service_error(err)
    return unwrap(await game_system.get_player(conn, body.id, log=log))


@router.post("/api/v0/game/{game_id}/start")
async def start_game(
        game_id: int,
        conn: Conn,
        user: AuthDep,
        universe: U,
        log: Log,
        force: bool = False,
) -> GameOut:
    game = unwrap(await universe.get_game(conn, game_id, requester_id=user.id, log=log))
    game_system = await _get_or_load_game_system(universe, conn, game)
    _require_joined_player(game_system, user.id)

    err = await game_system.start_game(conn, force=force, requester_id=user.id, log=log)
    if err is not None:
        raise_for_service_error(err)
    return unwrap(await universe.get_game(conn, game_id, requester_id=user.id, log=log))


@router.post("/api/v0/game/{game_id}/restart")
async def restart_game(
        game_id: int,
        conn: Conn,
        user: AuthDep,
        universe: U,
        log: Log,
) -> GameOut:
    game = unwrap(await universe.get_game(conn, game_id, requester_id=user.id, log=log))
    game_system = await _get_or_load_game_system(universe, conn, game)
    _require_joined_player(game_system, user.id)
    _require_host(game_system, user.id)

    if game.status != GameStatus.FINISHED:
        raise_service_error(400, ServiceCode.GAME_NOT_FINISHED, "Game is not finished")

    joined_player_ids = [p.user.id for p in game_system.player_states.values() if p.is_joined]

    new_game = unwrap(await universe.create_game(
        conn,
        user.id,
        game.world.id,
        game.name,
        game.public,
        game.max_players,
        log=log,
    ))

    new_game_system = GameSystem.of(new_game.id)
    if new_game_system is None:
        raise_service_error(500, ServiceCode.SERVER_ERROR, "New game system not initialized")

    for player_id in joined_player_ids:
        if player_id == user.id:
            continue
        connect_err = await new_game_system.connect_player(conn, player_id, log=log)
        if connect_err is not None:
            raise_for_service_error(connect_err)

    return unwrap(await universe.get_game(conn, new_game.id, requester_id=user.id, log=log))


@router.post("/api/v0/game/{game_id}/join")
async def join_game(
        game_id: int,
        conn: Conn,
        user: AuthDep,
        universe: U,
        log: Log,
) -> GameOut:
    game = unwrap(await universe.get_game(conn, game_id, requester_id=user.id, log=log))

    game_system = await _get_or_load_game_system(universe, conn, game)
    result = await game_system.connect_player(conn, user.id, log=log)
    if result is not None:
        raise_for_service_error(result)

    return unwrap(await universe.get_game(conn, game_id, requester_id=user.id, log=log))


@router.post("/api/v0/game/code/{game_code}/join")
async def join_game_by_code(
        game_code: str,
        conn: Conn,
        user: AuthDep,
        universe: U,
        log: Log,
) -> GameOut:
    game = unwrap(await universe.get_game_by_code(conn, game_code, requester_id=user.id, log=log))

    game_system = await _get_or_load_game_system(universe, conn, game)
    result = await game_system.connect_player(conn, user.id, log=log)
    if result is not None:
        raise_for_service_error(result)

    return unwrap(await universe.get_game(conn, game.id, requester_id=user.id, log=log))


@router.post("/api/v0/game/{game_id}/leave")
async def leave_game(
        game_id: int,
        conn: Conn,
        user: AuthDep,
        universe: U,
        log: Log,
) -> dict[str, None]:
    game = unwrap(await universe.get_game(conn, game_id, requester_id=user.id, log=log))

    game_system = await _get_or_load_game_system(universe, conn, game)
    result = await game_system.disconnect_player(conn, user.id, requester_id=user.id, log=log)
    if result is not None:
        raise_for_service_error(result)
    return {}
