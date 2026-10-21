"""Measure CER and latency of whisper.cpp servers on Japanese ASR test sets."""

import argparse
import hashlib
import io
import json
import math
import re
import statistics
import subprocess
import time
import unicodedata
import wave
from dataclasses import dataclass
from datetime import UTC, datetime
from itertools import islice
from pathlib import Path

import httpx
import numpy as np
import soundfile as sf
import soxr
from datasets import Audio, load_dataset

SAMPLE_RATE = 16000

DATASETS = {
    "jsut": "japanese-asr/ja_asr.jsut_basic5000",
    "common_voice": "japanese-asr/ja_asr.common_voice_8_0",
    "reazonspeech": "japanese-asr/ja_asr.reazonspeech_test",
}

# Bumped whenever normalize() changes, so that results scored under different
# rules are not compared in the same table.
NORMALIZATION_VERSION = 1

# Characters NFKC leaves outside the Unicode punctuation categories but that
# models add or drop freely. The prolonged sound mark is a modifier letter and
# is deliberately kept, since it carries meaning in Japanese.
EXTRA_STRIPPED = "~〜"
WHITESPACE = re.compile(r"\s+")


class TranscribeError(RuntimeError):
    """The server answered, but not with a transcript this script can score."""


@dataclass
class Sample:
    index: int
    wav_path: Path
    reference: str
    duration_s: float
    audio_sha256: str


@dataclass
class Utterance:
    index: int
    reference: str
    hypothesis: str
    errors: int
    reference_length: int
    elapsed_s: float
    duration_s: float

    @property
    def cer(self) -> float:
        return self.errors / max(self.reference_length, 1)


def normalize(text: str) -> str:
    text = unicodedata.normalize("NFKC", text)
    text = WHITESPACE.sub("", text)
    return "".join(
        ch
        for ch in text
        if not unicodedata.category(ch).startswith("P") and ch not in EXTRA_STRIPPED
    )


def edit_distance(reference: str, hypothesis: str) -> int:
    previous = list(range(len(hypothesis) + 1))
    for i, ref_char in enumerate(reference, start=1):
        current = [i]
        for j, hyp_char in enumerate(hypothesis, start=1):
            cost = 0 if ref_char == hyp_char else 1
            current.append(min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost))
        previous = current
    return previous[-1]


def percentile(sorted_values: list[float], fraction: float) -> float:
    """Nearest-rank percentile: the smallest value at or above the fraction."""
    rank = max(math.ceil(fraction * len(sorted_values)), 1)
    return sorted_values[rank - 1]


def to_mono_16k(audio: np.ndarray, sample_rate: int) -> np.ndarray:
    if audio.ndim > 1:
        audio = audio.mean(axis=1)
    if sample_rate != SAMPLE_RATE:
        audio = soxr.resample(audio, sample_rate, SAMPLE_RATE)
    return np.clip(audio, -1.0, 1.0)


def decode_audio(value: dict) -> tuple[np.ndarray, int]:
    """Decode one undecoded datasets Audio value.

    Rows carry the audio inline when the dataset is stored as parquet, and only
    a path when it points at local or remote files.
    """
    data = value.get("bytes")
    if data is not None:
        return sf.read(io.BytesIO(data), dtype="float32")

    path = value.get("path")
    if path and Path(path).exists():
        return sf.read(path, dtype="float32")

    raise RuntimeError(
        f"row has neither inline audio nor a readable path (path={path!r}); "
        "this dataset cannot be read without decoding it in the datasets library"
    )


def audio_fingerprint(value: dict) -> str:
    """Identify the audio of one row, so a silent upstream swap is noticed.

    The hash covers the audio itself, not the path it came from: a file whose
    contents are replaced under the same name has to invalidate the cache.
    """
    data = value.get("bytes")
    if data is not None:
        return hashlib.sha256(data).hexdigest()

    path = value.get("path")
    if path and Path(path).exists():
        digest = hashlib.sha256()
        with open(path, "rb") as audio_file:
            for chunk in iter(lambda: audio_file.read(1024 * 1024), b""):
                digest.update(chunk)
        return digest.hexdigest()

    # Nothing identifies the audio. decode_audio rejects this row anyway.
    return hashlib.sha256(str(path).encode()).hexdigest()


def corpus_fingerprint(samples: list[Sample]) -> str:
    """Identify the exact set of utterances a measurement was taken on."""
    digest = hashlib.sha256()
    for sample in samples:
        digest.update(f"{sample.index}\x1f{sample.audio_sha256}\x1f{sample.reference}\x1e".encode())
    return digest.hexdigest()[:16]


def write_wav(path: Path, audio: np.ndarray) -> None:
    pcm = (audio * 32767.0).astype(np.int16)
    with wave.open(str(path), "wb") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(SAMPLE_RATE)
        wav_file.writeframes(pcm.tobytes())


