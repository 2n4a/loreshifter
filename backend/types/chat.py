import dataclasses
import datetime
import enum
import typing

import types.utils
from game.message import MessageOut


class ChatType(enum.Enum, metaclass=types.utils.PgEnum):
    __pg_enum_name__ = "chat_type"

    ROOM = "room"
    CHARACTER_CREATION = "characterCreation"
    GAME = "game"
    ADVICE = "advice"


class ChatInterfaceType(enum.Enum, metaclass=types.utils.PgEnum):
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


