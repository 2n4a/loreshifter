import dataclasses
import inspect
import typing

from enum import Enum
from structlog import BoundLogger

import config
from game.logger import gl_log


class ServiceCode(str, Enum):
    USER_NOT_FOUND = "UserNotFound"
    WORLD_NOT_FOUND = "WorldNotFound"
    GAME_NOT_FOUND = "GameNotFound"
    PLAYER_NOT_FOUND = "PlayerNotFound"
    NOT_HOST = "NotHost"
    GAME_FULL = "GameFull"
    SERVER_ERROR = "ServerError"
    MESSAGE_NOT_FOUND = "MessageNotFound"
    MUTUALLY_EXCLUSIVE_OPTIONS = "MutuallyExclusiveOptions"
    GAME_ALREADY_STARTED = "GameAlreadyStarted"
    PLAYER_NOT_READY = "PlayerNotReady"


@dataclasses.dataclass
class ServiceError:
    code: ServiceCode
    message: str
    details: dict[str, typing.Any] | None = None


LOG_STACKTRACE = config.LOG_STACKTRACE


async def error(
        code: ServiceCode, message: str,
        log: BoundLogger | None = gl_log,
        cause: Exception | None = None,
        **kwargs
) -> ServiceError:
    details = {str(k): v for k, v in kwargs.items()}
    if cause is not None:
        details['cause'] = repr(cause)

    if LOG_STACKTRACE:
        stack = inspect.stack()

        if len(stack) > 1:
            caller_frame = stack[1]
            details['call_site_filename'] = caller_frame.filename
            details['call_site_lineno'] = caller_frame.lineno
            details['call_site_function'] = caller_frame.function
            if caller_frame.code_context:
                details['call_site_code'] = caller_frame.code_context[0].strip()

        trace_list = []
        for frame_info in stack[1:]:
            trace_list.append({
                'filename': frame_info.filename,
                'lineno': frame_info.lineno,
                'function': frame_info.function,
                'code': '\n'.join(frame_info.code_context) if frame_info.code_context else None
            })
        details['stack_trace'] = trace_list

    if log is not None:
        await log.awarn(message, **details)
    return ServiceError(code, message, details)
