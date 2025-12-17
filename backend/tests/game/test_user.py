import pytest

from game.user import (
    get_or_create_user,
    get_user,
    delete_user,
    create_test_user,
    check_user_exists,
    check_user_exists_not_deleted,
)
from lstypes.error import ServiceCode, ServiceError
from lstypes.user import FullUserOut


@pytest.mark.asyncio
async def test_get_or_create_user(db):
    user = await get_or_create_user(db, "test_user", "test@example.com", 1337)
    assert isinstance(user, FullUserOut)
    assert user.name == "test_user"
    assert user.email == "test@example.com"

    user = await get_or_create_user(db, "test_user", "new_test@example.com", 1337)
    assert isinstance(user, FullUserOut)
    assert user.name == "test_user"
    assert user.email == "new_test@example.com"

    user = await get_or_create_user(db, "test", "new_test@example.com", 1337)
    assert isinstance(user, FullUserOut)
    assert user.name == "test"
    assert user.email == "new_test@example.com"

    user = await get_or_create_user(db, "test", "new_test@example.com", 1337)
    assert isinstance(user, FullUserOut)
    assert user.name == "test"
    assert user.email == "new_test@example.com"


@pytest.mark.asyncio
async def test_get_user(db):
    user = await create_test_user(db, "test_user")
    retrieved_user = await get_user(db, user.id)
    assert isinstance(retrieved_user, FullUserOut)
    assert user.id == retrieved_user.id
    assert user.name == retrieved_user.name

    fail = await get_user(db, -123)
    assert isinstance(fail, ServiceError)
    assert fail.code == ServiceCode.USER_NOT_FOUND

    user = await create_test_user(db, "test_user2")
    await delete_user(db, user.id)
    retrieved_user = await get_user(db, user.id)
    assert isinstance(retrieved_user, FullUserOut)
    assert user.id == retrieved_user.id
    assert user.name == retrieved_user.name
    assert retrieved_user.deleted

    user = await create_test_user(db, "test_user3")
    await delete_user(db, user.id)
    retrieved_user = await get_user(db, user.id, deleted_ok=False)
    assert isinstance(retrieved_user, ServiceError)
    assert fail.code == ServiceCode.USER_NOT_FOUND


@pytest.mark.asyncio
async def test_delete_user(db):
    user = await create_test_user(db, "test_user")
    await delete_user(db, user.id)
    retrieved_user = await get_user(db, user.id)
    assert retrieved_user.deleted
    assert await check_user_exists(db, user.id)
    assert not await check_user_exists_not_deleted(db, user.id)
