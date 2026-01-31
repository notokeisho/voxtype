"""Admin whitelist management API endpoints."""

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, ConfigDict
from sqlalchemy import delete, select

from app.auth.dependencies import get_current_admin_user
from app.database import async_session_factory
from app.models.user import User
from app.models.whitelist import Whitelist

router = APIRouter(prefix="/admin/api", tags=["admin"])


class WhitelistEntryResponse(BaseModel):
    """Whitelist entry response model."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    github_id: str
    created_at: datetime
    created_by: int | None


class AddWhitelistRequest(BaseModel):
    """Request model for adding to whitelist."""

    github_id: str


@router.get("/whitelist", response_model=list[WhitelistEntryResponse])
async def list_whitelist(
    _admin: User = Depends(get_current_admin_user),
) -> list[WhitelistEntryResponse]:
    """List all whitelist entries.

    Admin only endpoint.
    """
    async with async_session_factory() as session:
        result = await session.execute(
            select(Whitelist).order_by(Whitelist.created_at.desc())
        )
        entries = result.scalars().all()
        return [WhitelistEntryResponse.model_validate(e) for e in entries]


@router.post(
    "/whitelist",
    response_model=WhitelistEntryResponse,
    status_code=status.HTTP_201_CREATED,
)
async def add_to_whitelist(
    request: AddWhitelistRequest,
    admin: User = Depends(get_current_admin_user),
) -> WhitelistEntryResponse:
    """Add a user to whitelist.

    Admin only endpoint.
    """
    async with async_session_factory() as session:
        # Check if already exists
        result = await session.execute(
            select(Whitelist).where(Whitelist.github_id == request.github_id)
        )
        existing = result.scalar_one_or_none()

        if existing:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="User already in whitelist",
            )

        entry = Whitelist(
            github_id=request.github_id,
            created_by=admin.id,
        )
        session.add(entry)
        await session.commit()
        await session.refresh(entry)

        return WhitelistEntryResponse.model_validate(entry)


@router.delete("/whitelist/{entry_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_from_whitelist(
    entry_id: int,
    _admin: User = Depends(get_current_admin_user),
) -> None:
    """Remove a user from whitelist.

    Admin only endpoint.
    """
    async with async_session_factory() as session:
        result = await session.execute(
            select(Whitelist).where(Whitelist.id == entry_id)
        )
        entry = result.scalar_one_or_none()

        if entry is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Whitelist entry not found",
            )

        await session.execute(delete(Whitelist).where(Whitelist.id == entry_id))
        await session.commit()
