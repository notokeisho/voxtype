"""Tests for the whisper.cpp client."""

import tempfile
from pathlib import Path
from unittest.mock import AsyncMock, patch

import pytest

from app.services.whisper_client import (
    WhisperClient,
    WhisperError,
    WhisperServerError,
    WhisperTimeoutError,
)


@pytest.fixture
def whisper_client():
    """Create a WhisperClient instance."""
    return WhisperClient()


@pytest.fixture
def test_audio_file():
    """Create a temporary test audio file."""
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        # Write minimal WAV header (44 bytes) + some data
        # RIFF header
        f.write(b"RIFF")
        f.write((36).to_bytes(4, "little"))  # file size - 8
        f.write(b"WAVE")
        # fmt chunk
        f.write(b"fmt ")
        f.write((16).to_bytes(4, "little"))  # chunk size
        f.write((1).to_bytes(2, "little"))  # audio format (PCM)
        f.write((1).to_bytes(2, "little"))  # num channels
        f.write((16000).to_bytes(4, "little"))  # sample rate
        f.write((32000).to_bytes(4, "little"))  # byte rate
        f.write((2).to_bytes(2, "little"))  # block align
        f.write((16).to_bytes(2, "little"))  # bits per sample
        # data chunk
        f.write(b"data")
        f.write((0).to_bytes(4, "little"))  # data size
        path = Path(f.name)

    yield path

    # Cleanup
    if path.exists():
        path.unlink()


class TestWhisperClient:
    """Tests for WhisperClient class."""

    def test_client_initialization(self, whisper_client: WhisperClient):
        """Test that WhisperClient initializes correctly."""
        assert whisper_client is not None
        assert whisper_client.servers is not None
        assert "fast" in whisper_client.servers
        assert "smart" in whisper_client.servers

    def test_get_base_url_fast(self, whisper_client: WhisperClient):
        """Test _get_base_url returns fast server URL."""
        url = whisper_client._get_base_url("fast")
        assert url == whisper_client.servers["fast"]

    def test_get_base_url_smart(self, whisper_client: WhisperClient):
        """Test _get_base_url returns smart server URL."""
        url = whisper_client._get_base_url("smart")
        assert url == whisper_client.servers["smart"]

    def test_get_base_url_invalid_defaults_to_fast(self, whisper_client: WhisperClient):
        """Test _get_base_url with invalid model defaults to fast."""
        url = whisper_client._get_base_url("invalid")
        assert url == whisper_client.servers["fast"]

    @pytest.mark.asyncio
    async def test_transcribe_success(
        self, whisper_client: WhisperClient, test_audio_file: Path
    ):
        """Test successful transcription."""
        from unittest.mock import MagicMock

        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"text": "これはテストです"}

        with patch(
            "app.services.whisper_client.httpx.AsyncClient"
        ) as mock_client_class:
            mock_client = AsyncMock()
            mock_client.post.return_value = mock_response
            mock_client_class.return_value.__aenter__.return_value = mock_client

            result = await whisper_client.transcribe(str(test_audio_file))

        assert isinstance(result, str)
        assert result == "これはテストです"

    @pytest.mark.asyncio
    async def test_transcribe_returns_string(
        self, whisper_client: WhisperClient, test_audio_file: Path
    ):
        """Test that transcribe returns a string."""
        from unittest.mock import MagicMock

        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"text": "テスト結果"}

        with patch(
            "app.services.whisper_client.httpx.AsyncClient"
        ) as mock_client_class:
            mock_client = AsyncMock()
            mock_client.post.return_value = mock_response
            mock_client_class.return_value.__aenter__.return_value = mock_client

            result = await whisper_client.transcribe(str(test_audio_file))

        assert isinstance(result, str)
        assert len(result) > 0

    @pytest.mark.asyncio
    async def test_transcribe_with_smart_model(
        self, whisper_client: WhisperClient, test_audio_file: Path
    ):
        """Test transcription with smart model."""
        from unittest.mock import MagicMock

        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"text": "スマートモデルの結果"}

        with patch(
            "app.services.whisper_client.httpx.AsyncClient"
        ) as mock_client_class:
            mock_client = AsyncMock()
            mock_client.post.return_value = mock_response
            mock_client_class.return_value.__aenter__.return_value = mock_client

            result = await whisper_client.transcribe(str(test_audio_file), model="smart")

            # Verify the correct URL was used
            call_args = mock_client.post.call_args
            assert whisper_client.servers["smart"] in call_args[0][0]

        assert result == "スマートモデルの結果"

    @pytest.mark.asyncio
    async def test_transcribe_default_model_is_fast(
        self, whisper_client: WhisperClient, test_audio_file: Path
    ):
        """Test that default model is fast."""
        from unittest.mock import MagicMock

        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"text": "デフォルトモデルの結果"}

        with patch(
            "app.services.whisper_client.httpx.AsyncClient"
        ) as mock_client_class:
            mock_client = AsyncMock()
            mock_client.post.return_value = mock_response
            mock_client_class.return_value.__aenter__.return_value = mock_client

            result = await whisper_client.transcribe(str(test_audio_file))

            # Verify the fast URL was used (default)
            call_args = mock_client.post.call_args
            assert whisper_client.servers["fast"] in call_args[0][0]

        assert result == "デフォルトモデルの結果"

    @pytest.mark.asyncio
    async def test_transcribe_file_not_found(self, whisper_client: WhisperClient):
        """Test transcribe with non-existent file."""
        with pytest.raises(WhisperError) as exc_info:
            await whisper_client.transcribe("/nonexistent/path/audio.wav")

        assert "not found" in str(exc_info.value).lower()

    @pytest.mark.asyncio
    async def test_transcribe_server_error(
        self, whisper_client: WhisperClient, test_audio_file: Path
    ):
        """Test transcribe when server returns error."""
        mock_response = AsyncMock()
        mock_response.status_code = 500
        mock_response.text = "Internal Server Error"

        with patch("httpx.AsyncClient.post", return_value=mock_response):
            with pytest.raises(WhisperServerError):
                await whisper_client.transcribe(str(test_audio_file))

    @pytest.mark.asyncio
    async def test_transcribe_timeout(
        self, whisper_client: WhisperClient, test_audio_file: Path
    ):
        """Test transcribe timeout handling."""
        import httpx

        with patch(
            "httpx.AsyncClient.post",
            side_effect=httpx.TimeoutException("Connection timeout"),
        ):
            with pytest.raises(WhisperTimeoutError):
                await whisper_client.transcribe(str(test_audio_file))

    @pytest.mark.asyncio
    async def test_transcribe_connection_error(
        self, whisper_client: WhisperClient, test_audio_file: Path
    ):
        """Test transcribe connection error handling."""
        import httpx

        with patch(
            "httpx.AsyncClient.post",
            side_effect=httpx.ConnectError("Connection refused"),
        ):
            with pytest.raises(WhisperError):
                await whisper_client.transcribe(str(test_audio_file))


class TestWhisperClientConfiguration:
    """Tests for WhisperClient configuration."""

    def test_servers_from_settings(self):
        """Test WhisperClient loads servers from settings."""
        from app.config import settings

        client = WhisperClient()
        assert client.servers["fast"] == settings.whisper_server_url_fast
        assert client.servers["smart"] == settings.whisper_server_url_smart

    def test_custom_timeout(self):
        """Test WhisperClient with custom timeout."""
        client = WhisperClient(timeout=120.0)
        assert client.timeout == 120.0

    def test_default_timeout(self):
        """Test WhisperClient default timeout."""
        client = WhisperClient()
        assert client.timeout == 60.0  # Default 60 seconds
