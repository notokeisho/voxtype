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
from app.models.user_dictionary import DictionaryLimitExceeded, add_user_entry, get_user_entry_by_pattern
from app.services.dictionary_normalize import (
    normalize_dictionary_text,
    normalize_dictionary_text_case_sensitive,
)

router = APIRouter(prefix="/admin/api", tags=["admin"])


class DictionaryRequestResponse(BaseModel):
    """Dictionary request response model."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    user_name: str | None = None
    user_github_id: str | None = None
    pattern: str
    replacement: str
    status: str
    created_at: datetime
    conflict_entry_id: int | None = None
    conflict_replacement: str | None = None


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
        result = await session.execute(select(GlobalDictionary))
        global_entries = result.scalars().all()
        user_ids = {entry.user_id for entry in entries}
        user_map: dict[int, User] = {}
        if user_ids:
            users_result = await session.execute(select(User).where(User.id.in_(user_ids)))
            user_map = {user.id: user for user in users_result.scalars().all()}

        normalized_globals: dict[str, GlobalDictionary] = {}
        for entry in global_entries:
            normalized_globals[normalize_dictionary_text(entry.pattern)] = entry

    return DictionaryRequestListResponse(
        entries=[
            _build_request_response(entry, normalized_globals, user_map.get(entry.user_id))
            for entry in entries
        ],
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

        result = await session.execute(select(GlobalDictionary))
        global_entries = result.scalars().all()
        normalized_pattern = normalize_dictionary_text(request.pattern)
        normalized_replacement = normalize_dictionary_text_case_sensitive(request.replacement)

        conflict_entry = None
        for entry in global_entries:
            if normalize_dictionary_text(entry.pattern) == normalized_pattern:
                conflict_entry = entry
                break

        if conflict_entry is not None:
            if normalize_dictionary_text_case_sensitive(conflict_entry.replacement) != normalized_replacement:
                await session.delete(conflict_entry)
            else:
                conflict_entry = None

        if conflict_entry is None:
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


def _build_conflict_info(
    request: GlobalDictionaryRequest,
    normalized_globals: dict[str, GlobalDictionary],
) -> dict[str, int | str | None]:
    normalized_pattern = normalize_dictionary_text(request.pattern)
    entry = normalized_globals.get(normalized_pattern)
    if entry is None:
        return {"conflict_entry_id": None, "conflict_replacement": None}

    if normalize_dictionary_text_case_sensitive(entry.replacement) == normalize_dictionary_text_case_sensitive(
        request.replacement
    ):
        return {"conflict_entry_id": None, "conflict_replacement": None}

    return {"conflict_entry_id": entry.id, "conflict_replacement": entry.replacement}


def _build_request_response(
    request: GlobalDictionaryRequest,
    normalized_globals: dict[str, GlobalDictionary],
    user: User | None,
) -> DictionaryRequestResponse:
    data = DictionaryRequestResponse.model_validate(request).model_dump()
    data.update(_build_conflict_info(request, normalized_globals))
    if user:
        data["user_name"] = user.github_username
        data["user_github_id"] = user.github_id
    return DictionaryRequestResponse(**data)


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

        existing_entry = await get_user_entry_by_pattern(
            session,
            request.user_id,
            request.pattern,
        )
        if existing_entry is None:
            try:
                await add_user_entry(
                    session=session,
                    user_id=request.user_id,
                    pattern=request.pattern,
                    replacement=request.replacement,
                    is_rejected=True,
                )
            except DictionaryLimitExceeded as error:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=str(error),
                ) from error

        request.status = REQUEST_STATUS_REJECTED
        request.reviewed_by = admin.id
        request.reviewed_at = datetime.utcnow()

        await session.commit()
        await session.refresh(request)

        return DictionaryRequestResponse.model_validate(request)


@router.delete("/dictionary-requests/{request_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_dictionary_request(
    request_id: int,
    _admin: User = Depends(get_current_admin_user),
) -> None:
    """Delete a pending dictionary request."""
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

        await session.delete(request)
        await session.commit()
