"""Tests for backup scheduler."""

from __future__ import annotations

import asyncio
from datetime import datetime

import pytest

from app.services.backup_scheduler import (
    get_next_run_at,
    run_backup_scheduler,
    start_backup_scheduler,
)


def test_get_next_run_at_before_target():
    now = datetime(2026, 2, 15, 2, 59, 0)
    next_run = get_next_run_at(now, run_at_hour=3)

    assert next_run == datetime(2026, 2, 15, 3, 0, 0)


def test_get_next_run_at_after_target():
    now = datetime(2026, 2, 15, 3, 1, 0)
    next_run = get_next_run_at(now, run_at_hour=3)

    assert next_run == datetime(2026, 2, 16, 3, 0, 0)


def test_get_next_run_at_exact_target():
    now = datetime(2026, 2, 15, 3, 0, 0)
    next_run = get_next_run_at(now, run_at_hour=3)

    assert next_run == datetime(2026, 2, 15, 3, 0, 0)


@pytest.mark.asyncio
async def test_run_backup_scheduler_runs_task_once():
    stop_event = asyncio.Event()
    ran = 0

    async def run_task():
        nonlocal ran
        ran += 1
        stop_event.set()

    async def now_provider():
        return datetime(2026, 2, 15, 3, 0, 0)

    await asyncio.wait_for(
        run_backup_scheduler(
            stop_event=stop_event,
            run_task=run_task,
            run_at_hour=3,
            now_provider=now_provider,
        ),
        timeout=1,
    )

    assert ran == 1


@pytest.mark.asyncio
async def test_start_backup_scheduler_creates_task():
    stop_event = asyncio.Event()
    ran = 0

    async def run_task():
        nonlocal ran
        ran += 1
        stop_event.set()

    async def now_provider():
        return datetime(2026, 2, 15, 3, 0, 0)

    task = start_backup_scheduler(
        stop_event=stop_event,
        run_task=run_task,
        run_at_hour=3,
        now_provider=now_provider,
        task_factory=asyncio.create_task,
    )
    await asyncio.wait_for(task, timeout=1)

    assert ran == 1
