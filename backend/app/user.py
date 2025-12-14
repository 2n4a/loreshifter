from fastapi import APIRouter

from app.api_error import raise_api_error, unwrap
from app.dependencies import UserDep, Conn, AuthDep
from lstypes.user import FullUserOut, UserOut
import game.user

router = APIRouter()


@router.get("/api/v0/user/me")
async def get_user(user: AuthDep) -> FullUserOut:
    return user


@router.get("/api/v0/user/{id_}")
async def get_user_by_id(requester: UserDep, conn: Conn, id_: int) -> FullUserOut | UserOut:
    if id_ == 0:
        if requester is None:
            raise_api_error(401, "Unauthorized", "Not authenticated")
        return requester

    if requester is not None and id_ == requester.id:
        return requester

    user = unwrap(await game.user.get_user(conn, id_, deleted_ok=False))
    return UserOut(
        id=user.id,
        name=user.name,
        created_at=user.created_at,
        deleted=user.deleted,
    )
