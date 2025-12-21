from lupa import LuaRuntime
from tooling.converters import py_to_lua, lua_to_py


def test_roundtrip_nested():
    lua = LuaRuntime(
        unpack_returned_tuples=True, register_eval=False, register_builtins=False
    )

    obj = {"a": 1, "b": [True, None, {"x": 3.5}], "c": {"k": "v"}}
    back = lua_to_py(py_to_lua(lua, obj))
    assert back == obj


def test_array_table_becomes_list():
    lua = LuaRuntime(
        unpack_returned_tuples=True, register_eval=False, register_builtins=False
    )
    t = lua.table()
    t[1] = "a"
    t[2] = "b"
    assert lua_to_py(t) == ["a", "b"]


def test_map_table_becomes_dict():
    lua = LuaRuntime(
        unpack_returned_tuples=True, register_eval=False, register_builtins=False
    )
    t = lua.table()
    t["x"] = 1
    t["y"] = 2
    assert lua_to_py(t) == {"x": 1, "y": 2}


def test_roundtrip_nested_with_none_in_list():
    lua = LuaRuntime(
        unpack_returned_tuples=True, register_eval=False, register_builtins=False
    )
    obj = {"a": 1, "b": [True, None, {"x": 3.5}], "c": {"k": "v"}}
    back = lua_to_py(py_to_lua(lua, obj))
    assert back == obj


def test_roundtrip_trailing_none_in_list():
    lua = LuaRuntime(
        unpack_returned_tuples=True, register_eval=False, register_builtins=False
    )
    obj = {"arr": [1, 2, None]}
    back = lua_to_py(py_to_lua(lua, obj))
    assert back == obj


def test_roundtrip_dict_none_vs_missing():
    lua = LuaRuntime(
        unpack_returned_tuples=True, register_eval=False, register_builtins=False
    )
    obj1 = {"target": None}
    obj2 = {}
    assert lua_to_py(py_to_lua(lua, obj1)) == obj1
    assert lua_to_py(py_to_lua(lua, obj2)) == obj2
    assert obj1 != obj2  # sanity: they differ and must stay different
