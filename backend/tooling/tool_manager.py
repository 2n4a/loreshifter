from __future__ import annotations
from typing import Any
from tooling.process_runner import ProcessLuaToolRunner


# тут основная функция run_tool
class ToolManager:
    def __init__(
        self,
        *,
        lua_sources: list[str],
        manifest: dict,
        timeout_ms: int = 100,
        memory_limit_mb: int = 64,
        start_method: str = "spawn",
    ) -> None:
        self._runner = ProcessLuaToolRunner(
            lua_sources=lua_sources,
            manifest=manifest,
            timeout_ms=timeout_ms,
            memory_limit_mb=memory_limit_mb,
            start_method=start_method,
        )

    async def run_tool(
        self,
        tool_name: str,
        world_state: dict[str, Any],
        llm_params: dict[str, Any],
    ) -> tuple[dict[str, Any], dict[str, Any]]:
        return await self._runner.run_tool_async(tool_name, world_state, llm_params)
