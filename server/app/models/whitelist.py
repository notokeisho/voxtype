"""Whitelist model and helper functions."""

from datetime import datetime

from sqlalchemy import ForeignKey, String, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class Whitelist(Base):
    """Whitelist model for storing allowed GitHub users."""

    __tablename__ = "whitelist"

    id: Mapped[int] = mapped_column(primary_key=True)
    github_id: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    github_username: Mapped[str | None] = mapped_column(String(100), nullable=True)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())
    created_by: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)

    def __repr__(self) -> str:
        return f"<Whitelist(id={self.id}, github_id={self.github_id}, github_username={self.github_username})>"


async def is_whitelisted(session: AsyncSession, github_id: str) -> bool:
    """Check if a GitHub user is whitelisted.

    Args:
        session: Database session
        github_id: GitHub username to check

    Returns:
        True if user is whitelisted, False otherwise
    """
    result = await session.execute(select(Whitelist).where(Whitelist.github_id == github_id))
    return result.scalar_one_or_none() is not None


async def add_to_whitelist(
    session: AsyncSession,
    github_id: str,
    created_by: int | None = None,
    github_username: str | None = None,
) -> Whitelist:
    """Add a GitHub user to the whitelist.

    Args:
        session: Database session
        github_id: GitHub user ID to add
        created_by: User ID of the admin who added this entry
        github_username: GitHub username for display purposes

    Returns:
        The created Whitelist entry
    """
    entry = Whitelist(
        github_id=github_id,
        created_by=created_by,
        github_username=github_username,
    )
    session.add(entry)
    await session.commit()
    return entry


async def remove_from_whitelist(session: AsyncSession, github_id: str) -> bool:
    """Remove a GitHub user from the whitelist.

    Args:
        session: Database session
        github_id: GitHub username to remove

    Returns:
        True if user was removed, False if user was not in whitelist
    """
    result = await session.execute(select(Whitelist).where(Whitelist.github_id == github_id))
    entry = result.scalar_one_or_none()
    if entry:
        await session.delete(entry)
        await session.commit()
        return True
    return False
