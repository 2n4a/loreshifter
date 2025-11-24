import typing
import asyncio
import inspect
import pytest


P = typing.ParamSpec("P")


class SystemStopMarker:
    pass

class SystemPipeException(RuntimeError):
    def __init__(self, cause: Exception, system_name: str):
        super().__init__(f"Pipe in system {system_name} failed with an exception")
        self.cause = cause


class SystemException(RuntimeError):
    def __init__(self, message: str):
        super().__init__(message)


class System[E]:
    """
    A system is an object which accepts commands and emits events.

    For example, an inference provider like OpenAI API is a system
    which accepts prompts and emits completions. It can have a
    `prompt` command which accepts the prompt and returns
    generated text, and it can emit events which correspond to
    the tokens in the generated text.

    Events are not meant to be responded to, or be results of commands.
    They are just a way to pass information from one system to another
    in a non-blocking, async manner.

    Events can be piped to other systems using `add_pipe`.
    """

    def __init__(self, name: None | str = None):
        self._event_queue: asyncio.Queue[E | SystemPipeException | SystemStopMarker] = asyncio.Queue()
        self.active_pipes = 0
        self.name = name or self.__class__.__name__
        self.stopped: bool = False
        self.listened: bool = False
        self.finished_event: asyncio.Event = asyncio.Event()
        self.finished_event.set()

    def add_pipe(self, pipe: typing.Callable[P, typing.Coroutine], *args: P.args, **kwargs: P.kwargs):
        if self.stopped:
            raise SystemException(f"Trying to add pipe to a stopped system {self.name}")

        coro = pipe(*args, **kwargs)
        if not inspect.isawaitable(coro):
            raise ValueError("Pipes must be async functions")

        async def wrapper():
            try:
                await coro
            except Exception as e:
                await self._event_queue.put(SystemPipeException(e, self.name))
            finally:
                self.active_pipes -= 1
                if self.active_pipes == 0:
                    self.finished_event.set()

        self.add_raw_pipe(wrapper())

    def add_raw_pipe(self, pipe: typing.Coroutine, name: str | None = None):
        self.active_pipes += 1
        self.finished_event.clear()
        asyncio.create_task(pipe, name=name)

    def emit(self, event: E):
        if self.stopped:
            return
        self._event_queue.put_nowait(event)

    async def stop(self):
        if self.stopped:
            return
        await self.finished_event.wait()
        self.stopped = True
        await self._event_queue.put(SystemStopMarker())

    async def listen(self) -> typing.AsyncGenerator[E]:
        if self.listened:
            raise SystemException(
                f"System {self.name} is already being listened to. "
                "You can only listen to a system once."
            )

        try:
            self.listened = True
            while True:
                event = await self._event_queue.get()
                self._event_queue.task_done()
                if isinstance(event, SystemStopMarker):
                    break
                elif isinstance(event, SystemPipeException):
                    raise event from event.cause
                else:
                    yield event
        finally:
            self.listened = False


@pytest.mark.asyncio
async def test_system_example():
    class SourceSystem(System[int]):
        def __init__(self, start: int, end: int):
            self.start = start
            self.end = end
            super().__init__()

        def run(self):
            for i in range(self.start, self.end):
                self.emit(i)

    class DoubleSystem(System[int]):
        def __init__(self, source: SourceSystem):
            super().__init__()
            self.add_pipe(self.double_pipe, source)

        async def double_pipe(self, system: SourceSystem):
            async for x in system.listen():
                self.emit(x * 2)

    source = SourceSystem(1, 4)
    double = DoubleSystem(source)

    source.run()
    results = []

    await source.stop()
    await double.stop()

    async for x in double.listen():
        results.append(x)

    assert results == [2, 4, 6]


if __name__ == "__main__":
    asyncio.run(test_system_example())
