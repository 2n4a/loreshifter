import dataclasses
import datetime

from lstypes.user import UserOut


@dataclasses.dataclass
class PlayerOut:
    user: UserOut
    is_ready: bool
    is_host: bool
    is_spectator: bool
    is_joined: bool
    joined_at: datetime.datetime
