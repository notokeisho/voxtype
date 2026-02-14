"""Admin dictionary request management API endpoints."""

from datetime import datetime

from fastapi import APIRouter, Depends
from pydantic import BaseModel, ConfigDict

from app.auth.dependencies import get_current_admin_user
from app.database import async_session_factory
from app.models.global_dictionary_request import (
    get_pending_request_count,
    get_pending_requests,
)
from app.models.user import User

router = APIRouter(prefix="/admin/api", tags=["admin"])


class DictionaryRequestResponse(BaseModel):
    """Dictionary request response model."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    pattern: str
    replacement: str
    status: str
    created_at: datetime


class DictionaryRequestListResponse(BaseModel):
    """Response for listing dictionary requests."""

    entries: list[DictionaryRequestResponse]
    count: int


@router.get("/dictionary-requests", response_model=DictionaryRequestListResponse)
async def list_dictionary_requests(
    _admin: User = Depends(get_current_admin_user),
) -> DictionaryRequestListResponse:
    """List pending dictionary requests."""
    async with async_session_factory() as session:
        entries = await get_pending_requests(session)
        count = await get_pending_request_count(session)

    return DictionaryRequestListResponse(
        entries=[DictionaryRequestResponse.model_validate(entry) for entry in entries],
        count=count,
    )
