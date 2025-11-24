import enum
import typing
import dataclasses
import asyncpg
import datetime
import game.utils as utils

from game.system import System
from game.message import MessageKind, MessageOut


class ChatType(enum.Enum, metaclass=utils.PgEnum):
    __pg_enum_name__ = "chat_type"

    ROOM = "room"
    CHARACTER_CREATION = "characterCreation"
    GAME = "game"
    ADVICE = "advice"


class ChatInterfaceType(enum.Enum, metaclass=utils.PgEnum):
    __pg_enum_name__ = "chat_interface_type"

    READONLY = "readonly"
    FOREIGN = "foreign"
    FULL = "full"
    TIMED = "timed"
    FOREIGN_TIMED = "foreignTimed"


class Chat(typing.Protocol):
    id: int
    game_id: int
    chat_type: ChatType
    owner_id: int | None
    interface_type: ChatInterfaceType
    deadline: datetime.datetime | None


@dataclasses.dataclass
class ChatInterface:
    type: ChatInterfaceType
    deadline: datetime.datetime


@dataclasses.dataclass
class ChatSegmentOut:
    chat_id: int
    chat_owner: int | None
    messages: list[MessageOut]
    previous_id: int | None
    next_id: int | None
    suggestions = list[str]
    interface: ChatInterface


@dataclasses.dataclass
class ChatEvent:
    chat_id: int

@dataclasses.dataclass
class ChatMessageSentEvent(ChatEvent):
    message: MessageOut

@dataclasses.dataclass
class ChatMessageDeletedEvent(ChatEvent):
    message: MessageOut

@dataclasses.dataclass
class ChatMessageEditEvent(ChatEvent):
    message: MessageOut


class ChatSystem(System[ChatEvent]):
    def __init__(self, id_: int):
        super().__init__()
        self.id = id_

    @staticmethod
    async def retrieve(conn: asyncpg.Connection, id_: int) -> ChatSystem | None:
        if await conn.fetchval("SELECT id FROM chats WHERE id = $1", id_) is None:
            return None
        return ChatSystem(id_)

    @staticmethod
    async def create_new(
            conn: asyncpg.Connection,
            game_id: int,
            kind: ChatType,
            owner_id: int | None = None,
            interface_type: ChatInterfaceType = ChatInterfaceType.FULL
    ) -> ChatSystem:

        id_ = await conn.fetchval(
            """
            INSERT INTO chats (game_id, chat_type, owner_id, interface_type)
            VALUES ($1, $2, $3, $4)
            RETURNING id
            """,
            game_id,
            kind,
            owner_id,
            interface_type,
        )

        if id_ is None:
            raise Exception("Failed to create chat")

        return ChatSystem(id_.id)

    @staticmethod
    def message_out_from_row(row: dict[str, typing.Any]) -> MessageOut:
        return MessageOut(
            id=row["id"],
            chat_id=row["chat_id"],
            sender_id=row["sender_id"],
            kind=row["kind"],
            text=row["text"],
            special=row["special"],
            sent_at=row["sent_at"],
            metadata=row["metadata"],
        )

    async def send_message(
            self,
            conn: asyncpg.Connection,
            message_kind: MessageKind,
            text: str,
            sender_id: int | None,
            special: str | None = None,
            metadata: dict[str, typing.Any] | None = None,
            sent_at: datetime.datetime | None = None,
    ) -> MessageOut:
        if sent_at is None:
            sent_at = datetime.datetime.now()

        message_id = await conn.fetchval(
            """
            INSERT INTO messages (chat_id, sender_id, kind, text, special, metadata, sent_at)
            VALUES ($1, $2, $3, $4, $5, $6)
            RETURNING id
            """,
            self.id,
            sender_id,
            message_kind,
            text,
            special,
            metadata,
            sent_at,
        )

        if message_id is None:
            raise Exception("Failed to create message")

        message = MessageOut(
            id=message_id,
            chat_id=self.id,
            sender_id=sender_id,
            kind=message_kind,
            text=text,
            special=special,
            sent_at=sent_at,
            metadata=metadata
        )

        self.emit(ChatMessageSentEvent(chat_id=self.id, message=message))

        return message


    async def edit_message(
            self,
            conn: asyncpg.Connection,
            message_id: int,
            text: str,
            special: str | None = None,
            metadata: dict[str, typing.Any] | None = None,
    ) -> MessageOut | None:
        message = await conn.fetchrow(
            """
            UPDATE messages
            SET text = $1, special = $2, metadata = $3
            WHERE id = $4
            RETURNING (id, chat_id, sender_id, kind, text, special, sent_at, metadata)
            """,
            text,
            special,
            metadata,
            message_id,
        )

        if message is None:
            return None

        message = self.message_out_from_row(message)
        self.emit(ChatMessageEditEvent(chat_id=self.id, message=message))
        return message

    async def delete_message(self, conn: asyncpg.Connection, message_id: int) -> MessageOut | None:
        message = await conn.fetchrow(
            """
            DELETE FROM messages
            WHERE id = $1
            RETURNING (id, chat_id, sender_id, kind, text, special, sent_at, metadata)
            """,
            message_id,
        )

        if message is None:
            return None

        message = self.message_out_from_row(message)
        self.emit(ChatMessageDeletedEvent(chat_id=self.id, message=message))
        return message

    async def get_messages(
            self,
            conn: asyncpg.Connection,
            limit: int,
            *,
            before_message_id: int | None = None,
            after_message_id: int | None = None,
        ) -> ChatSegmentOut | None:
        if before_message_id is not None and after_message_id is not None:
            raise Exception("before_message_id and after_message_id are mutually exclusive")
        if before_message_id is not None and after_message_id is not None:
            raise NotImplementedError("before_message_id and after_message_id are not implemented yet")

        messages = await conn.fetch(
            # language=sql
            """
            SELECT 
                c.id as chat_id, c.owner_id, c.interface_type, c.deadline,
                m.id as message_id, m.sender_id, m.kind, m.text, m.special, m.metadata, m.sent_at
            FROM chats AS c
            WHERE c.id = $1
            LEFT JOIN messages AS m
                ON c.id = m.chat_id
            ORDER BY m.id ASC NULLS FIRST
            LIMIT $2
            """,
            self.id,
            limit + 1,
        )

        if not messages:
            return None

        return ChatSegmentOut(
            chat_id=messages[0]["chat_id"],
            chat_owner=messages[0]["owner_id"],
            interface=ChatInterface(
                type=messages[0]["interface_type"],
                deadline=messages[0]["deadline"],
            ),
            next_id=None,
            previous_id=messages[0]["message_id"],
            messages=[
                MessageOut(
                    chat_id=messages[0]["chat_id"],
                    id=m["message_id"],
                    sender_id=m["sender_id"],
                    kind=m["kind"],
                    text=m["text"],
                    sent_at=m["sent_at"],
                    special=m["special"],
                    metadata=m["metadata"],
                )
                for m in messages[1:]
            ]
        )
