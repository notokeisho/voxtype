"""Tests for GitHub OAuth authentication and JWT tokens."""

import time

import pytest
from fastapi import status
from fastapi.testclient import TestClient

from app.auth.jwt import create_jwt_token, verify_jwt_token
from app.config import settings
from app.main import app


@pytest.fixture
def client():
    """Create a test client for the FastAPI application."""
    return TestClient(app)


class TestLoginRedirect:
    """Tests for the /auth/login endpoint."""

    def test_login_redirects_to_github(self, client: TestClient):
        """Test that /auth/login redirects to GitHub OAuth."""
        response = client.get("/auth/login", follow_redirects=False)
        assert response.status_code == status.HTTP_302_FOUND
        assert "github.com" in response.headers["location"]

    def test_login_includes_client_id(self, client: TestClient):
        """Test that the redirect URL includes the GitHub client ID."""
        response = client.get("/auth/login", follow_redirects=False)
        location = response.headers["location"]
        assert settings.github_client_id in location

    def test_login_includes_redirect_uri(self, client: TestClient):
        """Test that the redirect URL includes the callback URI."""
        response = client.get("/auth/login", follow_redirects=False)
        location = response.headers["location"]
        assert "redirect_uri" in location


class TestOAuthCallbackAllowlist:
    """Tests for the OAuth callback allowlist."""

    def test_allowed_callback_starts_oauth(self, client: TestClient):
        """An allowlisted callback is accepted and the OAuth flow starts."""
        response = client.get(
            "/auth/github/login?callback=voxtype://callback",
            follow_redirects=False,
        )
        assert response.status_code == status.HTTP_302_FOUND
        assert "github.com" in response.headers["location"]

    def test_unknown_callback_is_rejected(self, client: TestClient):
        """A callback outside the allowlist is rejected before reaching GitHub."""
        response = client.get(
            "/auth/github/login?callback=https://attacker.example.com/steal",
            follow_redirects=False,
        )
        assert response.status_code == status.HTTP_400_BAD_REQUEST

    def test_unknown_redirect_uri_is_rejected(self, client: TestClient):
        """The admin-web parameter name is checked the same way."""
        response = client.get(
            "/auth/login?redirect_uri=https://attacker.example.com/steal",
            follow_redirects=False,
        )
        assert response.status_code == status.HTTP_400_BAD_REQUEST

    def test_callback_rejects_session_value_outside_allowlist(self, client: TestClient):
        """A session value that is no longer allowed never reaches a token."""
        original = settings.oauth_callback_allowlist
        settings.oauth_callback_allowlist = "voxtype://callback"
        try:
            client.get(
                "/auth/github/login?callback=voxtype://callback",
                follow_redirects=False,
            )
            settings.oauth_callback_allowlist = "https://voxtype-admin.oshiruko.dev/auth/callback"
            response = client.get("/auth/github/callback?code=dummy", follow_redirects=False)
        finally:
            settings.oauth_callback_allowlist = original

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert "voxtype://callback" not in response.headers.get("location", "")
        assert "token" not in response.text


class TestJWTToken:
    """Tests for JWT token creation and verification."""

    def test_create_jwt_token(self):
        """Test JWT token creation."""
        token = create_jwt_token(user_id=1, github_id="testuser")
        assert token is not None
        assert isinstance(token, str)

    def test_verify_jwt_token(self):
        """Test JWT token verification returns correct payload."""
        token = create_jwt_token(user_id=1, github_id="testuser")
        payload = verify_jwt_token(token)
        assert payload is not None
        assert payload["user_id"] == 1
        assert payload["github_id"] == "testuser"

    def test_jwt_token_contains_expiration(self):
        """Test JWT token contains expiration claim."""
        token = create_jwt_token(user_id=1, github_id="testuser")
        payload = verify_jwt_token(token)
        assert "exp" in payload

    def test_jwt_expiration_is_7_days(self):
        """Test JWT token expires in 7 days."""
        token = create_jwt_token(user_id=1, github_id="testuser")
        payload = verify_jwt_token(token)
        now = time.time()
        seven_days = 7 * 24 * 60 * 60
        # Token should expire in approximately 7 days
        assert payload["exp"] > now
        assert payload["exp"] <= now + seven_days + 1

    def test_invalid_token_returns_none(self):
        """Test that an invalid token returns None."""
        payload = verify_jwt_token("invalid.token.here")
        assert payload is None

    def test_expired_token_returns_none(self):
        """Test that an expired token returns None."""
        # Create a token that expires immediately (for testing)
        from datetime import UTC, datetime, timedelta

        from jose import jwt

        payload = {
            "user_id": 1,
            "github_id": "testuser",
            "exp": datetime.now(UTC) - timedelta(days=1),
        }
        token = jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)
        result = verify_jwt_token(token)
        assert result is None

    def test_token_with_wrong_secret_returns_none(self):
        """Test that a token signed with wrong secret returns None."""
        from jose import jwt

        payload = {
            "user_id": 1,
            "github_id": "testuser",
            "exp": time.time() + 3600,
        }
        token = jwt.encode(payload, "wrong-secret", algorithm="HS256")
        result = verify_jwt_token(token)
        assert result is None


class TestCallbackEndpoint:
    """Tests for the /auth/github/callback endpoint."""

    def test_callback_without_code_returns_error(self, client: TestClient):
        """Test that callback without code returns an error."""
        response = client.get("/auth/github/callback")
        assert response.status_code == status.HTTP_400_BAD_REQUEST

    def test_callback_with_error_returns_error(self, client: TestClient):
        """Test that callback with error parameter returns an error."""
        response = client.get("/auth/github/callback?error=access_denied")
        assert response.status_code == status.HTTP_400_BAD_REQUEST

    def test_error_page_escapes_reflected_values(self, client: TestClient):
        """The error page must not reflect query values as markup."""
        response = client.get("/auth/error?error=x&message=<script>alert(1)</script>")
        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert "<script>alert(1)</script>" not in response.text
        assert "&lt;script&gt;" in response.text
