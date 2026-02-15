"""Dictionary normalization helpers."""

import unicodedata


def normalize_dictionary_text(text: str, *, casefold: bool = True) -> str:
    """Normalize dictionary text for comparison."""
    normalized = unicodedata.normalize("NFKC", text).strip()
    if casefold:
        return normalized.casefold()
    return normalized


def normalize_dictionary_text_case_sensitive(text: str) -> str:
    """Normalize dictionary text without case folding."""
    return normalize_dictionary_text(text, casefold=False)
