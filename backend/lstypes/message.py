import dataclasses
import datetime
from typing import Protocol, Any

from lstypes.utils import PgEnum


class MessageKind(metaclass=PgEnum):
    __pg_enum_name__ = "message_kind"

    PLAYER = "player"
    SYSTEM = "system"
    CHARACTER_CREATION = "characterCreation"
    GENERAL_INFO = "generalInfo"
    PUBLIC_INFO = "publicInfo"
    PRIVATE_INFO = "privateInfo"


class Message(Protocol):
    id: int
    chat_id: int
    sender_id: int | None
    kind: MessageKind
    text: str
    special: str | None
    sent_at: datetime.datetime
    metadata: dict[str, Any] | None


@dataclasses.dataclass
class MessageOut:
    id: int
    chat_id: int
    sender_id: int | None
    kind: MessageKind
    text: str
    special: str | None
    sent_at: datetime.datetime
    metadata: dict[str, Any] | None


@dataclasses.dataclass
class MessageOutWithNeighbors:
    msg: MessageOut
    next_id: int | None
    prev_id: int | None
