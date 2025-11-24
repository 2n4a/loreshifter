from fastapi import APIRouter, HTTPException

from app.dependencies import User, Conn, Auth
from game.user import UserOut, OtherUserOut
import game.user

router = APIRouter()


@router.get("/api/v0/user/me")
async def get_user(user: Auth) -> UserOut:
    return user


@router.get("/api/v0/user/{id}")
async def get_user(user: User, conn: Conn, id: int) -> UserOut | OtherUserOut:
    if id == 0 or id == user.id:
        return user
    user = await game.user.get_user(conn, id)
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    return OtherUserOut(
        id=user.id,
        name=user.name,
        created_at=user.created_at,
    )