def load_samples(dataset: str, limit: int, cache_dir: Path) -> list[Sample]:
    """Stream the first `limit` utterances and store them as 16kHz mono WAV.

    Decoding happens here rather than in the datasets library so that the
    heavyweight audio backends newer versions pull in are not needed.

    A manifest records the reference text and the hash of the source audio each
    cached WAV was written for. If either changes upstream, the stale WAV is
    replaced instead of being scored against data it does not match.
    """
    dataset_id = DATASETS.get(dataset, dataset)
    target_dir = cache_dir / dataset.replace("/", "__")
    target_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = target_dir / "manifest.json"
    manifest: dict[str, dict] = {}
    if manifest_path.exists():
        manifest = json.loads(manifest_path.read_text())

    rows = load_dataset(dataset_id, split="test", streaming=True)
    rows = rows.cast_column("audio", Audio(decode=False))

    samples: list[Sample] = []
    for index, row in enumerate(islice(rows, limit)):
        key = f"{index:04d}"
        reference = row["transcription"]
        wav_path = target_dir / f"{key}.wav"
        sha256 = audio_fingerprint(row["audio"])
        cached = manifest.get(key)
        reusable = (
            cached is not None
            and cached["reference"] == reference
            and cached.get("audio_sha256") == sha256
            and wav_path.exists()
        )

        if cached is not None and reusable:
            duration = cached["duration_s"]
        else:
            audio, sample_rate = decode_audio(row["audio"])
            audio = to_mono_16k(audio, sample_rate)
            write_wav(wav_path, audio)
            duration = len(audio) / SAMPLE_RATE
            manifest[key] = {
                "reference": reference,
                "duration_s": duration,
                "audio_sha256": sha256,
            }

        samples.append(Sample(index, wav_path, reference, duration, sha256))

    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2))
    if not samples:
        raise SystemExit(f"{dataset}: no utterances were loaded")
    return samples


def transcribe(client: httpx.Client, base_url: str, wav_path: Path) -> tuple[str, float]:
    with open(wav_path, "rb") as audio_file:
        files = {"file": (wav_path.name, audio_file, "audio/wav")}
        start = time.perf_counter()
        response = client.post(
            f"{base_url.rstrip('/')}/inference",
            files=files,
            data={"response_format": "json"},
        )
        elapsed = time.perf_counter() - start

    response.raise_for_status()
    try:
        payload = response.json()
    except ValueError as error:
        raise TranscribeError(f"response is not JSON: {response.text[:200]}") from error

    if not isinstance(payload, dict):
        raise TranscribeError(f"response is not a JSON object: {payload!r:.200}")

    # An empty transcript is a real answer and is scored as such. A missing or
    # null field is a protocol error and must not be silently counted as one.
    text = payload.get("text")
    if not isinstance(text, str):
        raise TranscribeError(f"response has no usable 'text' field: {payload}")
    return text, elapsed


def run_nvidia_smi(gpu_index: int, query: str) -> list[str] | None:
    try:
        output = subprocess.run(
            [
                "nvidia-smi",
                f"--id={gpu_index}",
                f"--query-{query}",
                "--format=csv,noheader,nounits",
            ],
            capture_output=True,
            text=True,
            check=True,
        )
    except (OSError, subprocess.CalledProcessError):
        return None
    return [line for line in output.stdout.splitlines() if line.strip()]


def read_gpu_memory(gpu_index: int) -> dict:
    """Read GPU memory. The total covers every process on the device."""
    total = run_nvidia_smi(gpu_index, "gpu=memory.used")
    processes = run_nvidia_smi(gpu_index, "compute-apps=pid,used_gpu_memory")

    per_process = []
    for line in processes or []:
        pid, _, used = line.partition(",")
        try:
            per_process.append({"pid": int(pid.strip()), "used_mb": int(used.strip())})
        except ValueError:
            continue

    return {
        "gpu_memory_total_used_mb": int(total[0]) if total else None,
        "gpu_processes": per_process,
    }


def run_target(
    label: str,
    base_url: str,
    dataset: str,
    samples: list[Sample],
    gpu_index: int,
    timeout: float,
) -> dict:
    utterances: list[Utterance] = []

    with httpx.Client(timeout=timeout) as client:
        # The model is already resident: whisper-server loads it before it
        # starts listening. This first call pays for GPU kernel setup and
        # buffer allocation instead, and is kept out of the statistics.
        _, first_inference_s = transcribe(client, base_url, samples[0].wav_path)
        gpu = read_gpu_memory(gpu_index)

        for sample in samples:
            text, elapsed = transcribe(client, base_url, sample.wav_path)
            reference = normalize(sample.reference)
            hypothesis = normalize(text)
            utterances.append(
                Utterance(
                    index=sample.index,
                    reference=reference,
                    hypothesis=hypothesis,
                    errors=edit_distance(reference, hypothesis),
                    reference_length=len(reference),
                    elapsed_s=elapsed,
                    duration_s=sample.duration_s,
                )
            )
            print(f"  {label}: {sample.index + 1}/{len(samples)}", end="\r", flush=True)

    total_errors = sum(u.errors for u in utterances)
    total_chars = sum(u.reference_length for u in utterances)
    latencies = sorted(u.elapsed_s for u in utterances)
    audio_s = sum(s.duration_s for s in samples)

    return {
        "label": label,
        "target_url": base_url,
        "dataset": dataset,
        "utterances": len(utterances),
        "corpus_fingerprint": corpus_fingerprint(samples),
        "normalization_version": NORMALIZATION_VERSION,
        "measured_at": datetime.now(UTC).isoformat(timespec="seconds"),
        "cer": total_errors / max(total_chars, 1),
        "median_latency_s": statistics.median(latencies),
        "p95_latency_s": percentile(latencies, 0.95),
        "first_inference_s": first_inference_s,
        "rtf": sum(latencies) / max(audio_s, 1e-9),
        "empty_hypotheses": sum(1 for u in utterances if not u.hypothesis),
        **gpu,
        "samples": [
            {
                "index": u.index,
                "cer": u.cer,
                "elapsed_s": u.elapsed_s,
                "duration_s": u.duration_s,
                "reference": u.reference,
                "hypothesis": u.hypothesis,
            }
            for u in utterances
        ],
    }


