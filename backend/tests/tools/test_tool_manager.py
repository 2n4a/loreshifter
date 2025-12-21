import pytest

from tooling.tool_manager import ToolManager


@pytest.mark.asyncio
async def test_tool_manager_run_tool_happy_path():
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
    manifest = {
        "tools": {
            "damage_dragon": {
                "lua_function": "damage_dragon",
                "description": "Reduces dragon HP by a specified amount",
            }
        }
    }

    manager = ToolManager(lua_sources=[lua_code], manifest=manifest, timeout_ms=200, memory_limit_mb=64)

    world_state = {"dragon_hp": 100, "phase": 1}
    llm_params = {"damage": 15}

    new_world_state, output = await manager.run_tool("damage_dragon", world_state, llm_params)

    assert new_world_state == {"dragon_hp": 85, "phase": 1}
    assert output == {"applied_damage": 15, "dragon_hp": 85}
