import asyncio
import pytest
import aiohttp

import app.dependencies as deps

pytest_plugins = ("tests.service",)


async def _wait_ws_event(ws: aiohttp.ClientWebSocketResponse, expected_type: str, timeout: float = 3.0):
    end = asyncio.get_running_loop().time() + timeout
    got_types = []

    while True:
        remaining = end - asyncio.get_running_loop().time()
        if remaining <= 0:
            raise AssertionError(f"Timeout waiting for {expected_type}; got={got_types}")

        msg = await ws.receive(timeout=remaining)

        if msg.type == aiohttp.WSMsgType.TEXT:
            data = msg.json()
            got_types.append(data.get("type"))
            if data.get("type") == expected_type:
                return data

        elif msg.type in (aiohttp.WSMsgType.CLOSE, aiohttp.WSMsgType.CLOSED):
            raise AssertionError(f"WebSocket closed while waiting for {expected_type}: {msg}")

        elif msg.type == aiohttp.WSMsgType.ERROR:
            raise AssertionError(f"WebSocket error: {ws.exception()}")


@pytest.mark.asyncio
@pytest.mark.timeout(10)
async def test_ws_sends_player_ready_event(service):
    # 1) login
    async with aiohttp.ClientSession(base_url=service.url) as client:
        resp = await client.get("/api/v0/test-login")
        assert resp.status == 200
        body = await resp.json()

    user = body["user"]
    token = body["token"]
    user_id = user["id"]

    async with deps.state.pg_pool.acquire() as conn:
        world = await service.universe.create_world(conn, "world", user_id, True)
        game = await service.universe.create_game(conn, user_id, world.id, "room", True, 2)

    # 3) connect websocket as a client
    ws_url = service.url.replace("http://", "ws://").replace("https://", "wss://")
    ws_endpoint = f"{ws_url}/api/v0/game/{game.id}/ws"

    headers = {"Authentication": token}

    async with aiohttp.ClientSession() as session:
        async with session.ws_connect(ws_endpoint, headers=headers) as ws:
            # поддержим heartbeat (сервер ждёт {"type":"ping"} и отвечает {"type":"pong"})
            await ws.send_json({"type": "ping"})
            pong = await _wait_ws_event(ws, "pong", timeout=2.0)

            async with aiohttp.ClientSession(base_url=service.url) as client:
                resp = await client.post(f"/api/v0/game/{game.id}/ready", headers=headers, json={"ready": True})
                assert resp.status == 200

            ev = await _wait_ws_event(ws, "PlayerReadyEvent", timeout=3.0)

            payload = ev["payload"]
            assert payload["game_id"] == game.id
            assert payload["player_id"] == user_id
            assert payload["ready"] is True
