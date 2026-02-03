"""Tests for Whitelist model and functions."""

import pytest
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.config import settings


@pytest.fixture
async def db_session():
    """Create a fresh database session for each test."""
    engine = create_async_engine(settings.database_url)
    async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as session:
        yield session
        await session.rollback()

    await engine.dispose()


@pytest.mark.asyncio
async def test_create_whitelist_entry(db_session: AsyncSession):
    """Test that a whitelist entry can be created."""
    from app.models.whitelist import Whitelist

    entry = Whitelist(github_id="whitelisted_user")
    db_session.add(entry)
    await db_session.flush()

    assert entry.id is not None
    assert entry.github_id == "whitelisted_user"
    assert entry.created_at is not None


@pytest.mark.asyncio
async def test_is_whitelisted(db_session: AsyncSession):
    """Test the is_whitelisted function."""
    from app.models.whitelist import Whitelist, is_whitelisted

    # Clean up first
    await db_session.execute(text("DELETE FROM whitelist WHERE github_id = 'alloweduser'"))
    await db_session.commit()

    # Add user to whitelist
    entry = Whitelist(github_id="alloweduser")
    db_session.add(entry)
    await db_session.commit()

    # Check whitelisted user
    assert await is_whitelisted(db_session, "alloweduser") is True

    # Check non-whitelisted user
    assert await is_whitelisted(db_session, "unknownuser") is False

    # Clean up
    await db_session.execute(text("DELETE FROM whitelist WHERE github_id = 'alloweduser'"))
    await db_session.commit()


@pytest.mark.asyncio
async def test_add_to_whitelist(db_session: AsyncSession):
    """Test the add_to_whitelist function."""
    from app.models.whitelist import add_to_whitelist, is_whitelisted

    # Clean up first
    await db_session.execute(text("DELETE FROM whitelist WHERE github_id = 'newuser'"))
    await db_session.commit()

    # Add user to whitelist
    await add_to_whitelist(db_session, "newuser")

    # Verify user is whitelisted
    assert await is_whitelisted(db_session, "newuser") is True

    # Clean up
    await db_session.execute(text("DELETE FROM whitelist WHERE github_id = 'newuser'"))
    await db_session.commit()


@pytest.mark.asyncio
async def test_remove_from_whitelist(db_session: AsyncSession):
    """Test the remove_from_whitelist function."""
    from app.models.whitelist import add_to_whitelist, is_whitelisted, remove_from_whitelist

    # Clean up first
    await db_session.execute(text("DELETE FROM whitelist WHERE github_id = 'tempuser'"))
    await db_session.commit()

    # Add user to whitelist
    await add_to_whitelist(db_session, "tempuser")
    assert await is_whitelisted(db_session, "tempuser") is True

    # Remove user from whitelist
    await remove_from_whitelist(db_session, "tempuser")
    assert await is_whitelisted(db_session, "tempuser") is False


@pytest.mark.asyncio
async def test_create_whitelist_entry_with_username(db_session: AsyncSession):
    """Test that a whitelist entry can be created with github_username."""
    from app.models.whitelist import Whitelist

    # Clean up first
    await db_session.execute(text("DELETE FROM whitelist WHERE github_id = '12345678'"))
    await db_session.commit()

    entry = Whitelist(github_id="12345678", github_username="testuser")
    db_session.add(entry)
    await db_session.flush()

    assert entry.id is not None
    assert entry.github_id == "12345678"
    assert entry.github_username == "testuser"
    assert entry.created_at is not None

    # Clean up
    await db_session.execute(text("DELETE FROM whitelist WHERE github_id = '12345678'"))
    await db_session.commit()


@pytest.mark.asyncio
async def test_add_to_whitelist_with_username(db_session: AsyncSession):
    """Test the add_to_whitelist function with github_username."""
    from app.models.whitelist import Whitelist, add_to_whitelist

    # Clean up first
    await db_session.execute(text("DELETE FROM whitelist WHERE github_id = '87654321'"))
    await db_session.commit()

    # Add user to whitelist with username
    entry = await add_to_whitelist(db_session, "87654321", github_username="anotherusername")

    assert entry.github_id == "87654321"
    assert entry.github_username == "anotherusername"

    # Clean up
    await db_session.execute(text("DELETE FROM whitelist WHERE github_id = '87654321'"))
    await db_session.commit()
