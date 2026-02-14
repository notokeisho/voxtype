"""Dictionary normalization helpers."""

import unicodedata


def normalize_dictionary_text(text: str) -> str:
    """Normalize dictionary text for comparison."""
    return unicodedata.normalize("NFKC", text).casefold().strip()
