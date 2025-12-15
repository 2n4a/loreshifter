import asyncio
import time
import asyncpg

import dataclasses

from app.logger import log
from game.universe import Universe, UniverseNewWorldEvent, UniverseWorldUpdateEvent, UniverseGameEvent
from game.game import GameSystem, GameEvent, GameStatusEvent, PlayerLeftEvent, PlayerJoinedEvent, PlayerKickedEvent
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from lstypes.game import GameStatus

HEARTBEAT_TIMEOUT = 30
DISCONNECT_TIMEOUT = 30


class WebSocketController:
    def __init__(self, pg_pool: asyncpg.Pool):
        self.pg_pool = pg_pool
        self.user_to_ws: dict[int, dict[int, WebSocket]] = {}
        self.pending_disconnect: dict[tuple[int, int], asyncio.Task] = {}
        self.disconnect_timeout = DISCONNECT_TIMEOUT
        self.heartbeat_timeout = HEARTBEAT_TIMEOUT

    async def delayed_disconnect(self, game_id: int, user_id: int):
        try:
            await asyncio.sleep(self.disconnect_timeout)

            game_map = self.user_to_ws.get(game_id) or {}
            websocket = game_map.get(user_id)

            if websocket is None:
                game = GameSystem.of(game_id)
                async with self.pg_pool.acquire() as conn:
                    await game.disconnect_player(
                        conn=conn,
                        player_id=user_id,
                        kick_immediately=True,
                    )

        except asyncio.CancelledError:
            return
        finally:
            key = (game_id, user_id)
            self.pending_disconnect.pop(key, None)

    async def ws_loop(self, game_id, user_id):
        last_seen = time.monotonic()
        websocket = self.user_to_ws[game_id][user_id]
        while True:
            if time.monotonic() - last_seen > HEARTBEAT_TIMEOUT:
                await self.disconnect(game_id=game_id, user_id=user_id, code=1001)
                return
            try:
                msg = await asyncio.wait_for(websocket.receive_json(), timeout=5)
            except asyncio.TimeoutError:
                continue
            except WebSocketDisconnect:
                return

            if msg.get("type") == "ping":
                last_seen = time.monotonic()
                await websocket.send_json({"type": "pong"})

    async def connect(self, websocket: WebSocket, user_id: int, game_id: int):
        key = (game_id, user_id)

        task = self.pending_disconnect.pop(key, None)
        if task:
            task.cancel()
            try:
                await task
            except asyncio.CancelledError:
                pass

        await websocket.accept()
        self.user_to_ws.setdefault(game_id, {})[user_id] = websocket

        try:
            await self.ws_loop(game_id, user_id)
        finally:
            if self.user_to_ws.get(game_id).get(user_id) is websocket:
                self.user_to_ws[game_id].pop(user_id, None)
                await self.on_disconnect(game_id, user_id)

    async def on_disconnect(self, game_id: int, user_id: int):
        key = (game_id, user_id)

        if key in self.pending_disconnect:
            return

        task = asyncio.create_task(self.delayed_disconnect(game_id, user_id))
        self.pending_disconnect[key] = task

    async def disconnect(self, game_id: int, user_id: int, code: int = 1000):
        game_map = self.user_to_ws.get(game_id) or {}
        websocket = game_map.get(user_id)
        if websocket is not None:
            try:
                await websocket.close(code=code)
                del websocket
            except Exception:
                pass

    async def send_json_all(self, message: dict, game_id):
        for connection in (self.user_to_ws.get(game_id) or {}).values():
            await connection.send_json(message)

    async def send_json_users(self, message: dict, game_id: int, user_ids: list[int]):
        game_map = self.user_to_ws.get(game_id)
        if not game_map:
            return

        for user_id in user_ids:
            ws = game_map.get(user_id)
            if ws is None:
                continue
            try:
                await ws.send_json(message)
            except Exception:
                pass

    def remove_game(self, game_id: int):
        if self.user_to_ws.get(game_id) is not None:
            self.user_to_ws.pop(game_id, None)

    async def listen(self, universe: Universe):
        try:
            async for event in universe.listen():
                log.info("Received %s", event)

                match event:
                    case UniverseNewWorldEvent(world=world):
                        ...

                    case UniverseWorldUpdateEvent(world=world):
                        ...

                    case UniverseGameEvent(event=ev):
                        match ev:
                            case PlayerJoinedEvent(game_id=gid, player=player_out):
                                await self.send_json_all({
                                    "type": type(ev).__name__,
                                    "payload": dataclasses.asdict(ev),
                                },
                                    gid
                                )

                            case PlayerLeftEvent(game_id=gid, player=player_out):
                                await self.disconnect(game_id=gid, user_id=player_out.user.id)
                                await self.send_json_all({
                                    "type": type(ev).__name__,
                                    "payload": dataclasses.asdict(ev),
                                },
                                    gid
                                )

                            case PlayerKickedEvent(game_id=gid, player=player_out):
                                await self.disconnect(game_id=gid, user_id=player_out.user.id)
                                await self.send_json_all({
                                    "type": type(ev).__name__,
                                    "payload": dataclasses.asdict(ev),
                                },
                                    gid
                                )

                            case GameStatusEvent(game_id=gid, new_status=new_s):
                                if new_s == GameStatus.ARCHIVED:
                                    self.remove_game(gid)

                                await self.send_json_all({
                                    "type": type(ev).__name__,
                                    "payload": {
                                        "game_id": gid,
                                        "new_status": new_s.value,
                                    },
                                }, gid)

                            case _:
                                gid = ev.game_id
                                await self.send_json_all({
                                    "type": type(ev).__name__,
                                    "payload": dataclasses.asdict(ev),
                                },
                                    gid
                                )

                    case _:
                        log.warning("Unhandled UniverseEvent: %s (%s)", event, type(event))
        except Exception as e:
            log.error("Listen task failed: %s", e)
            raise
