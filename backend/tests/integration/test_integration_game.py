import pytest
from tests.service import service
import aiohttp
import app.dependencies as deps


@pytest.mark.asyncio
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
        resp = await client.post(f"/api/v0/game/{game.id}/ready", headers=headers, json={"ready": False})
        assert resp.status == 200
