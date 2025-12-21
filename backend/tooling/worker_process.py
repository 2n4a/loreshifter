# tooling/worker_process.py
from __future__ import annotations

import math
import traceback
from typing import Any

from lupa import LuaRuntime
import resource

_SANDBOX_LUA = r"""
local dangerous = {"os", "io", "package", "debug"}
for _, k in ipairs(dangerous) do
  _G[k] = nil
end

_G.require = nil
_G.dofile = nil
_G.loadfile = nil
_G.load = nil

_G.python = nil
"""


def _apply_rlimits(timeout_ms: int, memory_limit_mb: int) -> None:
    if memory_limit_mb and memory_limit_mb > 0:
        mem_bytes = int(memory_limit_mb * 1024 * 1024)
        resource.setrlimit(resource.RLIMIT_AS, (mem_bytes, mem_bytes))

    if timeout_ms and timeout_ms > 0:
        cpu_seconds = max(1, int(math.ceil(timeout_ms / 1000.0)))
        resource.setrlimit(resource.RLIMIT_CPU, (cpu_seconds, cpu_seconds))


def worker_entry(
    conn,
    *,
    lua_sources: list[str],
    manifest: dict,  # NEW
    timeout_ms: int,
    memory_limit_mb: int,
) -> None:
    """
      Request:
        {"op": "validate"}
        OR
        {"op": "run", "tool_name": str, "world_state": dict, "llm_params": dict}

      Response (ok):
        validate -> {"ok": True, "tool_names": [..]}
        run      -> {"ok": True, "world_state": <dict>, "output": <dict>}

      Response (fail):
        {"ok": False, "error_type": str, "error": str, "traceback": str}
    """
    try:
        _apply_rlimits(timeout_ms=timeout_ms, memory_limit_mb=memory_limit_mb)

        lua = LuaRuntime(
            unpack_returned_tuples=True,
            register_eval=False,
            register_builtins=False,
        )

        lua.execute(_SANDBOX_LUA)

        for src in lua_sources or []:
            lua.execute(src)


        tools = (manifest or {}).get("tools")
        if not isinstance(tools, dict):
            raise ValueError("manifest['tools'] must be a dict/object")

        g = lua.globals()
        tool_map: dict[str, str] = {}
        for tool_name, spec in tools.items():
            if not isinstance(tool_name, str) or not tool_name:
                raise ValueError("tool names must be non-empty strings")
            if not isinstance(spec, dict):
                raise ValueError(f"tool spec for {tool_name!r} must be a dict/object")

            fn_name = spec.get("lua_function")
            if not isinstance(fn_name, str) or not fn_name:
                raise ValueError(f"tool {tool_name!r} missing valid 'lua_function'")

            fn = g[fn_name]
            if not callable(fn):
                raise ValueError(f"Lua function {fn_name!r} for tool {tool_name!r} not found or not callable")

            tool_map[tool_name] = fn_name


        req = conn.recv()
        op = req.get("op")


        if op == "validate":
            conn.send({"ok": True, "tool_names": sorted(tool_map.keys())})
            return

        if op != "run":
            raise ValueError(f"Unknown op: {op!r}")

        tool_name = req["tool_name"]
        world_state = req["world_state"]
        llm_params = req["llm_params"]

        fn_name = tool_map.get(tool_name)
        if not fn_name:
            conn.send({"ok": False, "error_type": "ToolNotFound", "error": f"Unknown tool: {tool_name}"})
            return

        fn = lua.globals()[fn_name]
        if not callable(fn):
            raise ValueError(f"Lua function {fn_name!r} not found or not callable")


        # Конвертеры
        from tooling.converters import py_to_lua, lua_to_py

        lua_ws = py_to_lua(lua, world_state)
        lua_params = py_to_lua(lua, llm_params)

        result = fn(lua_ws, lua_params)
        if not isinstance(result, tuple) or len(result) != 2:
            raise ValueError("Tool must return exactly (world_state, output)")

        new_ws_lua, out_lua = result
        new_ws = lua_to_py(new_ws_lua)
        out = lua_to_py(out_lua)

        conn.send({"ok": True, "world_state": new_ws, "output": out})
    except Exception as e:
        conn.send(
            {
                "ok": False,
                "error_type": e.__class__.__name__,
                "error": str(e),
                "traceback": traceback.format_exc(),
            }
        )
    finally:
        try:
            conn.close()
        except Exception:
            pass
