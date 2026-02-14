"""Admin dictionary request management API endpoints."""

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, ConfigDict
from sqlalchemy import select

from app.auth.dependencies import get_current_admin_user
from app.database import async_session_factory
from app.models.global_dictionary import GlobalDictionary
from app.models.global_dictionary_request import (
    REQUEST_STATUS_APPROVED,
    REQUEST_STATUS_PENDING,
    REQUEST_STATUS_REJECTED,
    get_pending_request_count,
    get_pending_requests,
    GlobalDictionaryRequest,
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


@router.post(
    "/dictionary-requests/{request_id}/approve",
    response_model=DictionaryRequestResponse,
)
async def approve_dictionary_request(
    request_id: int,
    admin: User = Depends(get_current_admin_user),
) -> DictionaryRequestResponse:
    """Approve a dictionary request."""
    async with async_session_factory() as session:
        result = await session.execute(
            select(GlobalDictionaryRequest).where(GlobalDictionaryRequest.id == request_id)
        )
        request = result.scalar_one_or_none()

        if request is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Dictionary request not found",
            )

        if request.status != REQUEST_STATUS_PENDING:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Dictionary request is not pending",
            )

        entry = GlobalDictionary(
            pattern=request.pattern,
            replacement=request.replacement,
            created_by=admin.id,
        )
        session.add(entry)

        request.status = REQUEST_STATUS_APPROVED
        request.reviewed_by = admin.id
        request.reviewed_at = datetime.utcnow()

        await session.commit()
        await session.refresh(request)

        return DictionaryRequestResponse.model_validate(request)


@router.post(
    "/dictionary-requests/{request_id}/reject",
    response_model=DictionaryRequestResponse,
)
async def reject_dictionary_request(
    request_id: int,
    admin: User = Depends(get_current_admin_user),
) -> DictionaryRequestResponse:
    """Reject a dictionary request."""
    async with async_session_factory() as session:
        result = await session.execute(
            select(GlobalDictionaryRequest).where(GlobalDictionaryRequest.id == request_id)
        )
        request = result.scalar_one_or_none()

        if request is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Dictionary request not found",
            )

        if request.status != REQUEST_STATUS_PENDING:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Dictionary request is not pending",
            )

        request.status = REQUEST_STATUS_REJECTED
        request.reviewed_by = admin.id
        request.reviewed_at = datetime.utcnow()

        await session.commit()
        await session.refresh(request)

        return DictionaryRequestResponse.model_validate(request)
