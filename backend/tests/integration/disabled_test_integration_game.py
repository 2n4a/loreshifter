import pytest

from app.auth import generate_jwt
from game.game import GameSystem, GameStatusEvent, PlayerReadyEvent
from lstypes.game import GameStatus
from game.universe import Universe, UniverseGameEvent
from game.user import create_test_user
from tests import postgres_connection_string, db
from tests.service import service
import aiohttp
import app.dependencies as deps

from app.dependencies import state, get_db


@pytest.mark.asyncio
@pytest.mark.timeout(2)
async def test_game_set_ready(service):
    async with aiohttp.ClientSession(base_url=service.url) as client:
        resp = await client.get("/api/v0/test-login")
        assert resp.status == 200
        body = await resp.json()

    user = body['user']
    token = body['token']
    user_id = user['id']

    async with deps.state.pg_pool.acquire() as conn:
        world = await service.universe.create_world(conn, 'world', user_id, True)
        game = await service.universe.create_game(conn, user_id, world.id, 'room', True, 1)

    async with aiohttp.ClientSession(base_url=service.url) as client:
        headers = {'Authentication': token}
        resp = await client.post(f"/api/v0/game/{game.id}/ready", headers=headers)
        assert resp.status == 200
        resp = await client.post(f"/api/v0/game/{game.id}/ready", headers=headers)
        assert resp.status == 200

    await service.stop()
    events = [
        event.event async for event in service.universe.listen()
        if isinstance(event, UniverseGameEvent)
    ]
    assert events == [
        GameStatusEvent(game_id=game.id, new_status=GameStatus.WAITING),
        PlayerReadyEvent(game_id=game.id, player_id=user.id, ready=True),
        PlayerReadyEvent(game_id=game.id, player_id=user.id, ready=False),
    ]
