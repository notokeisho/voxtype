"""Admin backup files listing endpoints."""

from datetime import datetime

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from app.auth.dependencies import get_current_admin_user
from app.models.user import User
from app.services.backup import list_backup_files

router = APIRouter(prefix="/admin/api", tags=["admin"])


class BackupFileResponse(BaseModel):
    """Backup file response."""

    filename: str
    created_at: datetime
    size_bytes: int


class BackupFilesResponse(BaseModel):
    """Backup files list response."""

    files: list[BackupFileResponse]


@router.get("/dictionary/backup/files", response_model=BackupFilesResponse)
async def list_backup_files_endpoint(
    _admin: User = Depends(get_current_admin_user),
) -> BackupFilesResponse:
    """List server-side backup files."""
    files = list_backup_files()
    return BackupFilesResponse(
        files=[
            BackupFileResponse(
                filename=item.filename,
                created_at=item.created_at,
                size_bytes=item.size_bytes,
            )
            for item in files
        ]
    )
