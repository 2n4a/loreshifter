from starlette.websockets import WebSocket

from game.logger import gl_log
from game.universe import Universe


class WebSocketController:
    def __init__(self):
        self.game_listening_websockets: dict[int, dict[int, WebSocket]] = {}

    def add_game_websocket(self, websocket: WebSocket, game_id: int, user_id: int):
        ...

    async def listen(self, universe: Universe, log=gl_log):
        try:
            async for event in universe.listen():
                ...
                await log.ainfo("Received %s", event)
        except Exception as e:
            await log.aerror("Listen task failed: %s", e)
            raise
