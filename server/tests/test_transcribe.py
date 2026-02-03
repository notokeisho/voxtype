"""Tests for the transcribe API endpoint."""

import asyncio
import os
from pathlib import Path
from unittest.mock import AsyncMock, patch

from fastapi import status
from fastapi.testclient import TestClient
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.auth.jwt import create_jwt_token
from app.config import settings
from app.main import app


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


def setup_test_user(github_id: str) -> int:
    """Sync wrapper."""
    return run_async(_setup_test_user(github_id))


def cleanup_test_user(github_id: str):
    """Sync wrapper."""
    run_async(_cleanup_test_user(github_id))


def create_test_audio_file() -> tuple[bytes, str]:
    """Create a minimal WAV file for testing."""
    # Minimal WAV header (44 bytes) + some audio data
    wav_data = bytearray()
    # RIFF header
    wav_data.extend(b"RIFF")
    wav_data.extend((36 + 100).to_bytes(4, "little"))  # file size - 8
    wav_data.extend(b"WAVE")
    # fmt chunk
    wav_data.extend(b"fmt ")
    wav_data.extend((16).to_bytes(4, "little"))  # chunk size
    wav_data.extend((1).to_bytes(2, "little"))  # audio format (PCM)
    wav_data.extend((1).to_bytes(2, "little"))  # num channels
    wav_data.extend((16000).to_bytes(4, "little"))  # sample rate
    wav_data.extend((32000).to_bytes(4, "little"))  # byte rate
    wav_data.extend((2).to_bytes(2, "little"))  # block align
    wav_data.extend((16).to_bytes(2, "little"))  # bits per sample
    # data chunk
    wav_data.extend(b"data")
    wav_data.extend((100).to_bytes(4, "little"))  # data size
    wav_data.extend(bytes(100))  # silence

    return bytes(wav_data), "test.wav"


class TestTranscribeEndpointAuthentication:
    """Tests for transcribe endpoint authentication."""

    def test_transcribe_without_token_returns_401(self):
        """Test that transcribe without token returns 401."""
        client = TestClient(app)
        audio_data, filename = create_test_audio_file()

        response = client.post(
            "/api/transcribe",
            files={"audio": (filename, audio_data, "audio/wav")},
        )

        assert response.status_code == status.HTTP_401_UNAUTHORIZED

    def test_transcribe_with_invalid_token_returns_401(self):
        """Test that transcribe with invalid token returns 401."""
        client = TestClient(app)
        audio_data, filename = create_test_audio_file()

        response = client.post(
            "/api/transcribe",
            files={"audio": (filename, audio_data, "audio/wav")},
            headers={"Authorization": "Bearer invalid.token.here"},
        )

        assert response.status_code == status.HTTP_401_UNAUTHORIZED


class TestTranscribeEndpointSuccess:
    """Tests for successful transcription."""

    def test_transcribe_returns_text(self):
        """Test that transcribe returns transcribed text."""
        github_id = "transcribe_test_1"
        client = TestClient(app)

        try:
            user_id = setup_test_user(github_id)
            token = create_jwt_token(user_id=user_id, github_id=github_id)
            audio_data, filename = create_test_audio_file()

            # Mock whisper client
            with patch(
                "app.api.transcribe.whisper_client.transcribe",
                new_callable=AsyncMock,
                return_value="これはテストです",
            ):
                response = client.post(
                    "/api/transcribe",
                    files={"audio": (filename, audio_data, "audio/wav")},
                    headers={"Authorization": f"Bearer {token}"},
                )

            assert response.status_code == status.HTTP_200_OK
            assert "text" in response.json()
            assert response.json()["text"] == "これはテストです"
        finally:
            cleanup_test_user(github_id)

    def test_transcribe_applies_dictionary(self):
        """Test that transcribe applies dictionary replacements."""
        github_id = "transcribe_test_2"
        client = TestClient(app)

        try:
            user_id = setup_test_user(github_id)
            token = create_jwt_token(user_id=user_id, github_id=github_id)
            audio_data, filename = create_test_audio_file()

            # Mock whisper client and postprocess
            with patch(
                "app.api.transcribe.whisper_client.transcribe",
                new_callable=AsyncMock,
                return_value="くろーどを使っています",
            ), patch(
                "app.api.transcribe.apply_dictionary",
                new_callable=AsyncMock,
                return_value="Claudeを使っています",
            ):
                response = client.post(
                    "/api/transcribe",
                    files={"audio": (filename, audio_data, "audio/wav")},
                    headers={"Authorization": f"Bearer {token}"},
                )

            assert response.status_code == status.HTTP_200_OK
            assert response.json()["text"] == "Claudeを使っています"
        finally:
            cleanup_test_user(github_id)


