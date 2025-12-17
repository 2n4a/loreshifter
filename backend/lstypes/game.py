import dataclasses
import datetime
import enum

from lstypes.chat import ChatSegmentOut
from lstypes.player import PlayerOut
from lstypes.utils import PgEnum
from lstypes.world import ShortWorldOut


class GameStatus(enum.Enum, metaclass=PgEnum):
    __pg_enum_name__ = "game_status"
    WAITING = "waiting"
    PLAYING = "playing"
    FINISHED = "finished"
    ARCHIVED = "archived"


@dataclasses.dataclass
class GameOut:
    id: int
    code: str
    public: bool
    name: str
    world: ShortWorldOut
    host_id: int
    players: list[PlayerOut]
    created_at: datetime.datetime
    max_players: int
    status: GameStatus


@dataclasses.dataclass
class StateOut:
    game: GameOut
    status: GameStatus
    character_creation_chat: ChatSegmentOut | None = None
    game_chat: ChatSegmentOut | None = None
    player_chats: list[ChatSegmentOut] = dataclasses.field(default_factory=list)
    advice_chats: list[ChatSegmentOut] = dataclasses.field(default_factory=list)
