import typing

from pydantic import BaseModel

from lstypes.error import ServiceCode, ServiceError


class ApiError(BaseModel):
    code: str
    message: str
    details: dict[str, typing.Any] | None = None


class ApiErrorException(Exception):
    def __init__(self, status_code: int, error: ApiError):
        super().__init__(error.message)
        self.status_code = status_code
        self.error = error


def _status_code_from_service_code(code: ServiceCode) -> int:
    match code:
        case ServiceCode.SERVER_ERROR:
            return 500
        case ServiceCode.NOT_HOST:
            return 403
        case ServiceCode.GAME_FULL:
            return 409
        case (
            ServiceCode.USER_NOT_FOUND
            | ServiceCode.WORLD_NOT_FOUND
            | ServiceCode.GAME_NOT_FOUND
            | ServiceCode.PLAYER_NOT_FOUND
        ):
            return 404
        case _:
            return 400


def api_error(code: str, message: str, details: dict[str, typing.Any] | None = None) -> ApiError:
    return ApiError(code=code, message=message, details=details)


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
        ApiError(
            code=err.code.value,
            message=err.message,
            details=err.details,
        ),
    )


def unwrap[T](result: T | ServiceError) -> T:
    if isinstance(result, ServiceError):
        raise_for_service_error(result)
    return result
