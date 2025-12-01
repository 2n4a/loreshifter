from fastapi import APIRouter

from app.dependencies import Conn, U

router = APIRouter()


@router.post("/api/v0/play/ready")
async def ready(conn: Conn, universe: U):
    universe
