"""Tests for the dictionary API endpoints."""

import asyncio

from fastapi import status
from fastapi.testclient import TestClient
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.auth.jwt import create_jwt_token
from app.config import settings
from app.main import app
from app.models.user_dictionary import USER_DICTIONARY_LIMIT


def run_async(coro):
    """Run async coroutine in a new event loop."""
    loop = asyncio.new_event_loop()
    try:
        return loop.run_until_complete(coro)
    finally:
        loop.close()


async def _setup_test_user(github_id: str):
    """Set up test user with whitelist."""
    from app.models.user import User
    from app.models.whitelist import add_to_whitelist

    engine = create_async_engine(settings.database_url)
    async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as session:
        # Clean up first
        await session.execute(
            text(
                f"DELETE FROM user_dictionary WHERE user_id IN "
                f"(SELECT id FROM users WHERE github_id = '{github_id}')"
            )
        )
        await session.execute(text(f"DELETE FROM whitelist WHERE github_id = '{github_id}'"))
        await session.execute(text(f"DELETE FROM users WHERE github_id = '{github_id}'"))
        await session.commit()

        # Create user
        user = User(github_id=github_id)
        session.add(user)
        await session.commit()
        await session.refresh(user)

        # Add to whitelist
        await add_to_whitelist(session, github_id)

        user_id = user.id

    await engine.dispose()
    return user_id


async def _cleanup_test_user(github_id: str):
    """Clean up test user."""
    engine = create_async_engine(settings.database_url)
    async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as session:
        await session.execute(
            text(
                f"DELETE FROM user_dictionary WHERE user_id IN "
                f"(SELECT id FROM users WHERE github_id = '{github_id}')"
            )
        )
        await session.execute(text(f"DELETE FROM whitelist WHERE github_id = '{github_id}'"))
        await session.execute(text(f"DELETE FROM users WHERE github_id = '{github_id}'"))
        await session.commit()

    await engine.dispose()


async def _add_user_dictionary_entry(user_id: int, pattern: str, replacement: str) -> int:
    """Add a dictionary entry and return its ID."""
    from app.models.user_dictionary import add_user_entry

    engine = create_async_engine(settings.database_url)
    async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as session:
        entry = await add_user_entry(session, user_id, pattern, replacement)
        entry_id = entry.id

    await engine.dispose()
    return entry_id


def setup_test_user(github_id: str) -> int:
    """Sync wrapper."""
    return run_async(_setup_test_user(github_id))


def cleanup_test_user(github_id: str):
    """Sync wrapper."""
    run_async(_cleanup_test_user(github_id))


def add_user_dictionary_entry(user_id: int, pattern: str, replacement: str) -> int:
    """Sync wrapper."""
    return run_async(_add_user_dictionary_entry(user_id, pattern, replacement))


class TestDictionaryEndpointAuthentication:
    """Tests for dictionary endpoint authentication."""

    def test_get_dictionary_without_token_returns_401(self):
        """Test that GET /api/dictionary without token returns 401."""
        client = TestClient(app)

        response = client.get("/api/dictionary")

        assert response.status_code == status.HTTP_401_UNAUTHORIZED

    def test_post_dictionary_without_token_returns_401(self):
        """Test that POST /api/dictionary without token returns 401."""
        client = TestClient(app)

        response = client.post(
            "/api/dictionary",
            json={"pattern": "test", "replacement": "TEST"},
        )

        assert response.status_code == status.HTTP_401_UNAUTHORIZED

    def test_delete_dictionary_without_token_returns_401(self):
        """Test that DELETE /api/dictionary/{id} without token returns 401."""
        client = TestClient(app)

        response = client.delete("/api/dictionary/1")

        assert response.status_code == status.HTTP_401_UNAUTHORIZED


class TestGetDictionary:
    """Tests for GET /api/dictionary."""

    def test_get_empty_dictionary(self):
        """Test getting dictionary when user has no entries."""
        github_id = "dict_get_test_1"
        client = TestClient(app)

        try:
            user_id = setup_test_user(github_id)
            token = create_jwt_token(user_id=user_id, github_id=github_id)

            response = client.get(
                "/api/dictionary",
                headers={"Authorization": f"Bearer {token}"},
            )

            assert response.status_code == status.HTTP_200_OK
            data = response.json()
            assert "entries" in data
            assert "count" in data
            assert "limit" in data
            assert data["entries"] == []
            assert data["count"] == 0
            assert data["limit"] == USER_DICTIONARY_LIMIT
        finally:
            cleanup_test_user(github_id)

    def test_get_dictionary_with_entries(self):
        """Test getting dictionary with existing entries."""
        github_id = "dict_get_test_2"
        client = TestClient(app)

        try:
            user_id = setup_test_user(github_id)
            token = create_jwt_token(user_id=user_id, github_id=github_id)

            # Add some entries
            add_user_dictionary_entry(user_id, "くろーど", "Claude")
            add_user_dictionary_entry(user_id, "AI", "人工知能")

            response = client.get(
                "/api/dictionary",
                headers={"Authorization": f"Bearer {token}"},
            )

            assert response.status_code == status.HTTP_200_OK
            data = response.json()
            assert data["count"] == 2
            assert len(data["entries"]) == 2

            # Check entry structure
            entry = data["entries"][0]
            assert "id" in entry
            assert "pattern" in entry
            assert "replacement" in entry
        finally:
            cleanup_test_user(github_id)


