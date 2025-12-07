import dataclasses
import datetime
import typing

import asyncpg

from game.logger import gl_log
from lstypes.error import ServiceError, error
from lstypes.message import MessageOut, MessageKind
from game.system import System
from lstypes.chat import ChatType, ChatInterfaceType, ChatInterface, ChatSegmentOut


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
        super().__init__(id_)

    @staticmethod
    async def create_new(
            conn: asyncpg.Connection,
            game_id: int,
            kind: ChatType,
            owner_id: int | None = None,
            interface_type: ChatInterfaceType = ChatInterfaceType.FULL,
            log=gl_log,
    ) -> ChatSystem | ServiceError:
        id_ = await conn.fetchval(
            """
            INSERT INTO chats (game_id, chat_type, owner_id, interface_type)
            VALUES ($1, $2, $3, $4) RETURNING id
            """,
            game_id,
            kind,
            owner_id,
            interface_type,
        )

        if id_ is None:
            return await error("SERVER_ERROR", "Failed to create chat", log=log)

        return ChatSystem(id_)

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
            log=gl_log,
    ) -> MessageOut | ServiceError:
        if sent_at is None:
            sent_at = datetime.datetime.now()

        message_id = await conn.fetchval(
            """
            INSERT INTO messages (chat_id, sender_id, kind, text, special, metadata, sent_at)
            VALUES ($1, $2, $3, $4, $5, $6) RETURNING id
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
            return await error("SERVER_ERROR", "Failed to send message", log=log)

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

        await log.ainfo("Sent message", chat_id=self.id, message_id=message_id, message_kind=message_kind)

        self.emit(ChatMessageSentEvent(chat_id=self.id, message=message))

        return message

    async def edit_message(
            self,
            conn: asyncpg.Connection,
            message_id: int,
            text: str,
            special: str | None = None,
            metadata: dict[str, typing.Any] | None = None,
            log=gl_log,
    ) -> MessageOut | ServiceError:
        message = await conn.fetchrow(
            """
            UPDATE messages
            SET text     = $1,
                special  = $2,
                metadata = $3
            WHERE id = $4 RETURNING (id, chat_id, sender_id, kind, text, special, sent_at, metadata)
            """,
            text,
            special,
            metadata,
            message_id,
        )

        if message is None:
            return await error("MESSAGE_NOT_FOUND", "Message not found", log=log)

        await log.ainfo("Edited message", chat_id=self.id, message_id=message_id)

        message = self.message_out_from_row(message)
        self.emit(ChatMessageEditEvent(chat_id=self.id, message=message))
        return message

    async def delete_message(
            self,
            conn: asyncpg.Connection,
            message_id: int,
            log=gl_log
    ) -> MessageOut | ServiceError:
        message = await conn.fetchrow(
            """
            DELETE
            FROM messages
            WHERE id = $1 RETURNING (id, chat_id, sender_id, kind, text, special, sent_at, metadata)
            """,
            message_id,
        )

        if message is None:
            return await error("MESSAGE_NOT_FOUND", "Message not found", log=log)

        await log.ainfo("Deleted message", chat_id=self.id, message_id=message_id)

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
    ) -> ChatSegmentOut | ServiceError:
        if before_message_id is not None and after_message_id is not None:
            raise Exception("before_message_id and after_message_id are mutually exclusive")
        # if before_message_id is not None and after_message_id is not None:
        #     raise NotImplementedError("before_message_id and after_message_id are not implemented yet")

        messages = await conn.fetch(
            # language=sql
            """
            SELECT c.id as chat_id,
                   c.owner_id,
                   c.interface_type,
                   c.deadline,
                   m.id as message_id,
                   m.sender_id,
                   m.kind,
                   m.text,
                   m.special,
                   m.metadata,
                   m.sent_at
            FROM chats AS c
                     LEFT JOIN messages AS m ON c.id = m.chat_id
            WHERE c.id = $1
            ORDER BY m.id ASC NULLS FIRST
                LIMIT $2
            """,
            self.id,
            limit + 1,
        )

        if not messages:
            return await error("CHAT_NOT_FOUND", "Chat not found", log=gl_log)

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
