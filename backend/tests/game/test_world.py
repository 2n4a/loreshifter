import pytest

from game.user import create_test_user


@pytest.mark.asyncio
async def test_create_world(db, universe):
    user = await create_test_user(db)
    world = await universe.create_world(db, "test_world", user.id, True)
    assert world.name == "test_world"
    assert world.owner.id == user.id
    assert world.public is True
