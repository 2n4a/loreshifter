import aiohttp
import pytest

from lstypes.error import ServiceError
import app.dependencies as deps
from tests.service import service


@pytest.mark.asyncio
async def test_error_responses_use_non_200_http_status_codes(service):
    async with aiohttp.ClientSession(base_url=service.url) as client:
        resp = await client.get("/api/v0/user/me")
        assert resp.status == 401
        body = await resp.json()
        assert body["code"] == "Unauthorized"

        resp = await client.get("/api/v0/login", params={"provider": "invalid"})
        assert resp.status == 400
        body = await resp.json()
        assert body["code"] == "InvalidProvider"

        resp = await client.get("/api/v0/login/callback/invalid")
        assert resp.status == 400
        body = await resp.json()
        assert body["code"] == "InvalidProvider"

        resp = await client.get("/api/v0/user/-123")
        assert resp.status == 404
        body = await resp.json()
        assert body["code"] == "UserNotFound"

        resp = await client.get("/api/v0/world/-123")
        assert resp.status == 404
        body = await resp.json()
        assert body["code"] == "WorldNotFound"

        resp = await client.get("/api/v0/game/-123")
        assert resp.status == 404
        body = await resp.json()
        assert body["code"] == "GameNotFound"

        resp = await client.get("/api/v0/test-login")
        assert resp.status == 200
        body = await resp.json()
        token = body["token"]

        headers = {"Authentication": token}

        resp = await client.post("/api/v0/game/-123/join", headers=headers)
        assert resp.status == 404
        body = await resp.json()
        assert body["code"] == "GameNotFound"

        resp = await client.post("/api/v0/game/code/INVALID_CODE/join", headers=headers)
        assert resp.status == 404
        body = await resp.json()
        assert body["code"] == "GameNotFound"

        resp = await client.post("/api/v0/game/-123/leave", headers=headers)
        assert resp.status == 404
        body = await resp.json()
        assert body["code"] == "GameNotFound"

        resp = await client.post("/api/v0/game/-123/ready", headers=headers)
        assert resp.status == 404
        body = await resp.json()
        assert body["code"] == "GameNotFound"


@pytest.mark.asyncio
async def test_ready_does_not_return_200_when_player_not_found(service):
    async with aiohttp.ClientSession(base_url=service.url) as client:
        resp = await client.get("/api/v0/test-login")
        assert resp.status == 200
        body = await resp.json()
        host_user_id = body["user"]["id"]

        resp = await client.get("/api/v0/test-login")
        assert resp.status == 200
        body = await resp.json()
        other_token = body["token"]
        other_user_id = body["user"]["id"]

        assert other_user_id != host_user_id

    async with deps.state.pg_pool.acquire() as conn:
        world = await service.universe.create_world(conn, "world", host_user_id, True)
        assert not isinstance(world, ServiceError)
        game = await service.universe.create_game(
            conn, host_user_id, world.id, "room", True, 1
        )
        assert not isinstance(game, ServiceError)

    async with aiohttp.ClientSession(base_url=service.url) as client:
        headers = {"Authentication": other_token}
        resp = await client.post(f"/api/v0/game/{game.id}/ready", headers=headers)
        assert resp.status == 404
        body = await resp.json()
        assert body["code"] == "PlayerNotFound"
