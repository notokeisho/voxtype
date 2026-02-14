"""Dictionary request API endpoints."""

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select

from app.auth.dependencies import get_current_user
from app.database import get_session
from app.models.global_dictionary import GlobalDictionary
from app.models.global_dictionary_request import (
    REQUEST_STATUS_PENDING,
    REQUEST_STATUS_REJECTED,
    GlobalDictionaryRequest,
    add_request,
    get_pending_request_count_for_user,
    get_request_count_for_user,
)
from app.models.user import User
from app.services.dictionary_normalize import normalize_dictionary_text

router = APIRouter(prefix="/api", tags=["dictionary-requests"])


class DictionaryRequestCreate(BaseModel):
    """Request body for creating a dictionary request."""

    pattern: str
    replacement: str


class DictionaryRequestResponse(BaseModel):
    """Response for a dictionary request."""

    id: int
    pattern: str
    replacement: str
    status: str
    remaining: int | None = None


@router.post(
    "/dictionary-requests",
    response_model=DictionaryRequestResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_dictionary_request(
    body: DictionaryRequestCreate,
    current_user: User = Depends(get_current_user),
):
    """Create a dictionary request."""
    async with get_session() as session:
        pending_count = await get_pending_request_count_for_user(session, current_user.id)
        rejected_count = await get_request_count_for_user(
            session,
            current_user.id,
            REQUEST_STATUS_REJECTED,
        )

        remaining = 200 - pending_count - rejected_count
        if remaining <= 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Dictionary request limit reached",
            )

        normalized_pattern = normalize_dictionary_text(body.pattern)
        normalized_replacement = normalize_dictionary_text(body.replacement)

        result = await session.execute(select(GlobalDictionary))
        for entry in result.scalars().all():
            if (
                normalize_dictionary_text(entry.pattern) == normalized_pattern
                and normalize_dictionary_text(entry.replacement) == normalized_replacement
            ):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Pattern already exists in global dictionary",
                )

        result = await session.execute(
            select(GlobalDictionaryRequest).where(
                GlobalDictionaryRequest.status == REQUEST_STATUS_PENDING
            )
        )
        for request in result.scalars().all():
            if (
                normalize_dictionary_text(request.pattern) == normalized_pattern
                and normalize_dictionary_text(request.replacement) == normalized_replacement
            ):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Dictionary request already exists",
                )

        request = await add_request(
            session=session,
            user_id=current_user.id,
            pattern=body.pattern,
            replacement=body.replacement,
        )

    return DictionaryRequestResponse(
        id=request.id,
        pattern=request.pattern,
        replacement=request.replacement,
        status=request.status,
        remaining=remaining - 1,
    )
