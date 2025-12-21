import asyncio
import contextlib


class Timer:
    def __init__(self, seconds: float):
        self.event = asyncio.Event()
        self.seconds = seconds
        self.going = False

    async def wait(self):
        self.going = True
        with contextlib.suppress(asyncio.TimeoutError):
            await asyncio.wait_for(self.event.wait(), timeout=self.seconds)
        self.going = False
        self.event.clear()

    def trigger_early(self):
        if self.going:
            self.event.set()


class AsyncReentrantLock:
    """A reentrant lock that can be acquired multiple times by the same task.

    This lock can be acquired multiple times by the same task without blocking.
    The lock will only be released when the outermost release() is called.
    """

    def __init__(self):
        self._lock = asyncio.Lock()
        self._task = None
        self._depth = 0

    async def __aenter__(self):
        await self.acquire()
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        self.release()

    async def acquire(self):
        """Acquire the lock.

        If the lock is already held by the current task, increment the depth counter.
        If the lock is held by a different task, block until it is released.
        """
        current_task = asyncio.current_task()
        if self._task == current_task:
            self._depth += 1
            return

        await self._lock.acquire()
        self._task = current_task
        self._depth = 1

    def release(self):
        """Release the lock.

        Decrements the depth counter. If the counter reaches zero, releases the lock.

        Raises:
            RuntimeError: If the lock is not acquired or is released too many times.
        """
        if self._task is None or self._task != asyncio.current_task():
            raise RuntimeError("Cannot release a lock that's not acquired by this task")

        self._depth -= 1
        if self._depth == 0:
            self._task = None
            self._lock.release()

    def locked(self) -> bool:
        """Return True if the lock is currently acquired by any task."""
        return self._lock.locked()


@contextlib.asynccontextmanager
async def get_conn():
    import app.dependencies

    if app.dependencies.state is not None:
        async with app.dependencies.state.pg_pool.acquire() as conn:
            yield conn
    else:
        import tests.conftest
        yield tests.conftest.active_conn
