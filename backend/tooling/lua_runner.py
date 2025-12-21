from __future__ import annotations
from dataclasses import dataclass
from typing import Any
from lupa import LuaRuntime
from tooling.converters import py_to_lua, lua_to_py


class ToolError(Exception):
    """Базовая ошибка раннера."""

    pass


class ToolNotFound(ToolError):
    """Запрошенный tool_name не описан в manifest."""

    pass


class ToolValidationError(ToolError):
    """Manifest кривой или функция не найдена/не callable."""

    pass


class ToolRuntimeError(ToolError):
    """Lua функция упала или вернула не то."""

    pass


@dataclass(frozen=True)
class ToolSpec:
    tool_name: str
    lua_function: str
    description: str | None = None


class LuaToolRunner:
    def __init__(self, *, lua_sources: list[str], manifest: dict) -> None:
        self.lua = LuaRuntime(
            unpack_returned_tuples=True,
            register_eval=False,
            register_builtins=False,
        )

        self.lua_sources = list(lua_sources or [])
        self.manifest = manifest or {}

        for src in self.lua_sources:
            self.lua.execute(src)

        self.tools: dict[str, ToolSpec] = self._parse_manifest(self.manifest)

        self._validate_functions_exist()

    def _parse_manifest(self, manifest: dict) -> dict[str, ToolSpec]:
        """
        Берём манифест формата:
          {"tools": { "tool_name": { "lua_function": "...", "description": "..." }, ... }}
        И превращаем в dict tool_name -> ToolSpec.
        """
        tools = manifest.get("tools")
        if not isinstance(tools, dict):
            raise ToolValidationError("manifest['tools'] must be a dict")

        out: dict[str, ToolSpec] = {}
        for tool_name, spec in tools.items():
            if not isinstance(tool_name, str) or not tool_name:
                raise ToolValidationError("tool names must be non-empty strings")
            if not isinstance(spec, dict):
                raise ToolValidationError(f"tool spec for {tool_name!r} must be a dict")

            fn_name = spec.get("lua_function")
            if not isinstance(fn_name, str) or not fn_name:
                raise ToolValidationError(
                    f"tool {tool_name!r} missing valid 'lua_function'"
                )

            desc = spec.get("description")
            if desc is not None and not isinstance(desc, str):
                raise ToolValidationError(
                    f"tool {tool_name!r} has invalid 'description' type"
                )

            out[tool_name] = ToolSpec(
                tool_name=tool_name, lua_function=fn_name, description=desc
            )

        return out

    def _validate_functions_exist(self) -> None:
        g = self.lua.globals()
        for tool_name, spec in self.tools.items():
            fn = g[spec.lua_function]
            if not callable(fn):
                raise ToolValidationError(
                    f"Lua function {spec.lua_function!r} for tool {tool_name!r} not found or not callable"
                )

    def run_tool(
        self, tool_name: str, world_state: dict, llm_params: dict
    ) -> tuple[dict, dict]:
        spec = self.tools.get(tool_name)
        if spec is None:
            raise ToolNotFound(f"Unknown tool: {tool_name}")

        fn = self.lua.globals()[spec.lua_function]
        try:
            lua_ws = py_to_lua(self.lua, world_state)
            lua_params = py_to_lua(self.lua, llm_params)

            result = fn(lua_ws, lua_params)

            if not isinstance(result, tuple) or len(result) != 2:
                raise ToolRuntimeError("Tool must return exactly (world_state, output)")

            new_ws_lua, out_lua = result
            new_ws = lua_to_py(new_ws_lua)
            out = lua_to_py(out_lua)

            if not isinstance(new_ws, dict):
                raise ToolRuntimeError("Returned world_state must be a dict-like table")
            if not isinstance(out, dict):
                raise ToolRuntimeError("Returned output must be a dict-like table")

            return new_ws, out
        except ToolError:
            raise
        except Exception as e:
            raise ToolRuntimeError(str(e)) from e
