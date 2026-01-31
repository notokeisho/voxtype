"""Post-processing service for transcription results.

This service applies dictionary replacements to transcribed text,
supporting both global and user-specific dictionaries with case-insensitive matching.
"""

import re

from app.database import async_session_factory
from app.models.global_dictionary import get_global_entries
from app.models.user_dictionary import get_user_entries


async def apply_dictionary(text: str, user_id: int) -> str:
    """Apply dictionary replacements to text.

    Processing order:
    1. Get user dictionary entries (higher priority)
    2. Get global dictionary entries
    3. Apply user dictionary replacements first (case-insensitive)
    4. Apply global dictionary replacements for unmatched patterns (case-insensitive)

    Args:
        text: The text to process
        user_id: The user ID for fetching user-specific dictionary

    Returns:
        The processed text with dictionary replacements applied
    """
    if not text:
        return text

    async with async_session_factory() as session:
        # Get dictionary entries
        user_entries = await get_user_entries(session, user_id)
        global_entries = await get_global_entries(session)

        # Apply user dictionary first (higher priority)
        result = text
        applied_patterns = set()

        for entry in user_entries:
            pattern = entry.pattern
            replacement = entry.replacement
            # Case-insensitive replacement
            result = _replace_case_insensitive(result, pattern, replacement)
            applied_patterns.add(pattern.lower())

        # Apply global dictionary for patterns not covered by user dictionary
        for entry in global_entries:
            if entry.pattern.lower() not in applied_patterns:
                pattern = entry.pattern
                replacement = entry.replacement
                result = _replace_case_insensitive(result, pattern, replacement)

        return result


def _replace_case_insensitive(text: str, pattern: str, replacement: str) -> str:
    """Replace all occurrences of pattern in text (case-insensitive).

    Args:
        text: The text to process
        pattern: The pattern to find (case-insensitive)
        replacement: The replacement string

    Returns:
        The text with all occurrences replaced
    """
    if not pattern:
        return text

    # Use regex for case-insensitive replacement
    # Escape special regex characters in the pattern
    escaped_pattern = re.escape(pattern)
    regex = re.compile(escaped_pattern, re.IGNORECASE)
    return regex.sub(replacement, text)
