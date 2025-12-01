import enum

from types.utils import PgEnum


class GameStatus(enum.Enum, metaclass=PgEnum):
    __pg_enum_name__ = "game_status"
    WAITING = "waiting"
    PLAYING = "playing"
    FINISHED = "finished"
    ARCHIVED = "archived"
