"""Admin global dictionary management API endpoints."""

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, ConfigDict
from sqlalchemy import delete, select

from app.auth.dependencies import get_current_admin_user
from app.database import async_session_factory
from app.models.global_dictionary import GlobalDictionary
from app.models.user import User

router = APIRouter(prefix="/admin/api", tags=["admin"])


class DictionaryEntryResponse(BaseModel):
    """Dictionary entry response model."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    pattern: str
    replacement: str
    created_at: datetime
    created_by: int | None


class AddDictionaryEntryRequest(BaseModel):
    """Request model for adding dictionary entry."""

    pattern: str
    replacement: str


@router.get("/dictionary", response_model=list[DictionaryEntryResponse])
async def list_global_dictionary(
    _admin: User = Depends(get_current_admin_user),
) -> list[DictionaryEntryResponse]:
    """List all global dictionary entries.

    Admin only endpoint.
    """
    async with async_session_factory() as session:
        result = await session.execute(
            select(GlobalDictionary).order_by(GlobalDictionary.created_at.desc())
        )
        entries = result.scalars().all()
        return [DictionaryEntryResponse.model_validate(e) for e in entries]


@router.post(
    "/dictionary",
    response_model=DictionaryEntryResponse,
    status_code=status.HTTP_201_CREATED,
)
async def add_global_dictionary_entry(
    request: AddDictionaryEntryRequest,
    admin: User = Depends(get_current_admin_user),
) -> DictionaryEntryResponse:
    """Add a global dictionary entry.

    Admin only endpoint.
    """
    async with async_session_factory() as session:
        # Check if pattern already exists
        result = await session.execute(
            select(GlobalDictionary).where(
                GlobalDictionary.pattern == request.pattern
            )
        )
        existing = result.scalar_one_or_none()

        if existing:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Pattern already exists in global dictionary",
            )

        entry = GlobalDictionary(
            pattern=request.pattern,
            replacement=request.replacement,
            created_by=admin.id,
        )
        session.add(entry)
        await session.commit()
        await session.refresh(entry)

        return DictionaryEntryResponse.model_validate(entry)


@router.delete("/dictionary/{entry_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_global_dictionary_entry(
    entry_id: int,
    _admin: User = Depends(get_current_admin_user),
) -> None:
    """Delete a global dictionary entry.

    Admin only endpoint.
    """
    async with async_session_factory() as session:
        result = await session.execute(
            select(GlobalDictionary).where(GlobalDictionary.id == entry_id)
        )
        entry = result.scalar_one_or_none()

        if entry is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Dictionary entry not found",
            )

        await session.execute(
            delete(GlobalDictionary).where(GlobalDictionary.id == entry_id)
        )
        await session.commit()
