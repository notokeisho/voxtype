"""Tests for audio utility functions."""

import math
import wave
from pathlib import Path

from app.services.audio_utils import compute_rms_wav


def write_wav(path: Path, samples: list[int], sample_rate: int = 16000) -> None:
    """Write 16-bit mono WAV file."""
    with wave.open(str(path), "wb") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        frames = b"".join(int(s).to_bytes(2, "little", signed=True) for s in samples)
        wav_file.writeframes(frames)


def test_compute_rms_wav_silence(tmp_path: Path):
    """Silence should result in near-zero RMS."""
    path = tmp_path / "silence.wav"
    write_wav(path, [0] * 1600)

    rms = compute_rms_wav(str(path))

    assert rms is not None
    assert rms == 0.0


def test_compute_rms_wav_tone(tmp_path: Path):
    """Tone should result in non-zero RMS."""
    path = tmp_path / "tone.wav"
    samples = [
        int(10000 * math.sin(2 * math.pi * 440 * i / 16000))
        for i in range(1600)
    ]
    write_wav(path, samples)

    rms = compute_rms_wav(str(path))

    assert rms is not None
    assert rms > 0.01
