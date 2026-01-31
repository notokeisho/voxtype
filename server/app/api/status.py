"""Health check and status API."""

import httpx
from fastapi import APIRouter
from sqlalchemy import text

from app.config import settings
from app.database import async_session_factory

router = APIRouter(prefix="/api", tags=["status"])


async def check_database() -> str:
    """Check database connection status.

    Returns:
        "connected" if database is reachable, "disconnected" otherwise
    """
    try:
        async with async_session_factory() as session:
            await session.execute(text("SELECT 1"))
        return "connected"
    except Exception:
        return "disconnected"


async def check_whisper_server() -> str:
    """Check whisper server connection status.

    Returns:
        "connected" if whisper server is reachable, "disconnected" otherwise
    """
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{settings.whisper_server_url}/health",
                timeout=5.0,
            )
            if response.status_code == 200:
                return "connected"
            return "disconnected"
    except Exception:
        return "disconnected"


@router.get("/status")
async def get_status():
    """Get system health status.

    Returns health status of all system components:
    - status: Overall system status ("ok" if all critical components are healthy)
    - database: Database connection status
    - whisper_server: Whisper server connection status

    This endpoint does not require authentication.
    """
    database_status = await check_database()
    whisper_status = await check_whisper_server()

    # Overall status is "ok" if database is connected
    # (whisper server may be optional for some operations)
    overall_status = "ok" if database_status == "connected" else "error"

    return {
        "status": overall_status,
        "database": database_status,
        "whisper_server": whisper_status,
    }
