"""Tests for VAD utilities."""

import wave
from pathlib import Path
from unittest.mock import patch

from app.services import vad_utils


def _write_wav(path: Path, channels: int = 1, sample_rate: int = 16000) -> None:
    with wave.open(str(path), "wb") as wav_file:
        wav_file.setnchannels(channels)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        wav_file.writeframes(b"\x00\x00" * 160)


def test_detect_speech_wav_returns_none_for_invalid_format(tmp_path: Path):
    path = tmp_path / "stereo.wav"
    _write_wav(path, channels=2)

    assert vad_utils.detect_speech_wav(str(path), 0.3) is None


def test_detect_speech_wav_returns_true_when_frame_exceeds_threshold(tmp_path: Path):
    path = tmp_path / "mono.wav"
    _write_wav(path)

    class FakeVAD:
        def __init__(self, sample_rate: int):
            self.window_size_samples = 32

        def process(self, _frame):
            return 0.4

    with patch("app.services.vad_utils.SileroVAD", FakeVAD):
        assert vad_utils.detect_speech_wav(str(path), 0.3) is True


def test_detect_speech_wav_returns_false_when_no_frame_exceeds_threshold(
    tmp_path: Path,
):
    path = tmp_path / "mono.wav"
    _write_wav(path)

    class FakeVAD:
        def __init__(self, sample_rate: int):
            self.window_size_samples = 32

        def process(self, _frame):
            return 0.1

    with patch("app.services.vad_utils.SileroVAD", FakeVAD):
        assert vad_utils.detect_speech_wav(str(path), 0.3) is False
