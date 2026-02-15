"""Admin backup restore endpoints."""

from datetime import datetime
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from app.auth.dependencies import get_current_admin_user
from app.database import async_session_factory
from app.models.user import User
from app.services.backup_restore import restore_global_dictionary_from_backup

router = APIRouter(prefix="/admin/api", tags=["admin"])


class BackupRestoreRequest(BaseModel):
    """Backup restore request."""

    filename: str
    mode: str


class BackupRestoreResponse(BaseModel):
    """Backup restore response."""

    restored_file: str
    mode: str
    total: int
    added: int
    skipped: int
    failed: int
    restored_at: datetime


@router.post("/dictionary/backup/restore", response_model=BackupRestoreResponse)
async def restore_backup_endpoint(
    request: BackupRestoreRequest,
    _admin: User = Depends(get_current_admin_user),
) -> BackupRestoreResponse:
    """Restore global dictionary from a server-side backup file."""
    async with async_session_factory() as session:
        try:
            result = await restore_global_dictionary_from_backup(
                session=session,
                filename=request.filename,
                mode=request.mode,
                base_dir=Path("./data/backups"),
            )
        except FileNotFoundError as exc:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Backup file not found",
            ) from exc

    return BackupRestoreResponse(
        restored_file=result.restored_file,
        mode=result.mode,
        total=result.total,
        added=result.added,
        skipped=result.skipped,
        failed=result.failed,
        restored_at=result.restored_at,
    )
