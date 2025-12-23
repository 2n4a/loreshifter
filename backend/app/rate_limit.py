from __future__ import annotations

import asyncio
import time
from dataclasses import dataclass


@dataclass(frozen=True)
class BucketSpec:
    capacity: float
    refill_rate_per_sec: float


@dataclass
class TokenBucket:
    capacity: float
    refill_rate_per_sec: float
    tokens: float
    updated_at: float
    last_used_at: float

    def refill(self, now: float) -> None:
        elapsed = now - self.updated_at
        if elapsed <= 0:
            return
        self.tokens = min(self.capacity, self.tokens + elapsed * self.refill_rate_per_sec)
        self.updated_at = now

    def touch(self, now: float) -> None:
        self.last_used_at = now


class TokenBucketLimiter:
    def __init__(
        self,
        *,
        per_route: BucketSpec,
        per_user: BucketSpec,
        per_route_user: BucketSpec,
        max_entries: int = 50_000,
        gc_interval_sec: float = 60.0,
        bucket_ttl_sec: float = 300.0,
    ):
        self.per_route = per_route
        self.per_user = per_user
        self.per_route_user = per_route_user
        self.max_entries = max_entries
        self.gc_interval_sec = gc_interval_sec
        self.bucket_ttl_sec = bucket_ttl_sec

        self._lock = asyncio.Lock()
        self._route: dict[str, TokenBucket] = {}
        self._user: dict[str, TokenBucket] = {}
        self._route_user: dict[tuple[str, str], TokenBucket] = {}
        self._gc_task: asyncio.Task | None = None
        self._last_gc_at: float = 0.0

    def _mk_bucket(self, spec: BucketSpec, now: float) -> TokenBucket:
        return TokenBucket(
            capacity=spec.capacity,
            refill_rate_per_sec=spec.refill_rate_per_sec,
            tokens=spec.capacity,
            updated_at=now,
            last_used_at=now,
        )

    def _total_entries(self) -> int:
        return len(self._route) + len(self._user) + len(self._route_user)

    def _collect_garbage_locked(self, *, now: float) -> None:
        ttl = self.bucket_ttl_sec
        eps = 1e-9

        def should_drop(b: TokenBucket) -> bool:
            return (b.tokens >= b.capacity - eps) and (now - b.last_used_at > ttl)

        for store in (self._route, self._user, self._route_user):
            dead_keys = [k for k, b in store.items() if should_drop(b)]
            for k in dead_keys:
                del store[k]

        self._last_gc_at = now

    async def check_and_consume(self, *, route_key: str, user_key: str | None) -> bool:
        now = time.monotonic()

        async with self._lock:
            if self._last_gc_at == 0.0 or (now - self._last_gc_at) >= self.gc_interval_sec:
                self._collect_garbage_locked(now=now)

            if self._total_entries() > self.max_entries:
                self._collect_garbage_locked(now=now)
                if self._total_entries() > self.max_entries:
                    self._route.clear()
                    self._user.clear()
                    self._route_user.clear()
                    self._last_gc_at = now

            rb = self._route.get(route_key)
            if rb is None:
                rb = self._mk_bucket(self.per_route, now)
                self._route[route_key] = rb
            rb.refill(now)
            rb.touch(now)

            if user_key is None:
                if rb.tokens < 1.0:
                    return False
                rb.tokens -= 1.0
                return True

            ub = self._user.get(user_key)
            if ub is None:
                ub = self._mk_bucket(self.per_user, now)
                self._user[user_key] = ub
            ub.refill(now)
            ub.touch(now)

            rk = (route_key, user_key)
            rub = self._route_user.get(rk)
            if rub is None:
                rub = self._mk_bucket(self.per_route_user, now)
                self._route_user[rk] = rub
            rub.refill(now)
            rub.touch(now)
            if rb.tokens < 1.0 or ub.tokens < 1.0 or rub.tokens < 1.0:
                return False

            rb.tokens -= 1.0
            ub.tokens -= 1.0
            rub.tokens -= 1.0
            return True

    def start_gc(self) -> None:
        if self._gc_task is None or self._gc_task.done():
            self._gc_task = asyncio.create_task(self._gc_loop(), name="token_bucket_gc")

    async def stop_gc(self) -> None:
        task = self._gc_task
        if task is None:
            return
        task.cancel()
        try:
            await task
        except asyncio.CancelledError:
            pass
        finally:
            self._gc_task = None

    async def _gc_loop(self) -> None:
        try:
            while True:
                await asyncio.sleep(self.gc_interval_sec)
                await self._collect_garbage()
        except asyncio.CancelledError:
            return

    async def _collect_garbage(self) -> None:
        now = time.monotonic()
        async with self._lock:
            self._collect_garbage_locked(now=now)
