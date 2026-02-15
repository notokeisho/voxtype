"""Backup generation utilities."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime
from pathlib import Path

from openpyxl import Workbook

from app.models.global_dictionary import get_global_entries


@dataclass(slots=True)
class BackupResult:
    """Result of backup creation."""

    created_file: Path
    created_at: datetime
    kept: int
    deleted: int


def _parse_backup_date(filename: str) -> date | None:
    prefix = "global_dictionary_"
    suffix = ".xlsx"
    if not filename.startswith(prefix) or not filename.endswith(suffix):
        return None
    date_part = filename[len(prefix):-len(suffix)]
    try:
        return date.fromisoformat(date_part)
    except ValueError:
        return None


def _list_backup_files(backup_dir: Path) -> list[Path]:
    return [path for path in backup_dir.iterdir() if _parse_backup_date(path.name)]


async def create_global_dictionary_backup(
    session,
    base_dir: Path | None = None,
    current_date: date | None = None,
) -> BackupResult:
    """Create a global dictionary backup and keep latest files only."""
    backup_dir = base_dir or Path("./data/backups")
    backup_dir.mkdir(parents=True, exist_ok=True)

    export_date = current_date or date.today()
    filename = f"global_dictionary_{export_date.isoformat()}.xlsx"
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
    backups.sort(key=lambda path: _parse_backup_date(path.name) or date.min, reverse=True)
    keep = backups[:3]
    to_delete = backups[3:]

    deleted = 0
    for path in to_delete:
        path.unlink(missing_ok=True)
        deleted += 1

    return BackupResult(
        created_file=backup_path,
        created_at=datetime.now(),
        kept=len(keep),
        deleted=deleted,
    )
