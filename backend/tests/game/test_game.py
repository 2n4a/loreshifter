import pytest

from game.game import GameSystem, GameStatusEvent, PlayerReadyEvent
from lstypes.game import GameStatus, GameOut
from game.universe import UniverseGameEvent
from game.user import create_test_user


@pytest.mark.asyncio
async def test_game_set_ready(db, universe):
    user = await create_test_user(db)
    world = await universe.create_world(db, "world", user.id, True)
    game = await universe.create_game(db, user.id, world.id, "room", True, 1)

    game_system = GameSystem.of(game.id)
    assert await game_system.set_ready(db, user.id, True) is None
    assert await game_system.set_ready(db, user.id, False) is None
    assert (await game_system.set_ready(db, -123, False)).code == "PLAYER_NOT_FOUND"

    events = [
        event.event for event in await universe.stop_and_gather_events()
        if isinstance(event, UniverseGameEvent)
    ]
    assert events == [
        GameStatusEvent(game_id=game.id, new_status=GameStatus.WAITING),
        PlayerReadyEvent(game_id=game.id, player_id=user.id, ready=True),
        PlayerReadyEvent(game_id=game.id, player_id=user.id, ready=False),
    ]

@pytest.mark.asyncio
async def test_create_game(db, universe):
    user = await create_test_user(db)
    world = await universe.create_world(db, "test_world", user.id, True)
    game = await universe.create_game(db, user.id, world.id, "test_room", True, 1)
    assert isinstance(game, GameOut)
