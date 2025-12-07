from pathlib import Path

import asyncpg
import pytest_asyncio

import config
from app.dependencies import init_connection
from game.universe import Universe


@pytest_asyncio.fixture(scope="session")
async def postgres_connection_string():
    dsn = config.POSTGRES_URL
    test_dsn = "postgres://test:test@localhost:5432/test"

    primary_connection: asyncpg.Connection = await asyncpg.connect(dsn)
    try:
        await primary_connection.execute("DROP DATABASE IF EXISTS test WITH (FORCE)")
        await primary_connection.execute("CREATE DATABASE test")
        await primary_connection.execute("DROP USER IF EXISTS test")
        await primary_connection.execute("CREATE USER test WITH PASSWORD 'test'")
        await primary_connection.execute("GRANT ALL PRIVILEGES ON DATABASE test TO test")
        await primary_connection.execute("ALTER DATABASE test OWNER TO test")
        connection = await asyncpg.connect(test_dsn)
        try:
            for migration in sorted(Path("../db/migrations/").glob("*.sql")):
                await connection.execute(migration.read_text())
        finally:
            await connection.close()
    finally:
        await primary_connection.close()

    return test_dsn


@pytest_asyncio.fixture
async def db(postgres_connection_string):
    conn = await asyncpg.connect(postgres_connection_string)
    await init_connection(conn)
    trxn = conn.transaction(isolation="serializable")
    await trxn.start()
    try:
        yield conn
    finally:
        await trxn.rollback()


@pytest_asyncio.fixture
async def universe():
    universe = Universe()
    yield universe
    await universe.stop()
