import pytest

from game.user import create_test_user


@pytest.mark.asyncio
async def test_create_world(db, universe):
    user = await create_test_user(db)
    world = await universe.create_world(db, "test_world", user.id, True)
    assert world.name == "test_world"
    assert world.owner.id == user.id
    assert world.public is True


@pytest.mark.asyncio
async def test_get_worlds(db, universe):
    user1 = await create_test_user(db, "user1")
    user2 = await create_test_user(db, "user2")
    await universe.create_world(db, "w1", user1.id, True)
    await universe.create_world(db, "w2", user2.id, True)
    await universe.create_world(db, "w3", user1.id, False)
    await universe.create_world(db, "w4", user2.id, False)

    worlds = await universe.get_worlds(db, 10, 0, sort="asc", requester_id=user1.id)
    assert len(worlds) == 3
    assert worlds[0].owner.name == "user1"
    assert worlds[1].owner.name == "user2"
    assert worlds[2].owner.name == "user1"

    worlds = await universe.get_worlds(db, 1, 0, sort="desc")
    assert len(worlds) == 1
    assert worlds[0].owner.name == "user2"
    assert worlds[0].name == "w2"


@pytest.mark.asyncio
async def test_get_world(db, universe):
    user = await create_test_user(db)
    created_world = await universe.create_world(db, "test_world", user.id, True)
    retrieved_world = await universe.get_world(db, created_world.id)
    assert retrieved_world.name == "test_world"
    assert retrieved_world.owner.id == user.id
    assert retrieved_world.public is True
