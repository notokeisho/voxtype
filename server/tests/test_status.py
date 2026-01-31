"""Tests for the status/health check API."""

import pytest
from fastapi import status
from fastapi.testclient import TestClient

from app.main import app


@pytest.fixture
def client():
    """Create a test client for the FastAPI application."""
    return TestClient(app)


class TestStatusEndpoint:
    """Tests for the /api/status endpoint."""

    def test_status_endpoint_returns_200(self, client: TestClient):
        """Test that /api/status returns 200 OK."""
        response = client.get("/api/status")
        assert response.status_code == status.HTTP_200_OK

    def test_status_endpoint_returns_ok_status(self, client: TestClient):
        """Test that /api/status returns status ok."""
        response = client.get("/api/status")
        data = response.json()
        assert data["status"] == "ok"

    def test_status_endpoint_includes_database_status(self, client: TestClient):
        """Test that /api/status includes database connection status."""
        response = client.get("/api/status")
        data = response.json()
        assert "database" in data
        assert data["database"] == "connected"

    def test_status_endpoint_includes_whisper_server_status(self, client: TestClient):
        """Test that /api/status includes whisper server status."""
        response = client.get("/api/status")
        data = response.json()
        assert "whisper_server" in data
        # whisper_server may be "connected" or "disconnected" depending on environment

    def test_status_endpoint_is_public(self, client: TestClient):
        """Test that /api/status does not require authentication."""
        # No Authorization header, should still work
        response = client.get("/api/status")
        assert response.status_code == status.HTTP_200_OK
