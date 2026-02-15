"""Backup scheduler utilities."""

from __future__ import annotations

import asyncio
from datetime import datetime, timedelta
from typing import Awaitable, Callable


def get_next_run_at(current: datetime, run_at_hour: int = 3) -> datetime:
    """Calculate next run time for the daily scheduler."""
    target = current.replace(hour=run_at_hour, minute=0, second=0, microsecond=0)
    if current > target:
        target = target + timedelta(days=1)
    return target


async def _resolve_now(
    now_provider: Callable[[], datetime | Awaitable[datetime]],
) -> datetime:
    current = now_provider()
    if asyncio.iscoroutine(current):
        return await current
    return current


async def run_backup_scheduler(
    stop_event: asyncio.Event,
    run_task: Callable[[], Awaitable[None]],
    run_at_hour: int = 3,
    now_provider: Callable[[], datetime | Awaitable[datetime]] = datetime.now,
) -> None:
    """Run backup task daily at the specified hour until stopped."""
    while not stop_event.is_set():
        now = await _resolve_now(now_provider)
        next_run = get_next_run_at(now, run_at_hour=run_at_hour)
        wait_seconds = max(0.0, (next_run - now).total_seconds())
        try:
            await asyncio.wait_for(stop_event.wait(), timeout=wait_seconds)
            break
        except asyncio.TimeoutError:
            pass

        if stop_event.is_set():
            break

        await run_task()


def start_backup_scheduler(
    stop_event: asyncio.Event,
    run_task: Callable[[], Awaitable[None]],
    run_at_hour: int = 3,
    now_provider: Callable[[], datetime | Awaitable[datetime]] = datetime.now,
    task_factory: Callable[[Awaitable[None]], asyncio.Task[None]] = asyncio.create_task,
) -> asyncio.Task[None]:
    """Start backup scheduler as a background task."""
    return task_factory(
        run_backup_scheduler(
            stop_event=stop_event,
            run_task=run_task,
            run_at_hour=run_at_hour,
            now_provider=now_provider,
        )
    )
