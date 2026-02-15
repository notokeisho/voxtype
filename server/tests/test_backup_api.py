"""Tests for backup admin API endpoints."""

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import delete, text

from app.auth.jwt import create_jwt_token
from app.database import async_session_factory
from app.main import app
from app.models.user import User
from app.models.whitelist import Whitelist


@pytest.fixture
async def admin_user():
    """Create an admin user."""
    async with async_session_factory() as session:
        user = User(
            github_id="backupadmin",
            github_avatar="https://example.com/admin.png",
            is_admin=True,
        )
        session.add(user)
        await session.commit()
        await session.refresh(user)

        whitelist_entry = Whitelist(github_id="backupadmin")
        session.add(whitelist_entry)
        await session.commit()

        yield user

        await session.execute(delete(Whitelist).where(Whitelist.github_id == "backupadmin"))
        await session.execute(delete(User).where(User.github_id == "backupadmin"))
        await session.execute(text("DELETE FROM backup_settings"))
        await session.commit()


@pytest.fixture
def admin_token(admin_user):
    """Create JWT token for admin user."""
    return create_jwt_token(user_id=admin_user.id, github_id=admin_user.github_id)


class TestBackupSettingsApi:
    """Tests for backup settings endpoints."""

    @pytest.mark.asyncio
    async def test_get_backup_settings_default(self, admin_token):
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.get(
                "/admin/api/dictionary/backup",
                headers={"Authorization": f"Bearer {admin_token}"},
            )

        assert response.status_code == 200
        data = response.json()
        assert data["enabled"] is False
        assert data["last_run_at"] is None

    @pytest.mark.asyncio
    async def test_update_backup_settings(self, admin_token):
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.patch(
                "/admin/api/dictionary/backup",
                headers={"Authorization": f"Bearer {admin_token}"},
                json={"enabled": True},
            )

        assert response.status_code == 200
        data = response.json()
        assert data["enabled"] is True


class TestBackupRunApi:
    """Tests for backup run endpoint."""

    @pytest.mark.asyncio
    async def test_run_backup(self, admin_token):
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.post(
                "/admin/api/dictionary/backup/run",
                headers={"Authorization": f"Bearer {admin_token}"},
            )

        assert response.status_code == 200
        data = response.json()
        assert data["created_file"].endswith(".xlsx")
        assert data["created_at"] is not None
        assert isinstance(data["kept"], int)
        assert isinstance(data["deleted"], int)
