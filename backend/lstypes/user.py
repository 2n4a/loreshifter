import dataclasses
import datetime


@dataclasses.dataclass
class FullUserOut:
    id: int
    name: str
    email: str
    created_at: datetime.datetime
    deleted: bool


@dataclasses.dataclass
class UserOut:
    id: int
    name: str
    created_at: datetime.datetime
    deleted: bool
