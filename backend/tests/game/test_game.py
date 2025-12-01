import pytest

from game.game import Game, PlayerReadyEvent
from game.universe import Universe
from game.user import create_test_user
from tests import postgres_connection_string, db

@pytest.mark.asyncio
async def test_game_set_ready(db):
    user = await create_test_user(db)
    userverse = Universe()
    world = await userverse.create_world(db, "world", user.id, True)
    game = await Game.create_game(db, user.id, world.id, "room", True, 1)

    assert await Game.set_ready(db, user.id, True)
    await game.stop()
    async for event in game.listen():
        if isinstance(event, PlayerReadyEvent):
            assert event.ready
            assert event.player_id == user.id
            assert event.game_id == game.id