class TestAddDictionary:
    """Tests for POST /api/dictionary."""

    def test_add_dictionary_entry(self):
        """Test adding a dictionary entry."""
        github_id = "dict_add_test_1"
        client = TestClient(app)

        try:
            user_id = setup_test_user(github_id)
            token = create_jwt_token(user_id=user_id, github_id=github_id)

            response = client.post(
                "/api/dictionary",
                headers={"Authorization": f"Bearer {token}"},
                json={"pattern": "いしだけん", "replacement": "石田研"},
            )

            assert response.status_code == status.HTTP_201_CREATED
            data = response.json()
            assert "id" in data
            assert data["pattern"] == "いしだけん"
            assert data["replacement"] == "石田研"
        finally:
            cleanup_test_user(github_id)

    def test_add_dictionary_entry_invalid_request(self):
        """Test adding entry with invalid request body."""
        github_id = "dict_add_test_2"
        client = TestClient(app)

        try:
            user_id = setup_test_user(github_id)
            token = create_jwt_token(user_id=user_id, github_id=github_id)

            # Missing replacement field
            response = client.post(
                "/api/dictionary",
                headers={"Authorization": f"Bearer {token}"},
                json={"pattern": "test"},
            )

            assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY
        finally:
            cleanup_test_user(github_id)

    def test_add_dictionary_entry_limit_exceeded(self):
        """Test adding entry when limit is reached."""
        github_id = "dict_add_test_3"
        client = TestClient(app)

        try:
            user_id = setup_test_user(github_id)
            token = create_jwt_token(user_id=user_id, github_id=github_id)

            # Add entries up to the limit
            for i in range(USER_DICTIONARY_LIMIT):
                add_user_dictionary_entry(user_id, f"pattern{i}", f"replacement{i}")

            # Try to add one more
            response = client.post(
                "/api/dictionary",
                headers={"Authorization": f"Bearer {token}"},
                json={"pattern": "extra", "replacement": "EXTRA"},
            )

            assert response.status_code == status.HTTP_400_BAD_REQUEST
            assert "limit" in response.json()["detail"].lower()
        finally:
            cleanup_test_user(github_id)


class TestDeleteDictionary:
    """Tests for DELETE /api/dictionary/{id}."""

    def test_delete_own_entry(self):
        """Test deleting user's own entry."""
        github_id = "dict_del_test_1"
        client = TestClient(app)

        try:
            user_id = setup_test_user(github_id)
            token = create_jwt_token(user_id=user_id, github_id=github_id)

            # Add an entry
            entry_id = add_user_dictionary_entry(user_id, "test", "TEST")

            # Delete it
            response = client.delete(
                f"/api/dictionary/{entry_id}",
                headers={"Authorization": f"Bearer {token}"},
            )

            assert response.status_code == status.HTTP_204_NO_CONTENT

            # Verify it's gone
            get_response = client.get(
                "/api/dictionary",
                headers={"Authorization": f"Bearer {token}"},
            )
            assert get_response.json()["count"] == 0
        finally:
            cleanup_test_user(github_id)

    def test_delete_nonexistent_entry(self):
        """Test deleting an entry that doesn't exist."""
        github_id = "dict_del_test_2"
        client = TestClient(app)

        try:
            user_id = setup_test_user(github_id)
            token = create_jwt_token(user_id=user_id, github_id=github_id)

            response = client.delete(
                "/api/dictionary/99999",
                headers={"Authorization": f"Bearer {token}"},
            )

            assert response.status_code == status.HTTP_404_NOT_FOUND
        finally:
            cleanup_test_user(github_id)

    def test_delete_other_user_entry(self):
        """Test that user cannot delete another user's entry."""
        github_id_1 = "dict_del_test_3a"
        github_id_2 = "dict_del_test_3b"
        client = TestClient(app)

        try:
            # Set up two users
            user_id_1 = setup_test_user(github_id_1)
            user_id_2 = setup_test_user(github_id_2)

            # User 1 adds an entry
            entry_id = add_user_dictionary_entry(user_id_1, "secret", "SECRET")

            # User 2 tries to delete it
            token_2 = create_jwt_token(user_id=user_id_2, github_id=github_id_2)

            response = client.delete(
                f"/api/dictionary/{entry_id}",
                headers={"Authorization": f"Bearer {token_2}"},
            )

            # Should return 404 (not found for this user)
            assert response.status_code == status.HTTP_404_NOT_FOUND

            # Verify user 1's entry still exists
            token_1 = create_jwt_token(user_id=user_id_1, github_id=github_id_1)
            get_response = client.get(
                "/api/dictionary",
                headers={"Authorization": f"Bearer {token_1}"},
            )
            assert get_response.json()["count"] == 1
        finally:
            cleanup_test_user(github_id_1)
            cleanup_test_user(github_id_2)
