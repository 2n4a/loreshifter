from fastapi import APIRouter
from pydantic import BaseModel

from app.dependencies import Conn, AuthDep, U
from game.game import GameSystem

router = APIRouter()


class GameIn(BaseModel):
    public: bool = False
    name: str | None = None
    world_id: int
    max_players: int = 1


@router.post("/api/v0/game")
async def post_game(conn: Conn, user: AuthDep, universe: U, game: GameIn):
    return await universe.create_game(conn, user.id, game.world_id, game.name, game.public, game.max_players)


@router.post("/api/v0/game/{game_id}/ready")
async def ready(game_id: int, conn: Conn, user: AuthDep):
    GameSystem.of(game_id).set_ready(conn, user.id)
