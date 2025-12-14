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

    user = body["user"]
    token = body["token"]
    user_id = user["id"]

    async with deps.state.pg_pool.acquire() as conn:
        world = await service.universe.create_world(conn, "world", user_id, True)
        game = await service.universe.create_game(
            conn, user_id, world.id, "room", True, 1
        )

    async with aiohttp.ClientSession(base_url=service.url) as client:
        headers = {"Authentication": token}
        resp = await client.post(f"/api/v0/game/{game.id}/ready", headers=headers)
        assert resp.status == 200
        resp = await client.post(
            f"/api/v0/game/{game.id}/ready", headers=headers, json={"ready": False}
        )
        assert resp.status == 200


@pytest.mark.asyncio
async def test_game_start_and_restart_errors(service):
    async with aiohttp.ClientSession(base_url=service.url) as client:
        resp = await client.get("/api/v0/test-login")
        assert resp.status == 200
        host = await resp.json()
        host_token = host["token"]
        host_id = host["user"]["id"]

        resp = await client.get("/api/v0/test-login")
        assert resp.status == 200
        other = await resp.json()
        other_token = other["token"]
        other_id = other["user"]["id"]

    async with deps.state.pg_pool.acquire() as conn:
        world = await service.universe.create_world(conn, "world", host_id, True)
        game = await service.universe.create_game(
            conn, host_id, world.id, "room", True, 2
        )

    async with aiohttp.ClientSession(base_url=service.url) as client:
        host_headers = {"Authentication": host_token}
        other_headers = {"Authentication": other_token}

        resp = await client.post(f"/api/v0/game/{game.id}/join", headers=other_headers)
        assert resp.status == 200

        resp = await client.post(f"/api/v0/game/{game.id}/start", headers=other_headers)
        assert resp.status == 401
        body = await resp.json()
        assert body["code"] == "NotHost"

        resp = await client.post(f"/api/v0/game/{game.id}/start", headers=host_headers)
        assert resp.status == 400
        body = await resp.json()
        assert body["code"] == "PlayerNotReady"
        assert sorted(body["details"]["playerIds"]) == sorted([host_id, other_id])

        resp = await client.post(f"/api/v0/game/{game.id}/ready", headers=host_headers)
        assert resp.status == 200
        resp = await client.post(f"/api/v0/game/{game.id}/ready", headers=other_headers)
        assert resp.status == 200

        resp = await client.post(f"/api/v0/game/{game.id}/start", headers=host_headers)
        assert resp.status == 200
        started = await resp.json()
        assert started["status"] == "playing"

        resp = await client.post(
            f"/api/v0/game/{game.id}/restart", headers=host_headers
        )
        assert resp.status == 400
        body = await resp.json()
        assert body["code"] == "GameNotFinished"


@pytest.mark.asyncio
async def test_game_put_state_and_chat(service):
    async with aiohttp.ClientSession(base_url=service.url) as client:
        resp = await client.get("/api/v0/test-login")
        assert resp.status == 200
        host = await resp.json()
        host_token = host["token"]
        host_id = host["user"]["id"]

        resp = await client.get("/api/v0/test-login")
        assert resp.status == 200
        other = await resp.json()
        other_token = other["token"]
        other_id = other["user"]["id"]

        resp = await client.get("/api/v0/test-login")
        assert resp.status == 200
        third = await resp.json()
        third_token = third["token"]

    async with deps.state.pg_pool.acquire() as conn:
        world = await service.universe.create_world(conn, "world", host_id, True)
        game = await service.universe.create_game(
            conn, host_id, world.id, "room", True, 2
        )

    async with aiohttp.ClientSession(base_url=service.url) as client:
        host_headers = {"Authentication": host_token}
        other_headers = {"Authentication": other_token}
        third_headers = {"Authentication": third_token}

        resp = await client.post(f"/api/v0/game/{game.id}/join", headers=other_headers)
        assert resp.status == 200

        resp = await client.put(
            f"/api/v0/game/{game.id}",
            headers=host_headers,
            json={"name": "room-updated", "host_id": other_id},
        )
        assert resp.status == 200
        updated_game = await resp.json()
        assert updated_game["name"] == "room-updated"
        assert updated_game["host_id"] == other_id

        resp = await client.get(f"/api/v0/game/{game.id}/state", headers=host_headers)
        assert resp.status == 200
        state = await resp.json()

        game_chat_id = state["game_chat"]["chat_id"]
        character_creation_chat_id = state["character_creation_chat"]["chat_id"]

        resp = await client.get(
            f"/api/v0/game/{game.id}/chat/{game_chat_id}", headers=host_headers
        )
        assert resp.status == 200
        segment = await resp.json()
        assert segment["chat_id"] == game_chat_id
        assert segment["messages"] == []

        resp = await client.post(
            f"/api/v0/game/{game.id}/chat/{game_chat_id}/send",
            headers=host_headers,
            json={"text": "hello"},
        )
        assert resp.status == 200
        msg = await resp.json()
        assert msg["text"] == "hello"

        resp = await client.get(
            f"/api/v0/game/{game.id}/chat/{game_chat_id}", headers=host_headers
        )
        assert resp.status == 200
        segment = await resp.json()
        assert [m["text"] for m in segment["messages"]] == ["hello"]

        resp = await client.post(f"/api/v0/game/{game.id}/join", headers=third_headers)
        assert resp.status == 200

        resp = await client.get(
            f"/api/v0/game/{game.id}/chat/{character_creation_chat_id}",
            headers=third_headers,
        )
        assert resp.status == 401
        body = await resp.json()
        assert body["code"] == "CannotAccessChat"
