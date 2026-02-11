"""Audio utility functions."""

import audioop
import wave


def compute_rms_wav(file_path: str) -> float | None:
    """Compute normalized RMS for a WAV file.

    Returns:
        Normalized RMS (0.0 - 1.0) or None if the file cannot be processed.
    """
    try:
        with wave.open(file_path, "rb") as wav_file:
            frames = wav_file.readframes(wav_file.getnframes())
            if not frames:
                return 0.0

            sample_width = wav_file.getsampwidth()
            rms = audioop.rms(frames, sample_width)
            max_possible = float(1 << (8 * sample_width - 1))
            if max_possible == 0:
                return 0.0

            return rms / max_possible
    except Exception:
        return None
