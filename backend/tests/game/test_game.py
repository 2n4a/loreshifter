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

@pytest.mark.asyncio
async def test_get_games(db, universe):
    user1 = await create_test_user(db, "user1")
    user2 = await create_test_user(db, "user2")
    world1 = await universe.create_world(db, "w1", user1.id, True)
    world2 = await universe.create_world(db, "w2", user2.id, True)
    await universe.create_game(db, user1.id, world1.id, "g1", True, 2)
    await universe.create_game(db, user2.id, world2.id, "g2", True, 2)
    await universe.create_game(db, user1.id, world1.id, "g3", False, 2)
    await universe.create_game(db, user2.id, world2.id, "g4", False, 2)

    games = await universe.get_games(db, 10, 0, sort="asc", requester_id=user1.id)
    assert len(games) == 3
    assert games[0].name == "g1"
    assert games[1].name == "g2"
    assert games[2].name == "g3"

    games = await universe.get_games(db, 1, 0, sort="desc", public=True)
    assert len(games) == 1
    assert games[0].name == "g2"


@pytest.mark.asyncio
async def test_get_game(db, universe):
    user1 = await create_test_user(db, "user1")
    world1 = await universe.create_world(db, "w1", user1.id, True)
    game1 = await universe.create_game(db, user1.id, world1.id, "g1", True, 2)

    game = await universe.get_game(db, game1.id, requester_id=user1.id)
    assert game.name == "g1"

    game = await universe.get_game(db, -123)
    assert game.code == "GAME_NOT_FOUND"

@pytest.mark.asyncio
async def test_get_game_by_code(db, universe):
    user1 = await create_test_user(db, "user1")
    world1 = await universe.create_world(db, "w1", user1.id, True)
    game1 = await universe.create_game(db, user1.id, world1.id, "g1", True, 2)

    game = await universe.get_game_by_code(db, game1.code, requester_id=user1.id)
    assert game.name == "g1"

    game = await universe.get_game_by_code(db, "INVALID_CODE")
    assert game.code == "GAME_NOT_FOUND"
