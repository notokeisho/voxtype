"""Whisper.cpp server client for audio transcription."""

from pathlib import Path

import httpx

from app.config import settings


class WhisperError(Exception):
    """Base exception for whisper client errors."""

    pass


class WhisperServerError(WhisperError):
    """Raised when whisper server returns an error response."""

    pass


class WhisperTimeoutError(WhisperError):
    """Raised when whisper server request times out."""

    pass


class WhisperClient:
    """HTTP client for whisper.cpp server.

    This client communicates with a whisper.cpp server to transcribe
    audio files to text. Supports multiple models (fast/smart).
    """

    def __init__(self, timeout: float = 60.0):
        """Initialize WhisperClient.

        Args:
            timeout: Request timeout in seconds. Defaults to 60.
        """
        self.servers = {
            "fast": settings.whisper_server_url_fast,
            "smart": settings.whisper_server_url_smart,
        }
        self.timeout = timeout

    def _get_base_url(self, model: str) -> str:
        """Get the base URL for the specified model.

        Args:
            model: Model name ("fast" or "smart").

        Returns:
            The base URL for the model server.
        """
        return self.servers.get(model, self.servers["fast"])

    async def transcribe(self, audio_path: str, model: str = "fast") -> str:
        """Transcribe an audio file to text.

        Args:
            audio_path: Path to the audio file to transcribe.
            model: Model to use ("fast" or "smart"). Defaults to "fast".

        Returns:
            The transcribed text.

        Raises:
            WhisperError: If the file is not found or connection fails.
            WhisperServerError: If the server returns an error response.
            WhisperTimeoutError: If the request times out.
        """
        base_url = self._get_base_url(model)
        # Check if file exists
        path = Path(audio_path)
        if not path.exists():
            raise WhisperError(f"Audio file not found: {audio_path}")

        # Read file and send to whisper server
        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                with open(audio_path, "rb") as f:
                    files = {"file": (path.name, f, "audio/wav")}
                    response = await client.post(
                        f"{base_url}/inference",
                        files=files,
                        data={"response_format": "json"},
                    )

                if response.status_code != 200:
                    raise WhisperServerError(
                        f"Whisper server error: {response.status_code} - {response.text}"
                    )

                result = response.json()
                return result.get("text", "")

        except httpx.TimeoutException as e:
            raise WhisperTimeoutError(f"Whisper server timeout: {e}") from e
        except httpx.ConnectError as e:
            raise WhisperError(f"Failed to connect to whisper server: {e}") from e
        except httpx.HTTPError as e:
            raise WhisperError(f"HTTP error: {e}") from e

    async def health_check(self, model: str = "fast") -> bool:
        """Check if the whisper server is healthy.

        Args:
            model: Model to check ("fast" or "smart"). Defaults to "fast".

        Returns:
            True if the server is reachable, False otherwise.
        """
        base_url = self._get_base_url(model)
        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                response = await client.get(f"{base_url}/health")
                return response.status_code == 200
        except Exception:
            return False


# Default client instance
whisper_client = WhisperClient()
