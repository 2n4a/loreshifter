import asyncio
import pytest
import aiohttp

import app.dependencies as deps
from game.game import GameSystem
from lstypes.message import MessageKind

pytest_plugins = ("tests.service",)


async def _wait_ws_event(
    ws: aiohttp.ClientWebSocketResponse, expected_type: str, timeout: float = 3.0
):
    end = asyncio.get_running_loop().time() + timeout
    got_types = []

    while True:
        remaining = end - asyncio.get_running_loop().time()
        if remaining <= 0:
            raise AssertionError(
                f"Timeout waiting for {expected_type}; got={got_types}"
            )

        msg = await ws.receive(timeout=remaining)

        if msg.type == aiohttp.WSMsgType.TEXT:
            data = msg.json()
            got_types.append(data.get("type"))
            if data.get("type") == expected_type:
                return data

        elif msg.type in (aiohttp.WSMsgType.CLOSE, aiohttp.WSMsgType.CLOSED):
            raise AssertionError(
                f"WebSocket closed while waiting for {expected_type}: {msg}"
            )

        elif msg.type == aiohttp.WSMsgType.ERROR:
            raise AssertionError(f"WebSocket error: {ws.exception()}")


async def _complete_character_creation(
    client: aiohttp.ClientSession, game_id: int, headers: dict
):
    resp = await client.get(f"/api/v0/game/{game_id}/state", headers=headers)
    assert resp.status == 200
    state = await resp.json()
    character_chat = state["character_creation_chat"]
    assert character_chat is not None
    chat_id = character_chat["chat_id"]

    answers = [
        "Torin",
        "Mercenary",
        "Strength 7",
        "Dexterity 6",
        "Intelligence 5",
        "Former knight sworn to a broken oath.",
    ]
    for answer in answers:
        resp = await client.post(
            f"/api/v0/game/{game_id}/chat/{chat_id}/send",
            headers=headers,
            json={"text": answer},
        )
        assert resp.status == 200

    await asyncio.sleep(0)


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
        game = await service.universe.create_game(
            conn, user_id, world.id, "room", True, 2
        )

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
                await _complete_character_creation(client, game.id, headers)
                resp = await client.post(
                    f"/api/v0/game/{game.id}/ready",
                    headers=headers,
                    json={"ready": True},
                )
                assert resp.status == 200

            ev = await _wait_ws_event(ws, "PlayerReadyEvent", timeout=3.0)

            payload = ev["payload"]
            assert payload["game_id"] == game.id
            assert payload["player_id"] == user_id
            assert payload["ready"] is True


@pytest.mark.asyncio
@pytest.mark.timeout(10)
async def test_ws_serializes_player_joined_event(service):
    async with aiohttp.ClientSession(base_url=service.url) as client:
        resp = await client.get("/api/v0/test-login")
        assert resp.status == 200
        host_body = await resp.json()

        resp = await client.get("/api/v0/test-login")
        assert resp.status == 200
        user2_body = await resp.json()

    host = host_body["user"]
    token = host_body["token"]
    host_id = host["id"]
    user2_id = user2_body["user"]["id"]

    async with deps.state.pg_pool.acquire() as conn:
        world = await service.universe.create_world(conn, "world", host_id, True)
        game = await service.universe.create_game(
            conn, host_id, world.id, "room", True, 2
        )

    ws_url = service.url.replace("http://", "ws://").replace("https://", "wss://")
    ws_endpoint = f"{ws_url}/api/v0/game/{game.id}/ws"
    headers = {"Authentication": token}

    async with aiohttp.ClientSession() as session:
        async with session.ws_connect(ws_endpoint, headers=headers) as ws:
            await ws.send_json({"type": "ping"})
            await _wait_ws_event(ws, "pong", timeout=2.0)

            async with deps.state.pg_pool.acquire() as conn:
                game_system = GameSystem.of(game.id)
                assert game_system is not None
                result = await game_system.connect_player(conn, user2_id)
                assert result is None

            ev = await _wait_ws_event(ws, "PlayerJoinedEvent", timeout=3.0)
            payload = ev["payload"]

            assert payload["game_id"] == game.id
            player = payload["player"]
            assert player["user"]["id"] == user2_id
            assert isinstance(player["user"]["created_at"], str)
            assert isinstance(player["joined_at"], str)


@pytest.mark.asyncio
@pytest.mark.timeout(10)
async def test_ws_serializes_chat_message_event(service):
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
            conn, user_id, world.id, "room", True, 2
        )

    ws_url = service.url.replace("http://", "ws://").replace("https://", "wss://")
    ws_endpoint = f"{ws_url}/api/v0/game/{game.id}/ws"
    headers = {"Authentication": token}

    async with aiohttp.ClientSession() as session:
        async with session.ws_connect(ws_endpoint, headers=headers) as ws:
            await ws.send_json({"type": "ping"})
            await _wait_ws_event(ws, "pong", timeout=2.0)

            async with deps.state.pg_pool.acquire() as conn:
                game_system = GameSystem.of(game.id)
                assert game_system is not None
                result = await game_system.game_chat.send_message(
                    conn,
                    message_kind=MessageKind.PLAYER,
                    text="hello",
                    sender_id=user_id,
                )
                assert result is not None

            ev = await _wait_ws_event(ws, "GameChatEvent", timeout=3.0)
            payload = ev["payload"]

            assert payload["game_id"] == game.id
            assert (
                payload["event"]["message"]["msg"]["kind"] == MessageKind.PLAYER.value
            )
            assert isinstance(payload["event"]["message"]["msg"]["sent_at"], str)
