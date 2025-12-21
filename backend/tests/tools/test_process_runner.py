import pytest

from tooling.process_runner import (
    ProcessLuaToolRunner,
    ToolNotFound,
    ToolTimeoutError,
    ToolValidationError,
)


def test_damage_dragon_happy_path():
    lua_code = """
function damage_dragon(world_state, llm_params)
  local damage = llm_params.damage or 0
  local hp = world_state.dragon_hp or 0
  local new_hp = hp - damage
  if new_hp < 0 then new_hp = 0 end

  world_state.dragon_hp = new_hp

  return world_state, { applied_damage = damage, dragon_hp = new_hp }
end
"""
    manifest = {"tools": {"damage_dragon": {"lua_function": "damage_dragon"}}}
    runner = ProcessLuaToolRunner(
        lua_sources=[lua_code], manifest=manifest, timeout_ms=200, memory_limit_mb=64
    )

    ws, out = runner.run_tool(
        "damage_dragon", {"dragon_hp": 100, "phase": 1}, {"damage": 15}
    )
    assert ws == {"dragon_hp": 85, "phase": 1}
    assert out == {"applied_damage": 15, "dragon_hp": 85}


def test_unknown_tool():
    lua_code = "function ok(ws, p) return ws, {} end"
    manifest = {"tools": {"ok": {"lua_function": "ok"}}}
    runner = ProcessLuaToolRunner(
        lua_sources=[lua_code], manifest=manifest, timeout_ms=200, memory_limit_mb=64
    )

    with pytest.raises(ToolNotFound):
        runner.run_tool("nope", {}, {})


def test_manifest_missing_function_fails_fast():
    lua_code = "function ok(ws, p) return ws, {} end"
    manifest = {"tools": {"missing": {"lua_function": "no_such_fn"}}}

    with pytest.raises(ToolValidationError):
        ProcessLuaToolRunner(
            lua_sources=[lua_code],
            manifest=manifest,
            timeout_ms=200,
            memory_limit_mb=64,
        )


def test_timeout():
    lua_code = """
function hang(ws, p)
  while true do end
  return ws, {}
end
"""
    manifest = {"tools": {"hang": {"lua_function": "hang"}}}
    runner = ProcessLuaToolRunner(
        lua_sources=[lua_code], manifest=manifest, timeout_ms=300, memory_limit_mb=64
    )

    with pytest.raises(ToolTimeoutError):
        runner.run_tool("hang", {}, {})
