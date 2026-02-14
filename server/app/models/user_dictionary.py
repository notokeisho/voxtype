"""User Dictionary model and helper functions."""

from datetime import datetime

from sqlalchemy import Boolean, ForeignKey, String, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base

# Maximum number of entries per user
USER_DICTIONARY_LIMIT = 100
USER_DICTIONARY_REJECTED_LIMIT = 200


class DictionaryLimitExceeded(Exception):
    """Raised when user dictionary limit is exceeded."""

    pass


class UserDictionary(Base):
    """User-specific dictionary for text replacement."""

    __tablename__ = "user_dictionary"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    pattern: Mapped[str] = mapped_column(String(255))
    replacement: Mapped[str] = mapped_column(String(255))
    is_rejected: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())

    def __repr__(self) -> str:
        return f"<UserDictionary(id={self.id}, user_id={self.user_id}, pattern={self.pattern})>"


async def get_user_entries(session: AsyncSession, user_id: int) -> list[UserDictionary]:
    """Get all dictionary entries for a user.

    Args:
        session: Database session
        user_id: User ID

    Returns:
        List of user's dictionary entries
    """
    result = await session.execute(select(UserDictionary).where(UserDictionary.user_id == user_id))
    return list(result.scalars().all())


async def get_user_entry_count(session: AsyncSession, user_id: int) -> int:
    """Get the count of dictionary entries for a user.

    Args:
        session: Database session
        user_id: User ID

    Returns:
        Number of entries for the user
    """
    result = await session.execute(
        select(func.count()).select_from(UserDictionary).where(UserDictionary.user_id == user_id)
    )
    return result.scalar() or 0


async def get_user_manual_entry_count(session: AsyncSession, user_id: int) -> int:
    """Get the count of manual dictionary entries for a user."""
    result = await session.execute(
        select(func.count()).select_from(UserDictionary).where(
            UserDictionary.user_id == user_id,
            UserDictionary.is_rejected.is_(False),
        )
    )
    return result.scalar() or 0


async def get_user_rejected_entry_count(session: AsyncSession, user_id: int) -> int:
    """Get the count of rejected dictionary entries for a user."""
    result = await session.execute(
        select(func.count()).select_from(UserDictionary).where(
            UserDictionary.user_id == user_id,
            UserDictionary.is_rejected.is_(True),
        )
    )
    return result.scalar() or 0


async def add_user_entry(
    session: AsyncSession,
    user_id: int,
    pattern: str,
    replacement: str,
    is_rejected: bool = False,
) -> UserDictionary:
    """Add a user dictionary entry.

    Args:
        session: Database session
        user_id: User ID
        pattern: Pattern to match
        replacement: Replacement text

    Returns:
        The created UserDictionary entry

    Raises:
        DictionaryLimitExceeded: If user has reached the maximum number of entries
    """
    if not is_rejected:
        count = await get_user_entry_count(session, user_id)
        if count >= USER_DICTIONARY_LIMIT:
            raise DictionaryLimitExceeded(
                f"User dictionary limit of {USER_DICTIONARY_LIMIT} entries exceeded"
            )

    if is_rejected:
        rejected_count = await get_user_rejected_entry_count(session, user_id)
        if rejected_count >= USER_DICTIONARY_REJECTED_LIMIT:
            raise DictionaryLimitExceeded(
                f"User rejected dictionary limit of {USER_DICTIONARY_REJECTED_LIMIT} entries exceeded"
            )

    entry = UserDictionary(
        user_id=user_id,
        pattern=pattern,
        replacement=replacement,
        is_rejected=is_rejected,
    )
    session.add(entry)
    await session.commit()
    return entry


async def delete_user_entry(session: AsyncSession, user_id: int, entry_id: int) -> bool:
    """Delete a user dictionary entry.

    Args:
        session: Database session
        user_id: User ID (for ownership verification)
        entry_id: ID of the entry to delete

    Returns:
        True if entry was deleted, False if entry was not found or not owned by user
    """
    result = await session.execute(
        select(UserDictionary).where(
            UserDictionary.id == entry_id,
            UserDictionary.user_id == user_id,
        )
    )
    entry = result.scalar_one_or_none()
    if entry:
        await session.delete(entry)
        await session.commit()
        return True
    return False
