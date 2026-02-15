"""Backup generation utilities."""

from __future__ import annotations

import asyncio
from dataclasses import dataclass
from datetime import date, datetime
from pathlib import Path
from typing import Awaitable, Callable, TypeVar

from openpyxl import Workbook

from app.models.backup_settings import get_backup_settings
from app.models.global_dictionary import get_global_entries

T = TypeVar("T")
_backup_lock = asyncio.Lock()


@dataclass(slots=True)
class BackupResult:
    """Result of backup creation."""

    created_file: Path
    created_at: datetime
    kept: int
    deleted: int


async def run_with_backup_lock(job: Callable[[], Awaitable[T]]) -> T:
    """Run backup related job with process-local lock."""
    async with _backup_lock:
        return await job()


async def run_backup_if_enabled(
    session,
    base_dir: Path | None = None,
    current_date: date | None = None,
    now_provider: Callable[[], datetime] = datetime.now,
) -> BackupResult | None:
    """Run backup only when enabled settings are true."""
    settings = await get_backup_settings(session)
    if not settings.enabled:
        return None

    async def _run() -> BackupResult:
        return await create_global_dictionary_backup(
            session,
            base_dir=base_dir,
            current_date=current_date,
            now_provider=now_provider,
        )

    return await run_with_backup_lock(_run)


def _parse_backup_datetime(filename: str) -> datetime | None:
    prefix = "global_dictionary_"
    suffix = ".xlsx"
    if not filename.startswith(prefix) or not filename.endswith(suffix):
        return None
    core_part = filename[len(prefix):-len(suffix)]
    try:
        return datetime.strptime(core_part, "%Y-%m-%d_%H-%M-%S")
    except ValueError:
        try:
            return datetime.strptime(core_part, "%Y-%m-%d")
        except ValueError:
            return None


def _list_backup_files(backup_dir: Path) -> list[Path]:
    return [path for path in backup_dir.iterdir() if _parse_backup_datetime(path.name)]


async def create_global_dictionary_backup(
    session,
    base_dir: Path | None = None,
    current_date: date | None = None,
    now_provider: Callable[[], datetime] = datetime.now,
) -> BackupResult:
    """Create a global dictionary backup and keep latest files only."""
    backup_dir = base_dir or Path("./data/backups")
    backup_dir.mkdir(parents=True, exist_ok=True)

    export_date = current_date or date.today()
    filename = f"global_dictionary_{export_date.isoformat()}_{now_provider().strftime('%H-%M-%S')}.xlsx"
    backup_path = backup_dir / filename

    entries = await get_global_entries(session)

    workbook = Workbook()
    sheet = workbook.active
    sheet.title = "global_dictionary"
    sheet.append(["pattern", "replacement", "created_at", "created_by"])
    for entry in entries:
        created_at = entry.created_at.isoformat() if entry.created_at else ""
        sheet.append([entry.pattern, entry.replacement, created_at, entry.created_by])

    workbook.save(backup_path)

    backups = _list_backup_files(backup_dir)
    backups.sort(
        key=lambda path: _parse_backup_datetime(path.name) or datetime.min,
        reverse=True,
    )
    keep = backups[:3]
    to_delete = backups[3:]

    deleted = 0
    for path in to_delete:
        path.unlink(missing_ok=True)
        deleted += 1

    settings = await get_backup_settings(session)
    settings.last_run_at = now_provider()
    await session.commit()

    return BackupResult(
        created_file=backup_path,
        created_at=settings.last_run_at,
        kept=len(keep),
        deleted=deleted,
    )
