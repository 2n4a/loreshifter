import datetime

import asyncpg

from lstypes.user import FullUserOut


async def get_or_create_user(
        conn: asyncpg.Connection,
        name: str,
        email: str,
        auth_id: int,
    ) -> FullUserOut:
    user = await conn.fetchrow(
        """
        SELECT id, name, email, created_at, deleted
        FROM users
        WHERE auth_id = $1
        """,
        auth_id,
    )
    if user is None:
        user = await conn.fetchrow(
            """
            INSERT INTO users (name, email, auth_id, created_at, deleted)
            VALUES ($1, $2, $3, $4, $5)
            RETURNING id, name, email, created_at, deleted
            """,
            name,
            email,
            auth_id,
            datetime.datetime.now(),
            False,
        )
    if user["name"] != name or user["email"] != email:
        await conn.execute(
            """
            UPDATE users
            SET name = $1, email = $2
            WHERE id = $3
            """,
            name,
            email,
            user["id"],
        )
    return FullUserOut(
        id=user["id"],
        name=user["name"],
        email=user["email"],
        created_at=user["created_at"],
        deleted=user["deleted"],
    )


TEST_USER_COUNTER = 0


async def create_test_user(
        conn: asyncpg.Connection,
        name: str | None = None,
        email: str | None = None,
) -> FullUserOut:
    global TEST_USER_COUNTER
    if name is None or email is None:
        TEST_USER_COUNTER += 1
        if name is None:
            name = f"test_{TEST_USER_COUNTER}"
        if email is None:
            email = f"test{TEST_USER_COUNTER}@example.com"

    user = await conn.fetchrow(
        """
        INSERT INTO users (name, email, auth_id, created_at, deleted)
        VALUES ($1, $2, $3, $4, $5)
        RETURNING id, name, email, created_at, deleted
        """,
        name,
        email,
        None,
        datetime.datetime.now(),
        False,
    )

    return FullUserOut(
        id=user["id"],
        name=user["name"],
        email=user["email"],
        created_at=user["created_at"],
        deleted=user["deleted"],
    )


async def get_user(conn: asyncpg.Connection, id_: int) -> FullUserOut | None:
    user = await conn.fetchrow(
        """
        SELECT id, name, email, created_at, deleted
        FROM users
        WHERE id = $1
        """,
        id_,
    )
    if user is None:
        return None
    return FullUserOut(
        id=user["id"],
        name=user["name"],
        email=user["email"],
        created_at=user["created_at"],
        deleted=user["deleted"],
    )


async def get_user_by_auth_id(conn: asyncpg.Connection, auth_id: int) -> FullUserOut | None:
    user = await conn.fetchrow(
        """
        SELECT id, name, email, created_at, deleted
        FROM users
        WHERE auth_id = $1
        """,
        auth_id,
    )
    if user is None:
        return None
    return FullUserOut(
        id=user["id"],
        name=user["name"],
        email=user["email"],
        created_at=user["created_at"],
        deleted=user["deleted"],
    )


async def delete_user(conn: asyncpg.Connection, id_: int) -> bool:
    return await conn.fetchval(
        """
        UPDATE users
        SET deleted = true
        WHERE id = $1 AND deleted = false
        RETURNING id
        """,
        id_,
    )
