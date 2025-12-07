import dataclasses
import datetime
import typing

from lstypes.user import UserOut


@dataclasses.dataclass
class WorldOut:
    id: int
    name: str
    owner: UserOut
    public: bool
    description: str | None
    data: typing.Any | None
    created_at: datetime.datetime
    last_updated_at: datetime.datetime
    deleted: bool

@dataclasses.dataclass
class ShortWorldOut:
    id: int
    name: str
    owner: UserOut
    public: bool
    description: str | None
    created_at: datetime.datetime
    last_updated_at: datetime.datetime
    deleted: bool
