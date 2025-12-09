import dataclasses
import datetime
import typing

import asyncpg

from game.logger import gl_log
from lstypes.error import ServiceError, error
from lstypes.message import MessageOut, MessageKind, MessageOutWithNeighbors
from game.system import System
from lstypes.chat import ChatType, ChatInterfaceType, ChatInterface, ChatSegmentOut


@dataclasses.dataclass
class ChatEvent:
    chat_id: int


@dataclasses.dataclass
class ChatMessageSentEvent(ChatEvent):
    message: MessageOutWithNeighbors


@dataclasses.dataclass
class ChatMessageDeletedEvent(ChatEvent):
    message: MessageOut


@dataclasses.dataclass
class ChatMessageEditEvent(ChatEvent):
    message: MessageOut


@dataclasses.dataclass
class ChatUpdatedSuggestions(ChatEvent):
    suggestions: list[str]


@dataclasses.dataclass
class MessageRef:
    msg: MessageOut | None
    prev: MessageRef | None = None
    next: MessageRef | None = None

    def to_message_out_with_neighbors(self) -> MessageOutWithNeighbors:
        prev_id = None
        next_id = None
        if self.prev is not None and self.prev.msg is not None:
            prev_id = self.prev.msg.id
        if self.next is not None and self.next.msg is not None:
            next_id = self.next.msg.id
        return MessageOutWithNeighbors(
            msg=self.msg,
            prev_id=prev_id,
            next_id=next_id,
        )

class MessageIndex:
    def __init__(self):
        dummy = MessageRef(None)
        self.first = dummy
        self.last = dummy
        self.index: dict[int, MessageRef] = {-1: dummy}

    def append(self, msg: MessageOut) -> MessageRef:
        ref = MessageRef(msg)
        self.last.next = ref
        ref.prev = self.last
        self.last = ref
        self.index[msg.id] = ref
        return ref

    def edit(self, msg: MessageOut) -> bool:
        if msg.id not in self.index:
            return False
        ref = self.index[msg.id]
        ref.msg = msg
        return True

    def delete(self, id_: int) -> MessageOut | None:
        if id_ not in self.index:
            return None
        ref = self.index[id_]
        ref.prev.next = ref.next
        ref.next.prev = ref.prev
        del self.index[id_]

        if self.first.msg.id == id_:
            self.first = ref.next
        if self.last.msg.id == id_:
            self.last = ref.prev
        return ref.msg

    def walk_forward(self, start_id: int | None, count: int) -> typing.Generator[MessageRef, None, None]:
        if start_id is None:
            ref = self.first
        elif start_id not in self.index:
            return
        else:
            ref =self.index[start_id].prev
        for _ in range(count):
            ref = ref.next
            if ref is None:
                break
            yield ref

    def walk_backward(self, start_id: int | None, count: int) -> typing.Generator[MessageRef, None, None]:
        if start_id is None:
            ref = self.last
        elif start_id not in self.index:
            return
        else:
            ref = self.index[start_id]
        for _ in range(count):
            yield ref
            ref = ref.prev
            if ref is None or ref.msg is None:
                break


class ChatSystem(System[ChatEvent]):
    def __init__(self, id_: int):
        super().__init__(id_)
        self.index = MessageIndex()
        self.suggestions = []

    @staticmethod
    async def create_or_load(
            conn: asyncpg.Connection,
            game_id: int,
            kind: ChatType,
            owner_id: int | None = None,
            interface_type: ChatInterfaceType = ChatInterfaceType.FULL,
            log=gl_log,
    ) -> ChatSystem | ServiceError:
        id_ = await conn.fetchval(
            """
            SELECT id FROM chats
            WHERE game_id = $1 AND chat_type = $2 AND owner_id = $3
            """,
            game_id,
            kind,
            owner_id,
        )

        if id_ is None:
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

        chat_system = ChatSystem(id_)

        messages = await conn.fetch(
            """
            SELECT id, chat_id, sender_id, kind, text, special, sent_at, metadata
            FROM messages
            WHERE chat_id = $1
            ORDER BY id
            """,
            id_,
        )

        for row in messages:
            message = ChatSystem.message_out_from_row(row)
            chat_system.index.append(message)

        return chat_system

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
    ) -> MessageOutWithNeighbors | ServiceError:
        if sent_at is None:
            sent_at = datetime.datetime.now()

        message_id = await conn.fetchval(
            """
            INSERT INTO messages (chat_id, sender_id, kind, text, special, metadata, sent_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id
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

        ref = self.index.append(message)
        message = ref.to_message_out_with_neighbors()

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
            WHERE id = $4 RETURNING id, chat_id, sender_id, kind, text, special, sent_at, metadata
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

        assert self.index.edit(message)

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
            WHERE id = $1 RETURNING id, chat_id, sender_id, kind, text, special, sent_at, metadata
            """,
            message_id,
        )

        if message is None:
            return await error("MESSAGE_NOT_FOUND", "Message not found", log=log)

        await log.ainfo("Deleted message", chat_id=self.id, message_id=message_id)

        message = self.message_out_from_row(message)

        assert self.index.delete(message_id) is not None

        self.emit(ChatMessageDeletedEvent(chat_id=self.id, message=message))
        return message

    async def get_messages(
            self,
            conn: asyncpg.Connection,
            limit: int,
            *,
            before_message_id: int | None = None,
            after_message_id: int | None = None,
            log=gl_log,
    ) -> ChatSegmentOut | ServiceError:
        log = log.bind(limit=limit, before_message_id=before_message_id, after_message_id=after_message_id)

        if before_message_id is not None and after_message_id is not None:
            return await error(
                "MUTUALLY_EXCLUSIVE_OPTIONS",
                "before_message_id and after_message_id are mutually exclusive",
                log=log
            )

        chat_info = await conn.fetchrow(
            """
            SELECT c.id as chat_id,
                   c.owner_id,
                   c.interface_type,
                   c.deadline
            FROM chats AS c
            WHERE c.id = $1
            """,
            self.id,
        )

        if not chat_info:
            return await error("SERVER_ERROR", "Chat not found", log=gl_log)

        if after_message_id is not None:
            messages = list(self.index.walk_forward(after_message_id, limit))
            if not messages:
                return await error(
                    "MESSAGE_NOT_FOUND",
                    "Message with id 'after_message_id' not found",
                    log=gl_log
                )
        else:
            messages = list(self.index.walk_backward(before_message_id, limit))
            if not messages:
                return await error(
                    "MESSAGE_NOT_FOUND",
                    "Message with id 'before_message_id' not found",
                    log=gl_log
                )

        messages.sort(key=lambda ref: ref.msg.id)

        return ChatSegmentOut(
            chat_id=chat_info["chat_id"],
            chat_owner=chat_info["owner_id"],
            interface=ChatInterface(
                type=chat_info["interface_type"],
                deadline=chat_info["deadline"],
            ),
            previous_id=messages[0].prev.msg.id if messages and messages[0].prev and messages[0].prev.msg else None,
            next_id=messages[-1].next.msg.id if messages and messages[-1].next and messages[-1].next.msg else None,
            messages=[m.msg for m in messages],
            suggestions=self.suggestions,
        )

    async def add_suggestion(self, suggestion: str):
        self.suggestions.append(suggestion)
        self.emit(
            ChatUpdatedSuggestions(
                chat_id=self.id,
                suggestions=self.suggestions,
            )
        )

    async def clear_suggestions(self):
        if not self.suggestions:
            return
        self.suggestions = []
        self.emit(
            ChatUpdatedSuggestions(
                chat_id=self.id,
                suggestions=self.suggestions,
            )
        )
