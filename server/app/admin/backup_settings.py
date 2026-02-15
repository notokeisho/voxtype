"""Admin backup settings endpoints."""

from datetime import datetime

from fastapi import APIRouter, Depends
from pydantic import BaseModel, ConfigDict

from app.auth.dependencies import get_current_admin_user
from app.database import async_session_factory
from app.models.backup_settings import get_backup_settings
from app.models.user import User

router = APIRouter(prefix="/admin/api", tags=["admin"])


class BackupSettingsResponse(BaseModel):
    """Backup settings response."""

    model_config = ConfigDict(from_attributes=True)

    enabled: bool
    last_run_at: datetime | None


class BackupSettingsUpdateRequest(BaseModel):
    """Backup settings update request."""

    enabled: bool


@router.get("/dictionary/backup", response_model=BackupSettingsResponse)
async def get_backup_settings_endpoint(
    _admin: User = Depends(get_current_admin_user),
) -> BackupSettingsResponse:
    """Get backup settings."""
    async with async_session_factory() as session:
        settings = await get_backup_settings(session)
        return BackupSettingsResponse.model_validate(settings)


@router.patch("/dictionary/backup", response_model=BackupSettingsResponse)
async def update_backup_settings_endpoint(
    request: BackupSettingsUpdateRequest,
    _admin: User = Depends(get_current_admin_user),
) -> BackupSettingsResponse:
    """Update backup settings."""
    async with async_session_factory() as session:
        settings = await get_backup_settings(session)
        settings.enabled = request.enabled
        await session.commit()
        await session.refresh(settings)
        return BackupSettingsResponse.model_validate(settings)
