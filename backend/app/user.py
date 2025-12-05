from fastapi import APIRouter, HTTPException

from app.dependencies import UserDep, Conn, AuthDep
from lstypes.user import FullUserOut, UserOut
import game.user

router = APIRouter()


@router.get("/api/v0/user/me")
async def get_user(user: AuthDep) -> FullUserOut:
    return user


@router.get("/api/v0/user/{id_}")
async def get_user(user: UserDep, conn: Conn, id_: int) -> FullUserOut | UserOut:
    if id_ == 0 or id_ == user.id:
        return user
    user = await game.user.get_user(conn, id_)
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    return UserOut(
        id=user.id,
        name=user.name,
        created_at=user.created_at,
    )
