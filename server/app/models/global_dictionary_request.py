"""Global Dictionary request model and helper functions."""

from datetime import datetime

from sqlalchemy import ForeignKey, String, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base

REQUEST_STATUS_PENDING = "pending"
REQUEST_STATUS_APPROVED = "approved"
REQUEST_STATUS_REJECTED = "rejected"


class GlobalDictionaryRequest(Base):
    """Request for adding an entry to the global dictionary."""

    __tablename__ = "global_dictionary_requests"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    pattern: Mapped[str] = mapped_column(String(255), index=True)
    replacement: Mapped[str] = mapped_column(String(255))
    status: Mapped[str] = mapped_column(String(20), index=True, default=REQUEST_STATUS_PENDING)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())
    reviewed_at: Mapped[datetime | None] = mapped_column(nullable=True)
    reviewed_by: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)

    def __repr__(self) -> str:
        return (
            f"<GlobalDictionaryRequest(id={self.id}, user_id={self.user_id}, "
            f"pattern={self.pattern}, status={self.status})>"
        )


async def add_request(
    session: AsyncSession,
    user_id: int,
    pattern: str,
    replacement: str,
) -> GlobalDictionaryRequest:
    """Add a dictionary request."""
    request = GlobalDictionaryRequest(
        user_id=user_id,
        pattern=pattern,
        replacement=replacement,
        status=REQUEST_STATUS_PENDING,
    )
    session.add(request)
    await session.commit()
    await session.refresh(request)
    return request


async def get_pending_requests(session: AsyncSession) -> list[GlobalDictionaryRequest]:
    """Get pending dictionary requests."""
    result = await session.execute(
        select(GlobalDictionaryRequest)
        .where(GlobalDictionaryRequest.status == REQUEST_STATUS_PENDING)
        .order_by(GlobalDictionaryRequest.created_at.desc())
    )
    return list(result.scalars().all())


async def get_pending_request_count(session: AsyncSession) -> int:
    """Get count of pending dictionary requests."""
    result = await session.execute(
        select(func.count()).select_from(GlobalDictionaryRequest).where(
            GlobalDictionaryRequest.status == REQUEST_STATUS_PENDING
        )
    )
    return result.scalar() or 0
