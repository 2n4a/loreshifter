from types.chat import ChatType
from events.chat import ChatSystem
from tests import postgres_connection_string, db
import pytest


@pytest.mark.asyncio
async def test_chat(db):
    chat = await ChatSystem.create_new(db, 0, ChatType.ROOM)
    assert chat.id == 1
