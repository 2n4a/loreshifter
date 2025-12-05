import pytest

from game.game import GameSystem, GameStatusEvent, PlayerReadyEvent
from lstypes.game import GameStatus
from game.universe import Universe, UniverseGameEvent
from game.user import create_test_user
from tests import postgres_connection_string, db


@pytest.mark.asyncio
async def test_game_set_ready(db):
    user = await create_test_user(db)
    universe = Universe()
    world = await universe.create_world(db, "world", user.id, True)
    game = await universe.create_game(db, user.id, world.id, "room", True, 1)

    assert await GameSystem.set_ready(db, user.id, True)
    assert await GameSystem.set_ready(db, user.id, False)

    await universe.stop()

    events = [
        event.event async for event in universe.listen()
        if isinstance(event, UniverseGameEvent)
    ]
    assert events == [
        GameStatusEvent(game_id=game.id, new_status=GameStatus.WAITING),
        PlayerReadyEvent(game_id=game.id, player_id=user.id, ready=True),
        PlayerReadyEvent(game_id=game.id, player_id=user.id, ready=False),
    ]
