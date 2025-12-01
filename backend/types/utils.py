import enum

import asyncpg


class PgEnum(enum.EnumMeta):
    _registry: dict[str, PgEnum] = {}

    __pg_enum_name__: str
    __pg_schema__: str

    def __new__(mcls, name, bases, namespace, **kwargs):
        pg_enum_name = namespace.get("__pg_enum_name__", name.lower())
        namespace["__pg_enum_name__"] = pg_enum_name

        schema = namespace.get("__pg_schema__", "public")
        namespace["__pg_schema__"] = schema

        if enum.Enum not in bases:
            bases = (*bases, enum.Enum)
        cls = super().__new__(mcls, name, bases, namespace, **kwargs)
        mcls._registry[pg_enum_name] = cls
        return cls

    @classmethod
    async def register_all(mcls, conn: asyncpg.Connection):
        for enum_name, enum_cls in mcls._registry.items():
            await conn.set_type_codec(
                enum_name,
                schema=enum_cls.__pg_schema__,
                encoder=lambda x: x.value,
                decoder=lambda x: enum_cls(x),
            )
