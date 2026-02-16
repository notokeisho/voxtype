"""Admin backup files listing endpoints."""

from datetime import datetime
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import FileResponse
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


@router.get("/dictionary/backup/files/{filename:path}/download")
async def download_backup_file_endpoint(
    filename: str,
    _admin: User = Depends(get_current_admin_user),
) -> FileResponse:
    """Download a server-side backup file."""
    if Path(filename).name != filename:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid filename",
        )
    if not filename.lower().endswith(".xlsx"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid filename",
        )

    backup_path = Path("./data/backups") / filename
    if not backup_path.exists() or not backup_path.is_file():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Backup file not found",
        )

    return FileResponse(
        path=backup_path,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        filename=filename,
    )
