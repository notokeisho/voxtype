"""Audio transcription API endpoint."""

import tempfile
import uuid
from enum import Enum
from pathlib import Path
from fastapi import APIRouter, Depends, Form, HTTPException, UploadFile, status

from app.auth.dependencies import get_current_user
from app.config import settings
from app.models.user import User
from app.services.postprocess import apply_dictionary
from app.services.audio_utils import compute_rms_wav
from app.services.vad_utils import detect_speech_wav
from app.services.whisper_client import WhisperError, whisper_client

router = APIRouter(prefix="/api", tags=["transcribe"])


class WhisperModel(str, Enum):
    """Available Whisper models for transcription."""

    FAST = "fast"
    SMART = "smart"

# Temporary directory for audio files
TEMP_DIR = Path(tempfile.gettempdir()) / "voxtype"


def ensure_temp_dir():
    """Ensure the temporary directory exists."""
    TEMP_DIR.mkdir(parents=True, exist_ok=True)


@router.post("/transcribe")
async def transcribe_audio(
    audio: UploadFile,
    model: WhisperModel = Form(default=WhisperModel.FAST),
    vad_speech_threshold: float | None = Form(default=None),
    current_user: User = Depends(get_current_user),
):
    """Transcribe an audio file to text.

    This endpoint accepts an audio file, sends it to the whisper server
    for transcription, and applies dictionary replacements.

    Args:
        audio: The audio file to transcribe (WAV format recommended)
        model: Whisper model to use ("fast" or "smart"). Defaults to "fast".
        current_user: The authenticated user

    Returns:
        JSON with transcribed text (raw and processed)

    Raises:
        HTTPException: 500 if transcription fails
    """
    ensure_temp_dir()

    # Generate unique filename for temp file
    file_ext = Path(audio.filename or "audio.wav").suffix or ".wav"
    temp_filename = f"{uuid.uuid4()}{file_ext}"
    temp_path = TEMP_DIR / temp_filename

    try:
        # Save uploaded file to temp location
        content = await audio.read()
        temp_path.write_bytes(content)

        if settings.rms_check_enabled:
            rms_value = compute_rms_wav(str(temp_path))
            if rms_value is not None and rms_value < settings.rms_silence_threshold:
                return {
                    "text": "",
                    "raw_text": "",
                }

        effective_vad_threshold = (
            settings.vad_speech_threshold if vad_speech_threshold is None else vad_speech_threshold
        )
        if settings.vad_enabled and effective_vad_threshold > 0:
            vad_result = detect_speech_wav(
                str(temp_path), effective_vad_threshold
            )
            if vad_result is False:
                return {
                    "text": "",
                    "raw_text": "",
                }

        # Transcribe audio
        try:
            raw_text = await whisper_client.transcribe(str(temp_path), model=model.value)
        except WhisperError as e:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Transcription failed: {e}",
            ) from e

        # Apply dictionary replacements
        processed_text = await apply_dictionary(raw_text, current_user.id)

        return {
            "text": processed_text,
            "raw_text": raw_text,
        }

    finally:
        # Always clean up temp file
        if temp_path.exists():
            try:
                temp_path.unlink()
            except OSError:
                pass  # Ignore cleanup errors
