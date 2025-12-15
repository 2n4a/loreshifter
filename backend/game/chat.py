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
    prev: "MessageRef | None" = None
    next: "MessageRef | None" = None

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
    """
    Stable doubly-linked list for messages with a dummy head AND dummy tail.
    Keeps the same public API as the original.
    """

    def __init__(self):
        self._head = MessageRef(None)
        self._tail = MessageRef(None)
        self._head.next = self._tail
        self._tail.prev = self._head

        self.first = self._head
        self.last = self._tail

        self.index: dict[int, MessageRef] = {}

    def _is_empty(self) -> bool:
        return self._head.next is self._tail

    def _refresh_first_last(self) -> None:
        if self._is_empty():
            self.first = self._head
            self.last = self._tail
        else:
            self.first = self._head.next
            self.last = self._tail.prev

    def append(self, msg: MessageOut) -> MessageRef:
        ref = MessageRef(msg)

        prev = self._tail.prev
        assert prev is not None

        prev.next = ref
        ref.prev = prev
        ref.next = self._tail
        self._tail.prev = ref

        self.index[msg.id] = ref
        self._refresh_first_last()
        return ref

    def edit(self, msg: MessageOut) -> bool:
        ref = self.index.get(msg.id)
        if ref is None:
            return False
        ref.msg = msg
        return True

    def delete(self, id_: int) -> MessageOut | None:
        ref = self.index.get(id_)
        if ref is None:
            return None

        assert ref.prev is not None and ref.next is not None
        ref.prev.next = ref.next
        ref.next.prev = ref.prev

        del self.index[id_]
        self._refresh_first_last()
        return ref.msg

    def walk_forward(self, start_id: int | None, count: int) -> typing.Generator[MessageRef, None, None]:
        if count <= 0 or self._is_empty():
            return

        if start_id is None:
            cur = self._head.next
        else:
            start = self.index.get(start_id)
            if start is None:
                return
            cur = start.next

        while cur is not None and cur is not self._tail and count > 0:
            yield cur
            cur = cur.next
            count -= 1

    def walk_backward(self, start_id: int | None, count: int) -> typing.Generator[MessageRef, None, None]:
        if count <= 0 or self._is_empty():
            return

        if start_id is None:
            cur = self._tail.prev
        else:
            cur = self.index.get(start_id)
            if cur is None:
                return

        while cur is not None and cur is not self._head and count > 0:
            yield cur
            cur = cur.prev
            count -= 1


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
    ) -> "ChatSystem" | ServiceError:
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
            metadata=metadata,
        )

        ref = self.index.append(message)
        out = ref.to_message_out_with_neighbors()

        self.emit(ChatMessageSentEvent(chat_id=self.id, message=out))
        return out

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

        if len(self.index.index) == 0:
            return ChatSegmentOut(
                chat_id=chat_info["chat_id"],
                chat_owner=chat_info["owner_id"],
                interface=ChatInterface(
                    type=chat_info["interface_type"],
                    deadline=chat_info["deadline"],
                ),
                previous_id=None,
                next_id=None,
                messages=[],
                suggestions=self.suggestions,
            )

        if after_message_id is not None:
            if after_message_id not in self.index.index:
                return await error(
                    "MESSAGE_NOT_FOUND",
                    "Message with id 'after_message_id' not found",
                    log=gl_log
                )
            messages = list(self.index.walk_forward(after_message_id, limit))
            if not messages:
                return ChatSegmentOut(
                    chat_id=chat_info["chat_id"],
                    chat_owner=chat_info["owner_id"],
                    interface=ChatInterface(
                        type=chat_info["interface_type"],
                        deadline=chat_info["deadline"],
                    ),
                    previous_id=after_message_id,
                    next_id=None,
                    messages=[],
                    suggestions=self.suggestions,
                )
        else:
            if before_message_id is not None and before_message_id not in self.index.index:
                return await error(
                    "MESSAGE_NOT_FOUND",
                    "Message with id 'before_message_id' not found",
                    log=gl_log
                )
            messages = list(self.index.walk_backward(before_message_id, limit))

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
            messages=[m.msg for m in messages if m.msg is not None],
            suggestions=self.suggestions,
        )
