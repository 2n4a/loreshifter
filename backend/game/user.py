import datetime
import random

import asyncpg

from game.logger import gl_log
from lstypes.error import ServiceError, error
from lstypes.user import FullUserOut


async def get_or_create_user(
        conn: asyncpg.Connection,
        name: str,
        email: str,
        auth_id: int,
        log=gl_log,
    ) -> FullUserOut | ServiceError:
    log = log.bind(user_name=name, user_email=email, user_auth_id=auth_id)
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
        await log.ainfo("Created new user %(user_id)s", user_id=user["id"])
    elif user["name"] != name or user["email"] != email:
        user = await conn.fetchrow(
            """
            UPDATE users
            SET name = $1, email = $2
            WHERE id = $3
            RETURNING id, name, email, created_at, deleted
            """,
            name,
            email,
            user["id"],
        )
        await log.ainfo("Updated user info", user_id=user["id"], user_name=name, user_email=email)
    else:
        await log.ainfo("User exists, fetched info", user_id=user["id"])
    return FullUserOut(
        id=user["id"],
        name=user["name"],
        email=user["email"],
        created_at=user["created_at"],
        deleted=user["deleted"],
    )


async def create_test_user(
        conn: asyncpg.Connection,
        name: str | None = None,
        email: str | None = None,
        log=gl_log,
) -> FullUserOut | ServiceError:
    if name is None or email is None:
        nonce = random.randbytes(8).hex()
        if name is None:
            name = f"test_{nonce}"
        if email is None:
            email = f"test{nonce}@example.com"

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

    await log.ainfo("Created new test user", user_id=user["id"], user_name=name, user_email=email)

    return FullUserOut(
        id=user["id"],
        name=user["name"],
        email=user["email"],
        created_at=user["created_at"],
        deleted=user["deleted"],
    )


async def get_user(
        conn: asyncpg.Connection,
        id_: int,
        deleted_ok: bool = True,
        log=gl_log,
) -> FullUserOut | ServiceError:
    if deleted_ok:
        user = await conn.fetchrow(
            """
            SELECT id, name, email, created_at, deleted
            FROM users
            WHERE id = $1
            """,
            id_,
        )
    else:
        user = await conn.fetchrow(
            """
            SELECT id, name, email, created_at, deleted
            FROM users
            WHERE id = $1 AND deleted = FALSE
            """,
            id_,
        )
    if user is None:
        return await error(
            "USER_NOT_FOUND",
            "User not found",
            user_id=id_,
            log=log,
        )
    return FullUserOut(
        id=user["id"],
        name=user["name"],
        email=user["email"],
        created_at=user["created_at"],
        deleted=user["deleted"],
    )


async def check_user_exists(conn: asyncpg.Connection, id_: int) -> bool:
    return await conn.fetchval(
        """
        SELECT EXISTS (SELECT 1 FROM users WHERE id = $1)
        """,
        id_,
    )


async def check_user_exists_not_deleted(conn: asyncpg.Connection, id_: int) -> bool:
    return await conn.fetchval(
        """
        SELECT EXISTS (SELECT 1 FROM users WHERE id = $1 AND deleted = FALSE)
        """,
        id_,
    )


# async def get_user_by_auth_id(conn: asyncpg.Connection, auth_id: int) -> FullUserOut | None:
#     user = await conn.fetchrow(
#         """
#         SELECT id, name, email, created_at, deleted
#         FROM users
#         WHERE auth_id = $1
#         """,
#         auth_id,
#     )
#     if user is None:
#         return None
#     return FullUserOut(
#         id=user["id"],
#         name=user["name"],
#         email=user["email"],
#         created_at=user["created_at"],
#         deleted=user["deleted"],
#     )


async def delete_user(conn: asyncpg.Connection, id_: int, log=gl_log) -> None | ServiceError:
    deleted_id = await conn.fetchval(
        """
        UPDATE users
        SET deleted = true
        WHERE id = $1 AND deleted = false
        RETURNING id
        """,
        id_,
    )
    if deleted_id is None:
        return await error(
            "USER_NOT_FOUND",
            "User not found",
            user_id=id_,
            log=log,
        )
    await log.ainfo("Deleted user", user_id=deleted_id)
    return None
