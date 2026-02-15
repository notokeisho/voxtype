"""Admin backup run endpoints."""

from datetime import datetime

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from app.auth.dependencies import get_current_admin_user
from app.database import async_session_factory
from app.models.user import User
from app.services.backup import create_global_dictionary_backup

router = APIRouter(prefix="/admin/api", tags=["admin"])


class BackupRunResponse(BaseModel):
    """Backup run response."""

    created_file: str
    created_at: datetime
    kept: int
    deleted: int


@router.post("/dictionary/backup/run", response_model=BackupRunResponse)
async def run_backup_endpoint(
    _admin: User = Depends(get_current_admin_user),
) -> BackupRunResponse:
    """Run backup immediately."""
    async with async_session_factory() as session:
        result = await create_global_dictionary_backup(session)
        return BackupRunResponse(
            created_file=result.created_file.name,
            created_at=result.created_at,
            kept=result.kept,
            deleted=result.deleted,
        )
