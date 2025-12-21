from __future__ import annotations
from typing import Any
import lupa



_ARRAY_LEN = "__py_array_len__"
_NONE_SENTINEL = "__py_none__"


def _is_lua_table(x: Any) -> bool:
    try:
        return lupa.lua_type(x) == "table"
    except Exception:
        return False


def _make_none_sentinel(lua):
    t = lua.table()
    t[_NONE_SENTINEL] = True
    return t


def py_to_lua(lua, obj: Any):
    if obj is None or isinstance(obj, (bool, int, float, str)):
        return obj

    if isinstance(obj, (list, tuple)):
        t = lua.table()
        t[_ARRAY_LEN] = len(obj)
        for i, v in enumerate(obj, start=1):
            if v is None:
                continue
            t[i] = py_to_lua(lua, v)
        return t

    if isinstance(obj, dict):
        t = lua.table()
        for k, v in obj.items():
            if v is None:
                t[k] = _make_none_sentinel(lua)
            else:
                t[k] = py_to_lua(lua, v)
        return t

    raise TypeError(f"Unsupported type: {type(obj).__name__}")


def lua_to_py(obj: Any, _stack: set[int] | None = None) -> Any:
    if _stack is None:
        _stack = set()

    if obj is None or isinstance(obj, (bool, int, float, str)):
        return obj

    if not _is_lua_table(obj):
        raise TypeError(f"Unsupported type: {type(obj).__name__}")


    oid = id(obj)
    if oid in _stack:
        raise ValueError("Cycle detected in Lua table")
    _stack.add(oid)
    
    try:
        keys = list(obj.keys())

        # 1) None sentinel
        sentinel_val = obj[_NONE_SENTINEL]
        if sentinel_val is True and len(keys) == 1 and keys[0] == _NONE_SENTINEL:
            return None

        # 2) Array marker
        n = obj[_ARRAY_LEN]
        if isinstance(n, int) and n >= 0:
            return [lua_to_py(obj[i], _stack) for i in range(1, n + 1)]

        # 3) Fallback: pure int keys => list (holes -> None)
        int_keys: list[int] = []
        for k in keys:
            if isinstance(k, int) and k >= 1:
                int_keys.append(k)
            else:
                int_keys = []
                break

        if int_keys:
            max_k = max(int_keys)
            return [lua_to_py(obj[i], _stack) for i in range(1, max_k + 1)]

        # 4) Dict/map
        out: dict[Any, Any] = {}
        for k in keys:
            if k in (_ARRAY_LEN, _NONE_SENTINEL):
                continue
            out[lua_to_py(k, _stack)] = lua_to_py(obj[k], _stack)
        return out

    finally:
        _stack.remove(oid)
