import dataclasses

import asyncio
import pytest
import pytest_asyncio
import uvicorn

import app.dependencies as deps
from game.universe import Universe
from app.main import app


@dataclasses.dataclass
class Service:
    url: str
    universe: Universe
    _server: uvicorn.Server
    _task: asyncio.Task
    _stopped: bool = False

    async def stop(self):
        if self._stopped:
            return
        self._server.should_exit = True
        await self._task
        self._stopped = True


@pytest_asyncio.fixture(scope="session")
async def service(postgres_connection_string) -> Service:
    port = 54321
    deps.PG_DSN = postgres_connection_string
    server = uvicorn.Server(
        config=uvicorn.Config(
            app,
            host='127.0.0.1',
            port=port,
            lifespan='on',
        )
    )
    task = asyncio.create_task(server.serve())
    while not server.started and deps.state is None:
        pass
    service = Service(
        url=f'http://127.0.0.1:{port}',
        universe=deps.state.universe,
        _server=server,
        _task=task,
    )
    try:
        yield service
    finally:
        await service.stop()

