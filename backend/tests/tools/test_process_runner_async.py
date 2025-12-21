import pytest

from tooling.process_runner import ProcessLuaToolRunner


@pytest.mark.asyncio
async def test_run_tool_async_happy_path():
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

    ws, out = await runner.run_tool_async(
        "damage_dragon", {"dragon_hp": 100, "phase": 1}, {"damage": 15}
    )
    assert ws == {"dragon_hp": 85, "phase": 1}
    assert out == {"applied_damage": 15, "dragon_hp": 85}
