import dataclasses
import datetime
import typing


@dataclasses.dataclass
class WorldOut:
    id: int
    name: str
    owner_id: int
    public: bool
    description: str | None
    data: typing.Any
    created_at: datetime.datetime
    last_updated_at: datetime.datetime
    deleted: bool
