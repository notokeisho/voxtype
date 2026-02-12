"""Utilities for voice activity detection (VAD)."""

import array
import sys
import wave
from typing import Iterable

from silero_vad_lite import SileroVAD


def _read_wav_mono_16k_int16(file_path: str) -> array.array | None:
    try:
        with wave.open(file_path, "rb") as wav_file:
            if wav_file.getnchannels() != 1:
                return None
            if wav_file.getframerate() != 16000:
                return None
            if wav_file.getsampwidth() != 2:
                return None

            frames = wav_file.readframes(wav_file.getnframes())
    except wave.Error:
        return None

    samples = array.array("h")
    samples.frombytes(frames)
    if sys.byteorder != "little":
        samples.byteswap()
    return samples


def _iter_float_frames(
    samples: array.array, frame_samples: int
) -> Iterable[array.array]:
    total = len(samples)
    for start in range(0, total, frame_samples):
        chunk = samples[start : start + frame_samples]
        pad = frame_samples - len(chunk)
        float_chunk = array.array("f", (value / 32768.0 for value in chunk))
        if pad > 0:
            float_chunk.extend([0.0] * pad)
        yield float_chunk


def detect_speech_wav(file_path: str, speech_threshold: float) -> bool | None:
    samples = _read_wav_mono_16k_int16(file_path)
    if samples is None:
        return None

    vad = SileroVAD(sample_rate=16000)
    frame_samples = vad.window_size_samples
    for frame in _iter_float_frames(samples, frame_samples):
        score = vad.process(frame)
        if score >= speech_threshold:
            return True
    return False