def parse_target(value: str) -> tuple[str, str]:
    label, separator, url = value.partition("=")
    if not separator:
        raise argparse.ArgumentTypeError("expected label=url")
    return label, url


def save_results(results: dict, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(results, ensure_ascii=False, indent=2))


def print_report(dataset: str, results: dict[str, dict]) -> None:
    measured = [r for r in results.values() if "error" not in r]
    failed = [r for r in results.values() if "error" in r]

    print(f"\n{dataset}")
    for field in ("utterances", "corpus_fingerprint", "normalization_version"):
        values = {r.get(field) for r in measured}
        if len(values) > 1:
            print(f"warning: rows differ in {field} ({sorted(map(str, values))}), not comparable")

    header = f"{'model':<24}{'CER':>8}{'median':>9}{'p95':>9}{'RTF':>8}{'GPU':>9}"
    print(header)
    print("-" * len(header))
    for result in sorted(measured, key=lambda r: r["cer"]):
        gpu = result["gpu_memory_total_used_mb"]
        print(
            f"{result['label']:<24}"
            f"{result['cer'] * 100:>7.2f}%"
            f"{result['median_latency_s']:>8.2f}s"
            f"{result['p95_latency_s']:>8.2f}s"
            f"{result['rtf']:>8.3f}"
            f"{(f'{gpu}MB' if gpu is not None else '-'):>9}"
        )

    for result in failed:
        print(f"{result['label']:<24}failed: {result['error']}")


def print_worst(result: dict, count: int) -> None:
    if "error" in result:
        return
    worst = sorted(result["samples"], key=lambda s: s["cer"], reverse=True)[:count]
    print(f"\n{result['label']}: worst {len(worst)} utterances")
    for sample in worst:
        print(f"  CER {sample['cer'] * 100:.1f}%")
        print(f"    ref: {sample['reference']}")
        print(f"    hyp: {sample['hypothesis']}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--target",
        type=parse_target,
        action="append",
        required=True,
        metavar="LABEL=URL",
        help="whisper-server to measure, e.g. turbo-q8=http://localhost:8090",
    )
    parser.add_argument(
        "--dataset",
        action="append",
        help=f"one of {', '.join(DATASETS)}, or a HuggingFace dataset id",
    )
    parser.add_argument("--limit", type=int, default=100)
    parser.add_argument("--timeout", type=float, default=300.0)
    parser.add_argument("--gpu-index", type=int, default=0)
    parser.add_argument("--worst", type=int, default=5)
    parser.add_argument("--audio-cache", type=Path, default=Path("tools/.asr_audio"))
    parser.add_argument("--out", type=Path, default=Path("tools/asr_results.json"))
    args = parser.parse_args()

    if args.limit < 1:
        raise SystemExit("--limit must be at least 1")

    datasets = args.dataset or ["jsut"]
    results: dict[str, dict] = {}
    if args.out.exists():
        results = json.loads(args.out.read_text())

    for dataset in datasets:
        print(f"loading {dataset} ({args.limit} utterances)")
        samples = load_samples(dataset, args.limit, args.audio_cache)
        measured = results.setdefault(dataset, {})

        for label, base_url in args.target:
            # Written after every target so that a later failure cannot discard
            # measurements that already cost minutes of GPU time.
            try:
                measured[label] = run_target(
                    label, base_url, dataset, samples, args.gpu_index, args.timeout
                )
            except (httpx.HTTPError, TranscribeError, OSError) as error:
                print(f"  {label}: failed: {error}")
                measured[label] = {
                    "label": label,
                    "target_url": base_url,
                    "dataset": dataset,
                    "measured_at": datetime.now(UTC).isoformat(timespec="seconds"),
                    "error": str(error),
                }
            save_results(results, args.out)

        print_report(dataset, measured)
        for label, _ in args.target:
            print_worst(measured[label], args.worst)

    print(f"\nresults written: {args.out}")


if __name__ == "__main__":
    main()
