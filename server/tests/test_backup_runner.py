"""Tests for backup runner."""

from __future__ import annotations

import asyncio
from datetime import date, datetime
from pathlib import Path

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.config import settings
from app.models.backup_settings import get_backup_settings
from app.models.global_dictionary import GlobalDictionary
from app.services.backup import run_backup_if_enabled


def run_async(coro):
    """Run async coroutine in a new event loop."""
    loop = asyncio.new_event_loop()
    try:
        return loop.run_until_complete(coro)
    finally:
        loop.close()


async def _with_session(callback):
    engine = create_async_engine(settings.database_url)
    async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    try:
        async with async_session() as session:
            return await callback(session)
    finally:
        await engine.dispose()


async def _cleanup_entries(prefix: str) -> None:
    async def _cleanup(session: AsyncSession) -> None:
        await session.execute(
            text("DELETE FROM global_dictionary WHERE pattern LIKE :prefix"),
            {"prefix": f"{prefix}%"},
        )
        await session.execute(text("DELETE FROM backup_settings"))
        await session.commit()

    await _with_session(_cleanup)


async def _insert_entry(prefix: str) -> None:
    async def _insert(session: AsyncSession) -> None:
        session.add(
            GlobalDictionary(
                pattern=f"{prefix}one",
                replacement="ONE",
                created_by=None,
            )
        )
        await session.commit()

    await _with_session(_insert)


async def _set_enabled(enabled: bool) -> None:
    async def _update(session: AsyncSession) -> None:
        settings_row = await get_backup_settings(session)
        settings_row.enabled = enabled
        await session.commit()

    await _with_session(_update)


async def _run_backup(tmp_path: Path, target_date: date):
    async def _run(session: AsyncSession):
        return await run_backup_if_enabled(
            session,
            base_dir=tmp_path,
            current_date=target_date,
            now_provider=lambda: datetime(2026, 2, 15, 0, 0, 0),
        )

    return await _with_session(_run)


def test_backup_runner_skips_when_disabled(tmp_path: Path):
    prefix = "backup_runner_disabled_"
    try:
        run_async(_cleanup_entries(prefix))
        run_async(_insert_entry(prefix))
        run_async(_set_enabled(False))

        result = run_async(_run_backup(tmp_path, date(2026, 2, 15)))

        assert result is None
        assert list(tmp_path.glob("*.xlsx")) == []
    finally:
        run_async(_cleanup_entries(prefix))


def test_backup_runner_runs_when_enabled(tmp_path: Path):
    prefix = "backup_runner_enabled_"
    try:
        run_async(_cleanup_entries(prefix))
        run_async(_insert_entry(prefix))
        run_async(_set_enabled(True))

        result = run_async(_run_backup(tmp_path, date(2026, 2, 15)))

        assert result is not None
        assert result.created_file.exists()
    finally:
        run_async(_cleanup_entries(prefix))
