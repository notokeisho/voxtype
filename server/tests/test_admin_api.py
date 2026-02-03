"""Tests for admin API endpoints."""

import pytest
from httpx import AsyncClient, ASGITransport
from sqlalchemy import delete

from app.auth.jwt import create_jwt_token
from app.database import async_session_factory
from app.main import app
from app.models.user import User
from app.models.whitelist import Whitelist
from app.models.global_dictionary import GlobalDictionary


@pytest.fixture
async def test_user():
    """Create a test user."""
    async with async_session_factory() as session:
        user = User(
            github_id="testuser",
            github_avatar="https://example.com/avatar.png",
            is_admin=False,
        )
        session.add(user)
        await session.commit()
        await session.refresh(user)

        # Add to whitelist
        whitelist_entry = Whitelist(github_id="testuser")
        session.add(whitelist_entry)
        await session.commit()

        yield user

        # Cleanup
        await session.execute(delete(Whitelist).where(Whitelist.github_id == "testuser"))
        await session.execute(delete(User).where(User.github_id == "testuser"))
        await session.commit()


@pytest.fixture
async def admin_user():
    """Create an admin user."""
    async with async_session_factory() as session:
        user = User(
            github_id="adminuser",
            github_avatar="https://example.com/admin.png",
            is_admin=True,
        )
        session.add(user)
        await session.commit()
        await session.refresh(user)

        # Add to whitelist
        whitelist_entry = Whitelist(github_id="adminuser")
        session.add(whitelist_entry)
        await session.commit()

        yield user

        # Cleanup
        await session.execute(delete(Whitelist).where(Whitelist.github_id == "adminuser"))
        await session.execute(delete(User).where(User.github_id == "adminuser"))
        await session.commit()


@pytest.fixture
def user_token(test_user):
    """Create JWT token for test user."""
    return create_jwt_token(user_id=test_user.id, github_id=test_user.github_id)


@pytest.fixture
def admin_token(admin_user):
    """Create JWT token for admin user."""
    return create_jwt_token(user_id=admin_user.id, github_id=admin_user.github_id)


class TestGetMe:
    """Tests for GET /api/me endpoint."""

    @pytest.mark.asyncio
    async def test_get_me_success(self, test_user, user_token):
        """Test getting current user info."""
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.get(
                "/api/me",
                headers={"Authorization": f"Bearer {user_token}"},
            )

        assert response.status_code == 200
        data = response.json()
        assert data["github_id"] == "testuser"
        assert data["github_avatar"] == "https://example.com/avatar.png"
        assert data["is_admin"] is False
        assert "id" in data
        assert "created_at" in data

    @pytest.mark.asyncio
    async def test_get_me_admin(self, admin_user, admin_token):
        """Test getting admin user info."""
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.get(
                "/api/me",
                headers={"Authorization": f"Bearer {admin_token}"},
            )

        assert response.status_code == 200
        data = response.json()
        assert data["github_id"] == "adminuser"
        assert data["is_admin"] is True

    @pytest.mark.asyncio
    async def test_get_me_without_token(self):
        """Test getting user info without token."""
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.get("/api/me")

        assert response.status_code == 401


class TestAdminUsers:
    """Tests for admin user management endpoints."""

    @pytest.mark.asyncio
    async def test_list_users_as_admin(self, admin_user, admin_token, test_user):
        """Test listing users as admin."""
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.get(
                "/admin/api/users",
                headers={"Authorization": f"Bearer {admin_token}"},
            )

        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        # Should include both admin and test user
        github_ids = [u["github_id"] for u in data]
        assert "adminuser" in github_ids
        assert "testuser" in github_ids

    @pytest.mark.asyncio
    async def test_list_users_as_non_admin(self, test_user, user_token):
        """Test listing users as non-admin (should fail)."""
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.get(
                "/admin/api/users",
                headers={"Authorization": f"Bearer {user_token}"},
            )

        assert response.status_code == 403

    @pytest.mark.asyncio
    async def test_delete_user_as_admin(self, admin_user, admin_token):
        """Test deleting a user as admin."""
        # Create a user to delete
        async with async_session_factory() as session:
            user_to_delete = User(github_id="deleteuser", is_admin=False)
            session.add(user_to_delete)
            await session.commit()
            await session.refresh(user_to_delete)
            user_id = user_to_delete.id

        try:
            async with AsyncClient(
                transport=ASGITransport(app=app), base_url="http://test"
            ) as client:
                response = await client.delete(
                    f"/admin/api/users/{user_id}",
                    headers={"Authorization": f"Bearer {admin_token}"},
                )

            assert response.status_code == 204
        finally:
            # Cleanup in case deletion failed
            async with async_session_factory() as session:
                await session.execute(delete(User).where(User.github_id == "deleteuser"))
                await session.commit()

    @pytest.mark.asyncio
    async def test_delete_admin_user_fails(self, admin_user, admin_token):
        """Test that admin users cannot be deleted."""
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.delete(
                f"/admin/api/users/{admin_user.id}",
                headers={"Authorization": f"Bearer {admin_token}"},
            )

        assert response.status_code == 400


