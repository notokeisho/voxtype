"""Audio utility functions."""

import audioop
import math
import wave

FRAME_MS = 20
TOP_FRAME_RATIO = 0.1


def compute_speech_rms_wav(file_path: str) -> float | None:
    """Compute a normalized RMS representing the loudest part of a WAV file.

    The file is split into 20ms frames and the mean RMS of the loudest 10%
    of frames is returned. Taking only the loudest frames keeps long silence
    from masking speech, while averaging them still dilutes isolated
    transients such as a single click.

    Returns:
        Normalized RMS (0.0 - 1.0) or None if the file cannot be processed.
    """
    try:
        with wave.open(file_path, "rb") as wav_file:
            sample_width = wav_file.getsampwidth()
            channels = wav_file.getnchannels()
            sample_rate = wav_file.getframerate()
            frames = wav_file.readframes(wav_file.getnframes())

        if not frames:
            return 0.0

        max_possible = float(1 << (8 * sample_width - 1))
        if max_possible == 0:
            return 0.0

        samples_per_frame = max(1, round(sample_rate * FRAME_MS / 1000))
        frame_bytes = samples_per_frame * sample_width * channels

        frame_rms = [
            audioop.rms(frames[offset : offset + frame_bytes], sample_width)
            for offset in range(0, len(frames), frame_bytes)
        ]

        # Always keep at least one frame so short audio stays measurable.
        top_count = max(1, math.ceil(len(frame_rms) * TOP_FRAME_RATIO))
        loudest = sorted(frame_rms, reverse=True)[:top_count]

        return sum(loudest) / len(loudest) / max_possible
    except Exception:
        return None
