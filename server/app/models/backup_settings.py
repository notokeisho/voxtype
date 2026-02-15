"""Backup settings model and helpers."""

from datetime import datetime

from sqlalchemy import Boolean, DateTime, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class BackupSettings(Base):
    """Backup settings for automatic backups."""

    __tablename__ = "backup_settings"

    id: Mapped[int] = mapped_column(primary_key=True)
    enabled: Mapped[bool] = mapped_column(Boolean, server_default=func.false())
    last_run_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, server_default=func.now(), onupdate=func.now()
    )

    def __repr__(self) -> str:
        return f"<BackupSettings(id={self.id}, enabled={self.enabled})>"


async def get_backup_settings(session: AsyncSession) -> BackupSettings:
    """Get or create backup settings row."""
    result = await session.execute(select(BackupSettings))
    settings = result.scalars().first()
    if settings:
        return settings

    settings = BackupSettings(enabled=False)
    session.add(settings)
    await session.commit()
    await session.refresh(settings)
    return settings