class TestAdminWhitelist:
    """Tests for admin whitelist management endpoints."""

    @pytest.mark.asyncio
    async def test_list_whitelist(self, admin_user, admin_token, test_user):
        """Test listing whitelist entries."""
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.get(
                "/admin/api/whitelist",
                headers={"Authorization": f"Bearer {admin_token}"},
            )

        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)

    @pytest.mark.asyncio
    async def test_add_to_whitelist(self, admin_user, admin_token):
        """Test adding to whitelist."""
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.post(
                "/admin/api/whitelist",
                headers={"Authorization": f"Bearer {admin_token}"},
                json={"github_id": "newwhitelistuser"},
            )

        assert response.status_code == 201
        data = response.json()
        assert data["github_id"] == "newwhitelistuser"

        # Cleanup
        async with async_session_factory() as session:
            await session.execute(
                delete(Whitelist).where(Whitelist.github_id == "newwhitelistuser")
            )
            await session.commit()

    @pytest.mark.asyncio
    async def test_remove_from_whitelist(self, admin_user, admin_token):
        """Test removing from whitelist."""
        # Create a whitelist entry to delete
        async with async_session_factory() as session:
            entry = Whitelist(github_id="toremove")
            session.add(entry)
            await session.commit()
            await session.refresh(entry)
            entry_id = entry.id

        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.delete(
                f"/admin/api/whitelist/{entry_id}",
                headers={"Authorization": f"Bearer {admin_token}"},
            )

        assert response.status_code == 204

    @pytest.mark.asyncio
    async def test_add_to_whitelist_with_username(self, admin_user, admin_token):
        """Test adding to whitelist with github_username."""
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.post(
                "/admin/api/whitelist",
                headers={"Authorization": f"Bearer {admin_token}"},
                json={"github_id": "99999999", "github_username": "testusername"},
            )

        assert response.status_code == 201
        data = response.json()
        assert data["github_id"] == "99999999"
        assert data["github_username"] == "testusername"

        # Cleanup
        async with async_session_factory() as session:
            await session.execute(
                delete(Whitelist).where(Whitelist.github_id == "99999999")
            )
            await session.commit()


class TestAdminDictionary:
    """Tests for admin global dictionary management endpoints."""

    @pytest.mark.asyncio
    async def test_list_global_dictionary(self, admin_user, admin_token):
        """Test listing global dictionary entries."""
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.get(
                "/admin/api/dictionary",
                headers={"Authorization": f"Bearer {admin_token}"},
            )

        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)

    @pytest.mark.asyncio
    async def test_add_global_dictionary_entry(self, admin_user, admin_token):
        """Test adding global dictionary entry."""
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.post(
                "/admin/api/dictionary",
                headers={"Authorization": f"Bearer {admin_token}"},
                json={"pattern": "くろーど", "replacement": "Claude"},
            )

        assert response.status_code == 201
        data = response.json()
        assert data["pattern"] == "くろーど"
        assert data["replacement"] == "Claude"

        # Cleanup
        async with async_session_factory() as session:
            await session.execute(
                delete(GlobalDictionary).where(GlobalDictionary.pattern == "くろーど")
            )
            await session.commit()

    @pytest.mark.asyncio
    async def test_delete_global_dictionary_entry(self, admin_user, admin_token):
        """Test deleting global dictionary entry."""
        # Create an entry to delete
        async with async_session_factory() as session:
            entry = GlobalDictionary(
                pattern="todelete",
                replacement="deleted",
                created_by=admin_user.id,
            )
            session.add(entry)
            await session.commit()
            await session.refresh(entry)
            entry_id = entry.id

        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.delete(
                f"/admin/api/dictionary/{entry_id}",
                headers={"Authorization": f"Bearer {admin_token}"},
            )

        assert response.status_code == 204
