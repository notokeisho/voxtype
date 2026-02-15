"""Tests for backup execution lock."""

import asyncio

from app.services.backup import run_with_backup_lock


def test_backup_lock_serializes_runs():
    max_running = 0
    running = 0

    async def job():
        nonlocal running
        nonlocal max_running
        running += 1
        max_running = max(max_running, running)
        await asyncio.sleep(0.05)
        running -= 1

    async def run_two_jobs():
        await asyncio.gather(run_with_backup_lock(job), run_with_backup_lock(job))

    asyncio.run(run_two_jobs())
    assert max_running == 1

