"""Admin whitelist management API endpoints."""

from datetime import datetime

import httpx
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
    github_username: str | None
    created_at: datetime
    created_by: int | None


class AddWhitelistRequest(BaseModel):
    """Request model for adding to whitelist."""

    github_id: str
    github_username: str | None = None


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
            github_username=request.github_username,
            created_by=admin.id,
        )
        session.add(entry)
        await session.commit()
        await session.refresh(entry)

        return WhitelistEntryResponse.model_validate(entry)


@router.delete("/whitelist/{entry_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_from_whitelist(
    entry_id: int,
    admin: User = Depends(get_current_admin_user),
) -> None:
    """Remove a user from whitelist.

    Admin only endpoint.
    Cannot remove yourself from whitelist.
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

        # Prevent removing yourself from whitelist
        if entry.github_id == admin.github_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot remove yourself from whitelist",
            )

        await session.execute(delete(Whitelist).where(Whitelist.id == entry_id))
        await session.commit()


class GitHubUserResponse(BaseModel):
    """GitHub user information response model."""

    id: str
    login: str
    avatar_url: str
    html_url: str


@router.get("/github/user/{username}", response_model=GitHubUserResponse)
async def search_github_user(
    username: str,
    _admin: User = Depends(get_current_admin_user),
) -> GitHubUserResponse:
    """Search GitHub user by username.

    Uses unauthenticated GitHub API (60 requests/hour limit).
    Admin only endpoint.
    """
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"https://api.github.com/users/{username}",
            headers={"Accept": "application/vnd.github.v3+json"},
            timeout=10.0,
        )

        if resp.status_code == 404:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="GitHub user not found",
            )
        if resp.status_code == 403:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="GitHub API rate limit exceeded",
            )
        if resp.status_code != 200:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="GitHub API error",
            )

        user = resp.json()
        return GitHubUserResponse(
            id=str(user["id"]),
            login=user["login"],
            avatar_url=user["avatar_url"],
            html_url=user["html_url"],
        )


class WhitelistCheckResponse(BaseModel):
    """Whitelist check response model."""

    exists: bool


@router.get("/whitelist/check/{github_id}", response_model=WhitelistCheckResponse)
async def check_whitelist(
    github_id: str,
    _admin: User = Depends(get_current_admin_user),
) -> WhitelistCheckResponse:
    """Check if a GitHub ID is already in the whitelist.

    Admin only endpoint.
    """
    async with async_session_factory() as session:
        result = await session.execute(
            select(Whitelist).where(Whitelist.github_id == github_id)
        )
        entry = result.scalar_one_or_none()
        return WhitelistCheckResponse(exists=entry is not None)
