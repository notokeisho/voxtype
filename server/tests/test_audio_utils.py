"""Tests for audio utility functions."""

import math
import wave
from array import array
from pathlib import Path

from app.services.audio_utils import compute_speech_rms_wav

SAMPLE_RATE = 16000


def write_wav(path: Path, samples: list[int], sample_rate: int = SAMPLE_RATE) -> None:
    """Write 16-bit mono WAV file."""
    with wave.open(str(path), "wb") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        wav_file.writeframes(array("h", samples).tobytes())


def tone(duration_sec: float, amplitude: int, sample_rate: int = SAMPLE_RATE) -> list[int]:
    """Generate a 440Hz sine wave."""
    count = int(duration_sec * sample_rate)
    return [
        int(amplitude * math.sin(2 * math.pi * 440 * i / sample_rate))
        for i in range(count)
    ]


def silence(duration_sec: float, sample_rate: int = SAMPLE_RATE) -> list[int]:
    """Generate silence."""
    return [0] * int(duration_sec * sample_rate)


def test_silence_returns_zero(tmp_path: Path):
    """Silence should result in zero RMS."""
    path = tmp_path / "silence.wav"
    write_wav(path, silence(0.1))

    assert compute_speech_rms_wav(str(path)) == 0.0


def test_tone_returns_non_zero(tmp_path: Path):
    """Tone should result in non-zero RMS."""
    path = tmp_path / "tone.wav"
    write_wav(path, tone(0.1, 10000))

    rms = compute_speech_rms_wav(str(path))

    assert rms is not None
    assert rms > 0.01


def test_long_silence_does_not_mask_quiet_speech(tmp_path: Path):
    """Speech frames should dominate even when most of the file is silent.

    Whole-file RMS for this input is about 0.0044, which falls below the
    0.005 silence threshold. Top-10% frame averaging must keep it above.
    """
    path = tmp_path / "quiet_speech.wav"
    write_wav(path, tone(1.0, 500) + silence(5.0))

    rms = compute_speech_rms_wav(str(path))

    assert rms is not None
    assert rms > 0.005


def test_speech_position_does_not_change_result(tmp_path: Path):
    """Frame ordering must not matter: only the loudest frames count."""
    head = tmp_path / "head.wav"
    tail = tmp_path / "tail.wav"
    write_wav(head, tone(1.0, 500) + silence(5.0))
    write_wav(tail, silence(5.0) + tone(1.0, 500))

    assert compute_speech_rms_wav(str(head)) == compute_speech_rms_wav(str(tail))


def test_single_transient_is_treated_as_silence(tmp_path: Path):
    """A lone 20ms click in a long recording must not pass the threshold.

    Averaging over the top 10% of frames dilutes a single loud frame, which
    is what keeps click noise from reaching Whisper when VAD is disabled.
    The dilution scales with the recording length, so this uses the 60s
    length that auto-stop produces.
    """
    path = tmp_path / "click.wav"
    write_wav(path, tone(0.02, 20000) + silence(59.98))

    rms = compute_speech_rms_wav(str(path))

    assert rms is not None
    assert rms < 0.005


def test_audio_shorter_than_one_frame_uses_at_least_one_frame(tmp_path: Path):
    """Audio below 20ms must still yield a representative value."""
    path = tmp_path / "short.wav"
    write_wav(path, tone(0.005, 10000))

    rms = compute_speech_rms_wav(str(path))

    assert rms is not None
    assert rms > 0.01


def test_empty_audio_returns_zero(tmp_path: Path):
    """Empty WAV should be treated as silence."""
    path = tmp_path / "empty.wav"
    write_wav(path, [])

    assert compute_speech_rms_wav(str(path)) == 0.0


def test_invalid_file_returns_none(tmp_path: Path):
    """Unreadable input keeps the existing None contract."""
    path = tmp_path / "broken.wav"
    path.write_bytes(b"not a wav file")

    assert compute_speech_rms_wav(str(path)) is None