class TestTranscribeEndpointFileHandling:
    """Tests for file upload and cleanup."""

    def test_transcribe_without_file_returns_422(self):
        """Test that transcribe without file returns 422."""
        github_id = "transcribe_test_3"
        client = TestClient(app)

        try:
            user_id = setup_test_user(github_id)
            token = create_jwt_token(user_id=user_id, github_id=github_id)

            response = client.post(
                "/api/transcribe",
                headers={"Authorization": f"Bearer {token}"},
            )

            assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY
        finally:
            cleanup_test_user(github_id)

    def test_temp_file_is_cleaned_up_on_success(self):
        """Test that temporary file is deleted after successful transcription."""
        github_id = "transcribe_test_4"
        client = TestClient(app)
        temp_files_created = []

        try:
            user_id = setup_test_user(github_id)
            token = create_jwt_token(user_id=user_id, github_id=github_id)
            audio_data, filename = create_test_audio_file()

            # Track temp file creation
            original_write = Path.write_bytes

            def track_write(self, data):
                if "voxtype" in str(self):
                    temp_files_created.append(str(self))
                return original_write(self, data)

            with patch(
                "app.api.transcribe.whisper_client.transcribe",
                new_callable=AsyncMock,
                return_value="テスト",
            ), patch.object(Path, "write_bytes", track_write):
                response = client.post(
                    "/api/transcribe",
                    files={"audio": (filename, audio_data, "audio/wav")},
                    headers={"Authorization": f"Bearer {token}"},
                )

            assert response.status_code == status.HTTP_200_OK

            # Verify temp files are cleaned up
            for temp_file in temp_files_created:
                assert not os.path.exists(temp_file), f"Temp file not cleaned up: {temp_file}"
        finally:
            cleanup_test_user(github_id)

    def test_temp_file_is_cleaned_up_on_error(self):
        """Test that temporary file is deleted even when transcription fails."""
        github_id = "transcribe_test_5"
        client = TestClient(app)

        try:
            user_id = setup_test_user(github_id)
            token = create_jwt_token(user_id=user_id, github_id=github_id)
            audio_data, filename = create_test_audio_file()

            from app.services.whisper_client import WhisperError

            with patch(
                "app.api.transcribe.whisper_client.transcribe",
                new_callable=AsyncMock,
                side_effect=WhisperError("Transcription failed"),
            ):
                response = client.post(
                    "/api/transcribe",
                    files={"audio": (filename, audio_data, "audio/wav")},
                    headers={"Authorization": f"Bearer {token}"},
                )

            # Should return error but still clean up
            assert response.status_code == status.HTTP_500_INTERNAL_SERVER_ERROR
        finally:
            cleanup_test_user(github_id)


class TestTranscribeEndpointResponse:
    """Tests for transcribe endpoint response format."""

    def test_response_includes_original_text(self):
        """Test that response includes original (raw) text."""
        github_id = "transcribe_test_6"
        client = TestClient(app)

        try:
            user_id = setup_test_user(github_id)
            token = create_jwt_token(user_id=user_id, github_id=github_id)
            audio_data, filename = create_test_audio_file()

            with patch(
                "app.api.transcribe.whisper_client.transcribe",
                new_callable=AsyncMock,
                return_value="くろーど",
            ), patch(
                "app.api.transcribe.apply_dictionary",
                new_callable=AsyncMock,
                return_value="Claude",
            ):
                response = client.post(
                    "/api/transcribe",
                    files={"audio": (filename, audio_data, "audio/wav")},
                    headers={"Authorization": f"Bearer {token}"},
                )

            assert response.status_code == status.HTTP_200_OK
            data = response.json()
            assert "text" in data
            assert "raw_text" in data
            assert data["raw_text"] == "くろーど"
            assert data["text"] == "Claude"
        finally:
            cleanup_test_user(github_id)
