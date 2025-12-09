import dataclasses
import datetime
import enum
import typing

import lstypes.utils
from lstypes.message import MessageOut


class ChatType(enum.Enum, metaclass=lstypes.utils.PgEnum):
    __pg_enum_name__ = "chat_type"

    ROOM = "room"
    CHARACTER_CREATION = "character_creation"
    GAME = "game"
    ADVICE = "advice"


class ChatInterfaceType(enum.Enum, metaclass=lstypes.utils.PgEnum):
    __pg_enum_name__ = "chat_interface_type"

    READONLY = "readonly"
    FOREIGN = "foreign"
    FULL = "full"
    TIMED = "timed"
    FOREIGN_TIMED = "foreign_timed"


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
    suggestions: list[str]
    interface: ChatInterface
