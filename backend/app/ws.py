import asyncio
import time
import asyncpg

import dataclasses

from game.logger import gl_log
from game.universe import Universe, UniverseNewWorldEvent, UniverseWorldUpdateEvent, UniverseGameEvent
from game.game import GameSystem, GameEvent, GameStatusEvent, PlayerLeftEvent, PlayerJoinedEvent, PlayerKickedEvent
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from lstypes.game import GameStatus
from fastapi.encoders import jsonable_encoder

from starlette.websockets import WebSocketState

HEARTBEAT_TIMEOUT = 30
DISCONNECT_TIMEOUT = 30


class WebSocketController:
    def __init__(self, pg_pool: asyncpg.Pool, log=gl_log):
        self._lock = asyncio.Lock()
        self.pg_pool = pg_pool
        self.user_to_ws: dict[int, dict[int, WebSocket]] = {}
        self.pending_disconnect: dict[tuple[int, int], asyncio.Task] = {}
        self.disconnect_timeout = DISCONNECT_TIMEOUT
        self.heartbeat_timeout = HEARTBEAT_TIMEOUT
        self.log = log

    async def delayed_disconnect(self, game_id: int, user_id: int):
        try:
            await asyncio.sleep(self.disconnect_timeout)

            async with self._lock:
                game_map = self.user_to_ws.get(game_id) or {}
                websocket = game_map.get(user_id)

            if websocket is None:
                game = GameSystem.of(game_id)
                if game is None:
                    return
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
            async with self._lock:
                _ = self.pending_disconnect.pop(key, None)

    async def ws_loop(self, game_id, user_id, websocket: WebSocket):
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

        async with self._lock:
            task = self.pending_disconnect.pop(key, None)

        if task:
            task.cancel()
            try:
                await task
            except asyncio.CancelledError:
                pass
            except Exception as e:
                await self.log.awarning("Failed to cancel pending disconnect", e)

        async with self._lock:
            self.user_to_ws.setdefault(game_id, {})[user_id] = websocket

        try:
            await self.ws_loop(game_id, user_id, websocket)
        finally:
            need_schedule = False
            async with self._lock:
                game_map = self.user_to_ws.get(game_id)
                if game_map and game_map.get(user_id) is websocket:
                    game_map.pop(user_id, None)
                    if not game_map:
                        self.user_to_ws.pop(game_id, None)
                    need_schedule = True

            if need_schedule:
                await self.on_disconnect(game_id, user_id)

    async def on_disconnect(self, game_id: int, user_id: int):
        key = (game_id, user_id)

        async with self._lock:
            if key in self.pending_disconnect:
                return
            task = asyncio.create_task(self.delayed_disconnect(game_id, user_id))
            self.pending_disconnect[key] = task

    async def disconnect(self, game_id: int, user_id: int, code: int = 1000, purge: bool = False):
        async with self._lock:
            game_map = self.user_to_ws.get(game_id)
            ws = game_map.get(user_id) if game_map else None

            if purge and ws is not None:
                game_map.pop(user_id, None)
                if not game_map:
                    self.user_to_ws.pop(game_id, None)

        if ws is not None:
            try:
                await ws.close(code=code)
            except Exception:
                pass

    async def _safe_send(self, game_id: int, user_id: int, ws: WebSocket, message: dict) -> bool:
        try:
            if getattr(ws, "client_state", None) == WebSocketState.DISCONNECTED:
                raise RuntimeError("WebSocket already disconnected")

            await self.log.ainfo(f"Sending message: {message}", game_id=game_id, user_id=user_id)
            await ws.send_json(message)
            return True

        except Exception as e:
            await self.log.awarning("WebSocketController send failed", game_id=game_id, user_id=user_id, err=str(e))

            removed = False
            async with self._lock:
                game_map = self.user_to_ws.get(game_id)
                if game_map and game_map.get(user_id) is ws:
                    game_map.pop(user_id, None)
                    if not game_map:
                        self.user_to_ws.pop(game_id, None)
                    removed = True

            try:
                await ws.close(code=1011)
            except Exception:
                pass

            if removed:
                await self.on_disconnect(game_id, user_id)

            return False

    async def send_json_all(self, message: dict, game_id):
        async with self._lock:
            game_map = self.user_to_ws.get(game_id) or {}
            conns = list(game_map.items())

        for user_id, ws in conns:
            await self._safe_send(game_id, user_id, ws, message)

    async def send_json_users(self, message: dict, game_id: int, user_ids: list[int]):
        async with self._lock:
            game_map = self.user_to_ws.get(game_id) or {}
            conns = [(uid, game_map.get(uid)) for uid in user_ids]
            conns = [(uid, ws) for uid, ws in conns if ws is not None]

        for user_id, ws in conns:
            await self._safe_send(game_id, user_id, ws, message)

    async def remove_game(self, game_id: int):
        async with self._lock:
            self.user_to_ws.pop(game_id, None)

    async def listen(self, universe: Universe):
        try:
            async for event in universe.listen():
                await self.log.ainfo("Received %s", event)

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
                                    "payload": jsonable_encoder(ev),
                                },
                                    gid
                                )

                            case PlayerLeftEvent(game_id=gid, player=player_out):
                                await self.disconnect(game_id=gid, user_id=player_out.user.id, purge=True)
                                await self.send_json_all({
                                    "type": type(ev).__name__,
                                    "payload": jsonable_encoder(ev),
                                },
                                    gid
                                )

                            case PlayerKickedEvent(game_id=gid, player=player_out):
                                await self.disconnect(game_id=gid, user_id=player_out.user.id, purge=True)
                                await self.send_json_all({
                                    "type": type(ev).__name__,
                                    "payload": jsonable_encoder(ev),
                                },
                                    gid
                                )

                            case GameStatusEvent(game_id=gid, new_status=new_s):
                                if new_s == GameStatus.ARCHIVED:
                                    await self.remove_game(gid)

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
                                    "payload": jsonable_encoder(ev),
                                },
                                    gid
                                )

                    case _:
                        await self.log.awarning("Unhandled UniverseEvent: %s (%s)", event, type(event))
        except Exception as e:
            await self.log.aerror("Listen task failed: %s", e)
            raise
