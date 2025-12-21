import pytest

from tooling.lua_runner import (
    LuaToolRunner,
    ToolNotFound,
    ToolRuntimeError,
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

  local output = {
    applied_damage = damage,
    dragon_hp = new_hp
  }

  return world_state, output
end
"""
    manifest = {
        "tools": {
            "damage_dragon": {
                "lua_function": "damage_dragon",
                "description": "Reduces dragon HP",
            }
        }
    }

    runner = LuaToolRunner(lua_sources=[lua_code], manifest=manifest)

    ws = {"dragon_hp": 100, "phase": 1}
    params = {"damage": 15}

    new_ws, out = runner.run_tool("damage_dragon", ws, params)
    assert new_ws == {"dragon_hp": 85, "phase": 1}
    assert out == {"applied_damage": 15, "dragon_hp": 85}


def test_manifest_missing_function_fails_fast():
    lua_code = "function ok(ws, p) return ws, {} end"
    manifest = {"tools": {"missing": {"lua_function": "no_such_fn"}}}

    with pytest.raises(ToolValidationError):
        LuaToolRunner(lua_sources=[lua_code], manifest=manifest)


def test_unknown_tool():
    lua_code = "function ok(ws, p) return ws, {} end"
    manifest = {"tools": {"ok": {"lua_function": "ok"}}}
    runner = LuaToolRunner(lua_sources=[lua_code], manifest=manifest)

    with pytest.raises(ToolNotFound):
        runner.run_tool("nope", {}, {})


def test_bad_return_shape():
    lua_code = "function bad(ws, p) return ws end"
    manifest = {"tools": {"bad": {"lua_function": "bad"}}}
    runner = LuaToolRunner(lua_sources=[lua_code], manifest=manifest)

    with pytest.raises(ToolRuntimeError):
        runner.run_tool("bad", {}, {})
