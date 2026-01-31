"""Integration tests for the full transcription flow."""

import asyncio
from unittest.mock import AsyncMock, patch

import pytest
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


async def _setup_integration_test_user(github_id: str):
    """Set up test user with whitelist and dictionary entries."""
    from app.models.global_dictionary import add_global_entry
    from app.models.user import User
    from app.models.user_dictionary import add_user_entry
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
        await session.execute(
            text("DELETE FROM global_dictionary WHERE pattern IN ('くろーど', 'えーあい')")
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

        # Add global dictionary entry
        await add_global_entry(session, "くろーど", "Claude")

        # Add user dictionary entry (should override global)
        await add_user_entry(session, user.id, "えーあい", "AI")

        user_id = user.id

    await engine.dispose()
    return user_id


async def _cleanup_integration_test_user(github_id: str):
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
        await session.execute(
            text("DELETE FROM global_dictionary WHERE pattern IN ('くろーど', 'えーあい')")
        )
        await session.execute(text(f"DELETE FROM whitelist WHERE github_id = '{github_id}'"))
        await session.execute(text(f"DELETE FROM users WHERE github_id = '{github_id}'"))
        await session.commit()

    await engine.dispose()


def setup_integration_test_user(github_id: str) -> int:
    """Sync wrapper."""
    return run_async(_setup_integration_test_user(github_id))


def cleanup_integration_test_user(github_id: str):
    """Sync wrapper."""
    run_async(_cleanup_integration_test_user(github_id))


def create_test_audio_file() -> tuple[bytes, str]:
    """Create a minimal WAV file for testing."""
    wav_data = bytearray()
    # RIFF header
    wav_data.extend(b"RIFF")
    wav_data.extend((36 + 100).to_bytes(4, "little"))
    wav_data.extend(b"WAVE")
    # fmt chunk
    wav_data.extend(b"fmt ")
    wav_data.extend((16).to_bytes(4, "little"))
    wav_data.extend((1).to_bytes(2, "little"))  # audio format (PCM)
    wav_data.extend((1).to_bytes(2, "little"))  # num channels
    wav_data.extend((16000).to_bytes(4, "little"))  # sample rate
    wav_data.extend((32000).to_bytes(4, "little"))  # byte rate
    wav_data.extend((2).to_bytes(2, "little"))  # block align
    wav_data.extend((16).to_bytes(2, "little"))  # bits per sample
    # data chunk
    wav_data.extend(b"data")
    wav_data.extend((100).to_bytes(4, "little"))
    wav_data.extend(bytes(100))  # silence

    return bytes(wav_data), "test.wav"


@pytest.mark.integration
class TestFullTranscriptionFlow:
    """Integration tests for the complete transcription flow."""

    def test_full_flow_authentication_to_transcription(self):
        """Test full flow: authentication -> transcription -> postprocess."""
        github_id = "integration_test_1"
        client = TestClient(app)

        try:
            # 1. Set up user with whitelist and dictionary
            user_id = setup_integration_test_user(github_id)

            # 2. Create JWT token (simulating login)
            token = create_jwt_token(user_id=user_id, github_id=github_id)

            # 3. Prepare audio file
            audio_data, filename = create_test_audio_file()

            # 4. Make transcription request with mocked whisper
            with patch(
                "app.api.transcribe.whisper_client.transcribe",
                new_callable=AsyncMock,
                return_value="くろーどとえーあいを使っています",
            ):
                response = client.post(
                    "/api/transcribe",
                    files={"audio": (filename, audio_data, "audio/wav")},
                    headers={"Authorization": f"Bearer {token}"},
                )

            # 5. Verify response
            assert response.status_code == status.HTTP_200_OK
            data = response.json()

            # Raw text should be the original whisper output
            assert data["raw_text"] == "くろーどとえーあいを使っています"

            # Processed text should have dictionary replacements applied
            assert "Claude" in data["text"]  # Global dictionary
            assert "AI" in data["text"]  # User dictionary

        finally:
            cleanup_integration_test_user(github_id)

    def test_full_flow_with_user_dictionary_priority(self):
        """Test that user dictionary takes priority over global dictionary."""
        github_id = "integration_test_2"
        client = TestClient(app)

        try:
            user_id = setup_integration_test_user(github_id)
            token = create_jwt_token(user_id=user_id, github_id=github_id)
            audio_data, filename = create_test_audio_file()

            # Add a user entry that overrides a global entry
            async def _add_override_entry():
                from app.models.global_dictionary import add_global_entry
                from app.models.user_dictionary import add_user_entry

                engine = create_async_engine(settings.database_url)
                async_session = async_sessionmaker(
                    engine, class_=AsyncSession, expire_on_commit=False
                )

                async with async_session() as session:
                    # Global: API -> Application Programming Interface
                    await add_global_entry(session, "API", "Application Programming Interface")
                    # User: API -> エーピーアイ (should take priority)
                    await add_user_entry(session, user_id, "API", "エーピーアイ")

                await engine.dispose()

            run_async(_add_override_entry())

            with patch(
                "app.api.transcribe.whisper_client.transcribe",
                new_callable=AsyncMock,
                return_value="APIを使っています",
            ):
                response = client.post(
                    "/api/transcribe",
                    files={"audio": (filename, audio_data, "audio/wav")},
                    headers={"Authorization": f"Bearer {token}"},
                )

            assert response.status_code == status.HTTP_200_OK
            data = response.json()

            # User dictionary should take priority
            assert "エーピーアイ" in data["text"]
            assert "Application Programming Interface" not in data["text"]

        finally:
            # Clean up additional entries
            async def _cleanup_override():
                engine = create_async_engine(settings.database_url)
                async_session = async_sessionmaker(
                    engine, class_=AsyncSession, expire_on_commit=False
                )
                async with async_session() as session:
                    await session.execute(
                        text("DELETE FROM global_dictionary WHERE pattern = 'API'")
                    )
                    await session.commit()
                await engine.dispose()

            run_async(_cleanup_override())
            cleanup_integration_test_user(github_id)

    def test_full_flow_dictionary_management_and_transcription(self):
        """Test adding dictionary entry and using it in transcription."""
        github_id = "integration_test_3"
        client = TestClient(app)

        try:
            user_id = setup_integration_test_user(github_id)
            token = create_jwt_token(user_id=user_id, github_id=github_id)
            audio_data, filename = create_test_audio_file()
            headers = {"Authorization": f"Bearer {token}"}

            # 1. Add a new dictionary entry via API
            add_response = client.post(
                "/api/dictionary",
                headers=headers,
                json={"pattern": "ぱいそん", "replacement": "Python"},
            )
            assert add_response.status_code == status.HTTP_201_CREATED

            # 2. Verify the entry is in the dictionary
            get_response = client.get("/api/dictionary", headers=headers)
            assert get_response.status_code == status.HTTP_200_OK
            entries = get_response.json()["entries"]
            patterns = [e["pattern"] for e in entries]
            assert "ぱいそん" in patterns

            # 3. Transcribe with the new dictionary entry
            with patch(
                "app.api.transcribe.whisper_client.transcribe",
                new_callable=AsyncMock,
                return_value="ぱいそんでプログラミングをしています",
            ):
                response = client.post(
                    "/api/transcribe",
                    files={"audio": (filename, audio_data, "audio/wav")},
                    headers=headers,
                )

            assert response.status_code == status.HTTP_200_OK
            data = response.json()
            assert "Python" in data["text"]

        finally:
            cleanup_integration_test_user(github_id)

    def test_full_flow_without_whitelist_rejected(self):
        """Test that user without whitelist is rejected."""
        github_id = "integration_test_4"
        client = TestClient(app)

        try:
            # Set up user WITHOUT whitelist
            async def _setup_user_no_whitelist():
                from app.models.user import User

                engine = create_async_engine(settings.database_url)
                async_session = async_sessionmaker(
                    engine, class_=AsyncSession, expire_on_commit=False
                )

                async with async_session() as session:
                    await session.execute(text(f"DELETE FROM users WHERE github_id = '{github_id}'"))
                    await session.commit()

                    user = User(github_id=github_id)
                    session.add(user)
                    await session.commit()
                    await session.refresh(user)
                    user_id = user.id

                await engine.dispose()
                return user_id

            user_id = run_async(_setup_user_no_whitelist())
            token = create_jwt_token(user_id=user_id, github_id=github_id)
            audio_data, filename = create_test_audio_file()

            # Should be rejected with 403 Forbidden
            response = client.post(
                "/api/transcribe",
                files={"audio": (filename, audio_data, "audio/wav")},
                headers={"Authorization": f"Bearer {token}"},
            )

            assert response.status_code == status.HTTP_403_FORBIDDEN

        finally:
            async def _cleanup():
                engine = create_async_engine(settings.database_url)
                async_session = async_sessionmaker(
                    engine, class_=AsyncSession, expire_on_commit=False
                )
                async with async_session() as session:
                    await session.execute(text(f"DELETE FROM users WHERE github_id = '{github_id}'"))
                    await session.commit()
                await engine.dispose()

            run_async(_cleanup())

    def test_status_endpoint_health_check(self):
        """Test status endpoint as part of integration test."""
        client = TestClient(app)

        # Status endpoint should work without authentication
        response = client.get("/api/status")

        assert response.status_code == status.HTTP_200_OK
        data = response.json()
        assert "status" in data
        assert "database" in data
        assert "whisper_server" in data
        # Database should be connected in test environment
        assert data["database"] == "connected"
