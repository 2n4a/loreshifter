import inspect
import typing

from enum import Enum
from structlog import BoundLogger

from pydantic import BaseModel

import config
from game.logger import gl_log


class ServiceCode(str, Enum):
    USER_NOT_FOUND = "UserNotFound"
    WORLD_NOT_FOUND = "WorldNotFound"
    GAME_NOT_FOUND = "GameNotFound"
    PLAYER_NOT_FOUND = "PlayerNotFound"
    CHAT_NOT_FOUND = "ChatNotFound"
    NOT_HOST = "NotHost"
    UNAUTHORIZED = "Unauthorized"
    CANNOT_ACCESS_CHAT = "CannotAccessChat"
    GAME_FULL = "GameFull"
    SERVER_ERROR = "ServerError"
    MESSAGE_NOT_FOUND = "MessageNotFound"
    MUTUALLY_EXCLUSIVE_OPTIONS = "MutuallyExclusiveOptions"
    GAME_ALREADY_STARTED = "GameAlreadyStarted"
    GAME_NEW_HOST_NOT_FOUND = "GameNewHostNotFound"
    GAME_MAX_PLAYERS_TOO_SMALL = "GameMaxPlayersTooSmall"
    PLAYER_NOT_IN_GAME = "PlayerNotInGame"
    GAME_NOT_FINISHED = "GameNotFinished"
    PLAYER_NOT_READY = "PlayerNotReady"
    CHARACTER_NOT_READY = "CharacterNotReady"
    INVALID_PROVIDER = "InvalidProvider"


class ServiceError(BaseModel):
    code: ServiceCode
    message: str
    details: dict[str, typing.Any] | None = None


class ServiceErrorException(Exception):
    def __init__(self, status_code: int, error: ServiceError):
        super().__init__(error.message)
        self.status_code = status_code
        self.error = error


def status_code_from_service_code(code: ServiceCode) -> int:
    match code:
        case ServiceCode.SERVER_ERROR:
            return 500
        case (
            ServiceCode.UNAUTHORIZED
            | ServiceCode.NOT_HOST
            | ServiceCode.CANNOT_ACCESS_CHAT
        ):
            return 401
        case ServiceCode.GAME_FULL:
            return 409
        case (
            ServiceCode.USER_NOT_FOUND
            | ServiceCode.WORLD_NOT_FOUND
            | ServiceCode.GAME_NOT_FOUND
            | ServiceCode.PLAYER_NOT_FOUND
            | ServiceCode.MESSAGE_NOT_FOUND
            | ServiceCode.CHAT_NOT_FOUND
        ):
            return 404
        case ServiceCode.CHARACTER_NOT_READY:
            return 400
        case _:
            return 400


def raise_service_error(
    status_code: int,
    code: ServiceCode,
    message: str,
    details: dict[str, typing.Any] | None = None,
) -> typing.NoReturn:
    raise ServiceErrorException(
        status_code, ServiceError(code=code, message=message, details=details)
    )


def raise_for_service_error(err: ServiceError) -> typing.NoReturn:
    raise ServiceErrorException(status_code_from_service_code(err.code), err)


def unwrap[T](result: T | ServiceError) -> T:
    if isinstance(result, ServiceError):
        raise_for_service_error(result)
    return result


LOG_STACKTRACE = config.LOG_STACKTRACE


async def error(
    code: ServiceCode,
    message: str,
    log: BoundLogger | None = gl_log,
    cause: Exception | None = None,
    **kwargs,
) -> ServiceError:
    details = {str(k): v for k, v in kwargs.items()}
    if cause is not None:
        details["cause"] = repr(cause)

    if LOG_STACKTRACE:
        stack = inspect.stack()

        if len(stack) > 1:
            caller_frame = stack[1]
            details["call_site_filename"] = caller_frame.filename
            details["call_site_lineno"] = caller_frame.lineno
            details["call_site_function"] = caller_frame.function
            if caller_frame.code_context:
                details["call_site_code"] = caller_frame.code_context[0].strip()

        trace_list = []
        for frame_info in stack[1:]:
            trace_list.append(
                {
                    "filename": frame_info.filename,
                    "lineno": frame_info.lineno,
                    "function": frame_info.function,
                    "code": (
                        "\n".join(frame_info.code_context)
                        if frame_info.code_context
                        else None
                    ),
                }
            )
        details["stack_trace"] = trace_list

    if log is not None:
        await log.awarn(message, **details)
    return ServiceError(code=code, message=message, details=details)
