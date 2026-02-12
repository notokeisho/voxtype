import argparse
import time
import wave
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import numpy as np


@dataclass
class BenchmarkResult:
    name: str
    total_ms: float
    frames: int


def read_wav_mono_16k(path: Path) -> np.ndarray:
    with wave.open(str(path), "rb") as wav_file:
        if wav_file.getnchannels() != 1:
            raise ValueError("Only mono WAV is supported")
        if wav_file.getframerate() != 16000:
            raise ValueError("Only 16kHz WAV is supported")
        if wav_file.getsampwidth() != 2:
            raise ValueError("Only 16-bit PCM WAV is supported")

        frames = wav_file.readframes(wav_file.getnframes())
        samples = np.frombuffer(frames, dtype=np.int16).astype(np.float32)
        return samples / 32768.0


def iter_frames(samples: np.ndarray, frame_samples: int) -> Iterable[np.ndarray]:
    total = len(samples)
    for start in range(0, total, frame_samples):
        chunk = samples[start : start + frame_samples]
        if len(chunk) < frame_samples:
            pad = np.zeros(frame_samples - len(chunk), dtype=np.float32)
            chunk = np.concatenate([chunk, pad])
        yield chunk


def bench_silero_vad_lite(samples: np.ndarray, frame_ms: int) -> BenchmarkResult:
    from silero_vad_lite import SileroVAD

    if frame_ms != 32:
        raise ValueError("silero-vad-lite requires 32ms frames")

    vad = SileroVAD(sample_rate=16000)
    frame_samples = vad.window_size_samples()
    frames = 0

    start = time.perf_counter()
    for chunk in iter_frames(samples, frame_samples):
        chunk = np.ascontiguousarray(chunk, dtype=np.float32)
        _ = vad.process(np.ctypeslib.as_ctypes(chunk))
        frames += 1
    total_ms = (time.perf_counter() - start) * 1000.0
    return BenchmarkResult("silero-vad-lite", total_ms, frames)


def bench_silero_vad(samples: np.ndarray, frame_ms: int) -> BenchmarkResult:
    import torch

    model, utils = torch.hub.load(
        repo_or_dir="snakers4/silero-vad",
        model="silero_vad",
        force_reload=False,
        onnx=True,
    )
    get_speech_timestamps = utils[0]

    frame_samples = int(16000 * frame_ms / 1000)
    frames = 0

    start = time.perf_counter()
    for chunk in iter_frames(samples, frame_samples):
        tensor = torch.from_numpy(chunk)
        _ = get_speech_timestamps(tensor, model, sampling_rate=16000)
        frames += 1
    total_ms = (time.perf_counter() - start) * 1000.0
    return BenchmarkResult("silero-vad", total_ms, frames)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("wav", type=Path, help="Path to 16kHz mono WAV")
    parser.add_argument("--frame-ms", type=int, default=32, choices=[10, 20, 30, 32])
    parser.add_argument("--skip-silero", action="store_true")
    parser.add_argument("--skip-lite", action="store_true")
    args = parser.parse_args()

    samples = read_wav_mono_16k(args.wav)
    results: list[BenchmarkResult] = []

    if not args.skip_lite:
        results.append(bench_silero_vad_lite(samples, args.frame_ms))
    if not args.skip_silero:
        results.append(bench_silero_vad(samples, args.frame_ms))

    for result in results:
        print(
            f"{result.name}: {result.total_ms:.2f} ms total "
            f"({result.frames} frames, {result.total_ms / max(result.frames, 1):.3f} ms/frame)"
        )


if __name__ == "__main__":
    main()
