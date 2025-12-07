from typing import Literal, Annotated

from fastapi import APIRouter, Query
from pydantic import BaseModel

from app.dependencies import Conn, AuthDep, U, UserDep, Log
from game.game import GameSystem
from lstypes.error import ServiceError
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
) -> GameOut | ServiceError:
    return await universe.create_game(
        conn,
        user.id,
        game.world_id,
        game.name,
        game.public,
        game.max_players,
        log=log
    )


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
        filter_: str | None = None,
        search: str | None = None,
        include_archived: bool = False,
) -> list[GameOut] | ServiceError:
    _ = filter_
    _ = search

    return await universe.get_games(
        conn,
        limit,
        offset,
        sort,
        order,
        public,
        requester_id=user.id if user else None,
        include_archived=include_archived,
        log=log,
    )


@router.get("/api/v0/game/{game_id}")
async def get_game(
        conn: Conn,
        user: UserDep,
        universe: U,
        log: Log,
        game_id: int,
) -> GameOut | ServiceError:
    return await universe.get_game(
        conn,
        game_id,
        requester_id=user.id if user else None,
        log=log,
    )


@router.get("/api/v0/game/code/{game_code}")
async def get_game_by_code(
        conn: Conn,
        user: UserDep,
        universe: U,
        log: Log,
        game_code: str,
) -> GameOut | ServiceError:
    return await universe.get_game_by_code(
        conn,
        game_code,
        requester_id=user.id if user else None,
        log=log,
    )


@router.post("/api/v0/game/{game_id}/ready")
async def ready(
        game_id: int,
        conn: Conn,
        user: AuthDep,
        log: Log,
):
    GameSystem.of(game_id).set_ready(conn, user.id, log=log)
