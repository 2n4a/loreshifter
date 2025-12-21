from __future__ import annotations

import asyncio
import multiprocessing as mp
import time
from dataclasses import dataclass
from typing import Any
from tooling.worker_process import worker_entry


class ToolError(Exception):
    pass


class ToolNotFound(ToolError):
    pass


class ToolValidationError(ToolError):
    pass


class ToolTimeoutError(ToolError):
    pass


class ToolRuntimeError(ToolError):
    pass


def _terminate(p: mp.Process) -> None:
    if p is None:
        return
    if p.is_alive():
        try:
            p.terminate()
        except Exception:
            pass
    try:
        p.join(timeout=0.2)
    except Exception:
        pass
    if p.is_alive():
        try:
            p.kill()
        except Exception:
            pass
        try:
            p.join(timeout=0.2)
        except Exception:
            pass


@dataclass(frozen=True)
class ProcessLuaToolRunner:
    lua_sources: list[str]
    manifest: dict
    timeout_ms: int = 100
    memory_limit_mb: int = 64
    start_method: str = "spawn"

    def __post_init__(self) -> None:
        tools = (self.manifest or {}).get("tools")
        if not isinstance(tools, dict):
            raise ToolValidationError("manifest['tools'] must be a dict/object")
        self._validate_in_worker()

    def _validate_in_worker(self) -> None:
        resp = self._call_worker({"op": "validate"})
        if resp.get("ok") is not True:
            raise ToolValidationError(
                f"{resp.get('error_type')}: {resp.get('error')}\n{resp.get('traceback','')}"
            )

    def run_tool(
        self, tool_name: str, world_state: dict, llm_params: dict
    ) -> tuple[dict, dict]:
        resp = self._call_worker(
            {
                "op": "run",
                "tool_name": tool_name,
                "world_state": world_state,
                "llm_params": llm_params,
            }
        )

        if resp.get("ok") is True:
            ws = resp["world_state"]
            out = resp["output"]
            if not isinstance(ws, dict):
                raise ToolRuntimeError("Returned world_state must be a dict-like table")
            if not isinstance(out, dict):
                raise ToolRuntimeError("Returned output must be a dict-like table")
            return ws, out

        et = resp.get("error_type", "Error")
        msg = resp.get("error", "Unknown error")
        tb = resp.get("traceback", "")

        if et == "ToolNotFound":
            raise ToolNotFound(msg)

        raise ToolRuntimeError(f"{et}: {msg}\n{tb}")

    async def run_tool_async(
        self, tool_name: str, world_state: dict, llm_params: dict
    ) -> tuple[dict, dict]:
        return await asyncio.to_thread(
            self.run_tool, tool_name, world_state, llm_params
        )

    def _call_worker(self, request: dict) -> dict:
        ctx = mp.get_context(self.start_method)
        parent_conn, child_conn = ctx.Pipe(duplex=True)

        p = ctx.Process(
            target=worker_entry,
            args=(child_conn,),
            kwargs={
                "lua_sources": self.lua_sources,
                "manifest": self.manifest,
                "timeout_ms": int(self.timeout_ms),
                "memory_limit_mb": int(self.memory_limit_mb),
            },
            daemon=True,
        )
        p.start()

        try:
            parent_conn.send(request)

            timeout_s = max(0.001, self.timeout_ms / 1000.0)
            deadline = time.monotonic() + timeout_s

            while True:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise ToolTimeoutError(f"Timed out after {self.timeout_ms} ms")

                if parent_conn.poll(min(0.05, remaining)):
                    return parent_conn.recv()

                if not p.is_alive():
                    raise ToolRuntimeError("Worker process exited unexpectedly")

        finally:
            try:
                parent_conn.close()
            except Exception:
                pass
            _terminate(p)
