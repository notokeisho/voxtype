"""Tests for database models."""

import pytest
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
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
async def test_create_user(db_session: AsyncSession):
    """Test that a user can be created and persisted."""
    from app.models.user import User

    user = User(
        github_id="testuser_create",
        github_avatar="https://avatars.githubusercontent.com/u/12345",
    )
    db_session.add(user)
    await db_session.flush()

    assert user.id is not None
    assert user.github_id == "testuser_create"
    assert user.is_admin is False
    assert user.created_at is not None


@pytest.mark.asyncio
async def test_user_unique_github_id(db_session: AsyncSession):
    """Test that github_id must be unique."""
    from app.models.user import User

    # Clean up any existing test users first
    await db_session.execute(text("DELETE FROM users WHERE github_id = 'uniqueuser_test'"))
    await db_session.commit()

    user1 = User(github_id="uniqueuser_test")
    db_session.add(user1)
    await db_session.commit()

    # Create a new session to test unique constraint
    engine = create_async_engine(settings.database_url)
    async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as session2:
        user2 = User(github_id="uniqueuser_test")
        session2.add(user2)

        with pytest.raises(IntegrityError):
            await session2.commit()

    await engine.dispose()

    # Clean up
    await db_session.execute(text("DELETE FROM users WHERE github_id = 'uniqueuser_test'"))
    await db_session.commit()
