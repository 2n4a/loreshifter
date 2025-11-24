import asyncio

from app.logger import log
from game.universe import Universe


class WebSocketController:
    def __init__(self):
        ...

    async def listen(self, universe: Universe):
        try:
            async for event in universe.listen():
                log.info("Received %s", event)
        except Exception as e:
            log.error("Listen task failed: %s", e)
            raise
