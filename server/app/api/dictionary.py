"""User dictionary API endpoints."""

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from app.auth.dependencies import get_current_user
from app.database import get_session
from app.models.user import User
from app.models.user_dictionary import (
    USER_DICTIONARY_LIMIT,
    DictionaryLimitExceeded,
    DictionaryPatternDuplicate,
    add_user_entry,
    delete_user_entry,
    get_user_entries,
    get_user_entry_count,
    get_user_manual_entry_count,
    get_user_rejected_entry_count,
)

router = APIRouter(prefix="/api", tags=["dictionary"])


class DictionaryEntryCreate(BaseModel):
    """Request body for creating a dictionary entry."""

    pattern: str
    replacement: str


class DictionaryEntryResponse(BaseModel):
    """Response for a single dictionary entry."""

    id: int
    pattern: str
    replacement: str


class DictionaryListResponse(BaseModel):
    """Response for listing dictionary entries."""

    entries: list[DictionaryEntryResponse]
    count: int
    manual_count: int
    rejected_count: int
    limit: int


@router.get("/dictionary", response_model=DictionaryListResponse)
async def get_dictionary(
    current_user: User = Depends(get_current_user),
):
    """Get user's dictionary entries.

    Returns:
        List of dictionary entries with count and limit
    """
    async with get_session() as session:
        entries = await get_user_entries(session, current_user.id)
        count = await get_user_entry_count(session, current_user.id)
        manual_count = await get_user_manual_entry_count(session, current_user.id)
        rejected_count = await get_user_rejected_entry_count(session, current_user.id)

    return DictionaryListResponse(
        entries=[
            DictionaryEntryResponse(
                id=entry.id,
                pattern=entry.pattern,
                replacement=entry.replacement,
            )
            for entry in entries
        ],
        count=count,
        manual_count=manual_count,
        rejected_count=rejected_count,
        limit=USER_DICTIONARY_LIMIT,
    )


@router.post("/dictionary", response_model=DictionaryEntryResponse, status_code=status.HTTP_201_CREATED)
async def add_dictionary_entry(
    body: DictionaryEntryCreate,
    current_user: User = Depends(get_current_user),
):
    """Add a new dictionary entry.

    Args:
        body: Dictionary entry data

    Returns:
        Created dictionary entry

    Raises:
        HTTPException: 400 if user has reached the entry limit
    """
    async with get_session() as session:
        try:
            entry = await add_user_entry(
                session,
                current_user.id,
                body.pattern,
                body.replacement,
            )
        except DictionaryPatternDuplicate as e:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Dictionary pattern already exists",
            ) from e
        except DictionaryLimitExceeded as e:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Dictionary limit exceeded: {e}",
            ) from e

    return DictionaryEntryResponse(
        id=entry.id,
        pattern=entry.pattern,
        replacement=entry.replacement,
    )


@router.delete("/dictionary/{entry_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_dictionary_entry(
    entry_id: int,
    current_user: User = Depends(get_current_user),
):
    """Delete a dictionary entry.

    Args:
        entry_id: ID of the entry to delete

    Raises:
        HTTPException: 404 if entry not found or not owned by user
    """
    async with get_session() as session:
        deleted = await delete_user_entry(session, current_user.id, entry_id)

    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Dictionary entry not found",
        )
