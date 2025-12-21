from __future__ import annotations

import time
import typing
import asyncio
from dataclasses import dataclass


@dataclass
class TokenBucket:
    capacity: float
    refill_rate_per_sec: float
    tokens: float
    updated_at: float

    def refill(self, now: float) -> None:
        elapsed = now - self.updated_at
        if elapsed <= 0:
            return
        self.tokens = min(self.capacity, self.tokens + elapsed * self.refill_rate_per_sec)
        self.updated_at = now

    def try_consume(self, n: float = 1.0, now: float | None = None) -> bool:
        if now is None:
            now = time.monotonic()
        self.refill(now)
        if self.tokens >= n:
            self.tokens -= n
            return True
        return False


@dataclass(frozen=True)
class BucketSpec:
    capacity: float
    refill_rate_per_sec: float


class TokenBucketLimiter:

    def __init__(
        self,
        *,
        per_route: BucketSpec,
        per_user: BucketSpec,
        per_route_user: BucketSpec,
        max_entries: int = 50_000,
    ):
        self.per_route = per_route
        self.per_user = per_user
        self.per_route_user = per_route_user
        self.max_entries = max_entries

        self._lock = asyncio.Lock()
        self._route: dict[str, TokenBucket] = {}
        self._user: dict[int, TokenBucket] = {}
        self._route_user: dict[tuple[str, int], TokenBucket] = {}

    def _mk_bucket(self, spec: BucketSpec, now: float) -> TokenBucket:
        return TokenBucket(
            capacity=spec.capacity,
            refill_rate_per_sec=spec.refill_rate_per_sec,
            tokens=spec.capacity,
            updated_at=now,
        )

    async def check_and_consume(self, *, route_key: str, user_id: int | None) -> bool:
        now = time.monotonic()

        async with self._lock:
            if (
                len(self._route) + len(self._user) + len(self._route_user)
                > self.max_entries
            ):
                self._route.clear()
                self._user.clear()
                self._route_user.clear()

            rb = self._route.get(route_key)
            if rb is None:
                rb = self._mk_bucket(self.per_route, now)
                self._route[route_key] = rb

            if not rb.try_consume(1.0, now=now):
                return False

            if user_id is None:
                return True

            ub = self._user.get(user_id)
            if ub is None:
                ub = self._mk_bucket(self.per_user, now)
                self._user[user_id] = ub

            if not ub.try_consume(1.0, now=now):
                return False

            key = (route_key, user_id)
            rub = self._route_user.get(key)
            if rub is None:
                rub = self._mk_bucket(self.per_route_user, now)
                self._route_user[key] = rub

            if not rub.try_consume(1.0, now=now):
                return False

            return True
