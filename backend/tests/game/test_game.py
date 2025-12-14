import asyncio

import pytest

from game.game import (
    GameSystem,
    GameStatusEvent,
    PlayerReadyEvent,
    PlayerJoinedEvent,
    PlayerLeftEvent,
    PlayerPromotedEvent,
    PlayerSpectatorEvent,
)
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


@pytest.mark.asyncio
async def test_player_can_join_multiple_games(db, universe):
    host = await create_test_user(db, "host")
    player = await create_test_user(db, "player")
    world = await universe.create_world(db, "world", host.id, True)

    game1 = await universe.create_game(db, host.id, world.id, "g1", True, 2)
    game2 = await universe.create_game(db, host.id, world.id, "g2", True, 2)
    game_system1 = GameSystem.of(game1.id)
    game_system2 = GameSystem.of(game2.id)

    await game_system1.connect_player(db, player.id)
    await game_system2.connect_player(db, player.id)

    joined_count = await db.fetchval(
        "SELECT count(*) FROM game_players WHERE user_id = $1 AND is_joined IS TRUE",
        player.id,
    )
    assert joined_count == 2

    joined_games = await universe.get_games(db, 10, 0, requester_id=player.id, joined_only=True)
    assert {g.name for g in joined_games} == {"g1", "g2"}


@pytest.mark.asyncio
async def test_player_join_and_leave(db, universe):
    user1 = await create_test_user(db, "user1")
    user2 = await create_test_user(db, "user2")
    world = await universe.create_world(db, "world", user1.id, True)
    game = await universe.create_game(db, user1.id, world.id, "test_game", True, 2)
    game_system = GameSystem.of(game.id)

    # user2 joins
    await game_system.connect_player(db, user2.id)
    assert user2.id in game_system.player_states
    assert game_system.player_states[user2.id].is_joined

    # user2 leaves
    await game_system.disconnect_player(db, user2.id, kick_immediately=True)
    await asyncio.sleep(0)  # Allow kick task to run
    assert user2.id not in game_system.player_states

    # user1 leaves, which should terminate the game
    await game_system.disconnect_player(db, user1.id, kick_immediately=True)
    await asyncio.sleep(0)  # Allow kick task to run
    assert not game_system.player_states
    assert game_system.status == GameStatus.ARCHIVED

    events = [
        event.event for event in await universe.stop_and_gather_events()
        if isinstance(event, UniverseGameEvent)
    ]

    joined_events = [e for e in events if isinstance(e, PlayerJoinedEvent)]
    assert len(joined_events) == 1
    assert joined_events[0].player.user.id == user2.id

    left_events = [e for e in events if isinstance(e, PlayerLeftEvent)]
    assert len(left_events) == 2  # user1 and user2

    archived_events = [e for e in events if isinstance(e, GameStatusEvent) and e.new_status == GameStatus.ARCHIVED]
    assert len(archived_events) > 0


@pytest.mark.asyncio
async def test_host_migration(db, universe):
    user1 = await create_test_user(db, "user1")
    user2 = await create_test_user(db, "user2")
    world = await universe.create_world(db, "world", user1.id, True)
    game = await universe.create_game(db, user1.id, world.id, "test_game", True, 2)
    game_system = GameSystem.of(game.id)
    assert game_system.host_id == user1.id

    # user2 joins
    await game_system.connect_player(db, user2.id)

    # user1 (host) leaves
    await game_system.disconnect_player(db, user1.id, kick_immediately=True)

    assert user1.id not in game_system.player_states
    assert game_system.host_id == user2.id

    events = [
        event.event for event in await universe.stop_and_gather_events()
        if isinstance(event, UniverseGameEvent)
    ]

    promoted_events = [e for e in events if isinstance(e, PlayerPromotedEvent)]
    assert len(promoted_events) == 1
    assert promoted_events[0].old_host == user1.id
    assert promoted_events[0].new_host == user2.id


@pytest.mark.asyncio
async def test_spectator_flow(db, universe):
    user1 = await create_test_user(db, "user1")
    user2 = await create_test_user(db, "user2")
    user3 = await create_test_user(db, "user3")
    world = await universe.create_world(db, "world", user1.id, True)
    # Game with 1 player slot
    game = await universe.create_game(db, user1.id, world.id, "test_game", True, 1)
    game_system = GameSystem.of(game.id)

    # user2 tries to join, becomes spectator as game is full
    await game_system.connect_player(db, user2.id)
    assert user2.id in game_system.player_states
    assert game_system.player_states[user2.id].is_spectator

    # user1 (host) leaves
    await game_system.disconnect_player(db, user1.id, kick_immediately=True)

    # user2 is promoted to host but is still a spectator
    assert game_system.host_id == user2.id
    assert game_system.player_states[user2.id].is_spectator

    # user2 (now host) makes themself a player
    await game_system.make_spectator(db, user2.id, spectate=False, requester_id=user2.id)
    assert not game_system.player_states[user2.id].is_spectator
    assert game_system.num_non_spectators == 1

    # user3 joins, becomes spectator
    await game_system.connect_player(db, user3.id)
    assert game_system.player_states[user3.id].is_spectator

    # user2 tries to make user3 a player, but game is full
    result = await game_system.make_spectator(db, user3.id, spectate=False, requester_id=user2.id)
    assert result.code == "GAME_FULL"
    assert game_system.player_states[user3.id].is_spectator
