from typing import Literal, Annotated

from fastapi import APIRouter, Query
from pydantic import BaseModel

from app.api_error import raise_api_error, raise_for_service_error, unwrap
from app.dependencies import Conn, AuthDep, U, UserDep, Log
from lstypes.player import PlayerOut
from game.game import GameSystem
from lstypes.game import GameOut

router = APIRouter()


class GameIn(BaseModel):
    public: bool = False
    name: str | None = None
    world_id: int
    max_players: int = 1


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
        game.name,
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
        order=sort,
        sort=order,
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


class ReadyIn(BaseModel):
    ready: bool = True


@router.post("/api/v0/game/{game_id}/ready")
async def ready(
        game_id: int,
        conn: Conn,
        user: AuthDep,
        log: Log,
        ready: ReadyIn | None = None,
) -> PlayerOut:
    game = GameSystem.of(game_id)
    if game is None:
        raise_api_error(404, "GameNotFound", "Game not found")
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
