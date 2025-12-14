import typing

from pydantic import BaseModel

from lstypes.error import ServiceError


class ApiError(BaseModel):
    code: str
    message: str
    details: dict[str, typing.Any] | None = None


class ApiErrorException(Exception):
    def __init__(self, status_code: int, error: ApiError):
        super().__init__(error.message)
        self.status_code = status_code
        self.error = error


_SERVICE_TO_API_CODE: dict[str, str] = {
    "USER_NOT_FOUND": "UserNotFound",
    "WORLD_NOT_FOUND": "WorldNotFound",
    "GAME_NOT_FOUND": "GameNotFound",
    "PLAYER_NOT_FOUND": "PlayerNotFound",
    "NOT_HOST": "NotHost",
    "GAME_FULL": "GameFull",
    "SERVER_ERROR": "ServerError",
}


def _status_code_from_service_code(code: str) -> int:
    match code:
        case "SERVER_ERROR":
            return 500
        case "NOT_HOST":
            return 403
        case "GAME_FULL":
            return 409
        case "USER_NOT_FOUND" | "WORLD_NOT_FOUND" | "GAME_NOT_FOUND" | "PLAYER_NOT_FOUND":
            return 404
        case _:
            return 400


def api_error(code: str, message: str, details: dict[str, typing.Any] | None = None) -> ApiError:
    return ApiError(code=code, message=message, details=details)


def api_error_from_service_error(err: ServiceError) -> ApiError:
    api_code = _SERVICE_TO_API_CODE.get(err.code, err.code)
    return ApiError(
        code=api_code,
        message=err.message,
        details=err.details,
    )


def raise_api_error(
        status_code: int,
        code: str,
        message: str,
        details: dict[str, typing.Any] | None = None,
) -> typing.NoReturn:
    raise ApiErrorException(status_code, api_error(code, message, details))


def raise_for_service_error(err: ServiceError) -> typing.NoReturn:
    raise ApiErrorException(
        _status_code_from_service_code(err.code),
        api_error_from_service_error(err),
    )


T = typing.TypeVar("T")


def unwrap(result: T | ServiceError) -> T:
    if isinstance(result, ServiceError):
        raise_for_service_error(result)
    return result
