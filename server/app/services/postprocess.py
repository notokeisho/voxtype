"""Post-processing service for transcription results.

This service applies dictionary replacements to transcribed text,
supporting both global and user-specific dictionaries with case-insensitive matching.
It also removes Japanese filler words for cleaner output.
"""

import re

from app.config import settings
from app.database import async_session_factory
from app.models.global_dictionary import get_global_entries
from app.models.user_dictionary import get_user_entries

# Whisper non-speech annotation patterns to remove
# These are added by Whisper when it detects background sounds
WHISPER_ANNOTATIONS = re.compile(
    r'[（(]'  # Opening bracket (Japanese or ASCII)
    r'(?:音楽?|エンディング|拍手|笑い?|笑声|咳|ため息|'
    r'沈黙|雑音|ノイズ|BGM|SE|効果音|歌|'
    r'music|applause|laughter|cough|sigh|silence|noise|sound)'
    r'[）)]',  # Closing bracket (Japanese or ASCII)
    re.IGNORECASE
)


# Japanese filler words to remove (safe patterns only)
# Excluded: あの, その, こう, うん, ほら, ね, さ (may break words like あの人, その通り, こういう)
JAPANESE_FILLERS = [
    "えーと", "えっと", "ええと",
    "あのー",
    "うーん",
    "えー", "ええ",
    "まあ", "まぁ",
    "なんか",
]


def remove_whisper_annotations(text: str) -> str:
    """Remove Whisper non-speech annotations from text.

    Whisper adds annotations like (音楽), (エンディング), (拍手) when it
    detects background sounds. This function removes them.

    Args:
        text: The text to process

    Returns:
        The text with Whisper annotations removed
    """
    if not text:
        return text

    result = WHISPER_ANNOTATIONS.sub('', text)
    # Clean up extra whitespace that may result from removal
    result = re.sub(r'\s+', ' ', result).strip()
    return result


def clean_punctuation(text: str) -> str:
    """Clean up unnatural punctuation patterns caused by silence detection.

    Whisper may interpret silence as punctuation when guided by a prompt.
    This function removes such artifacts while preserving newlines from
    dictionary replacements.

    Args:
        text: The text to process

    Returns:
        The text with unnatural punctuation patterns cleaned
    """
    if not text:
        return text

    result = text

    # === Consecutive punctuation normalization ===
    # 。。→。, 、、→、
    result = re.sub(r'。+', '。', result)
    result = re.sub(r'、+', '、', result)

    # ??→?, ？？→？ (consecutive question marks)
    result = re.sub(r'\?+', '?', result)
    result = re.sub(r'？+', '？', result)

    # === Mixed punctuation patterns ===
    # 。、→。, 、。→。 (period takes precedence)
    result = re.sub(r'[。、]+。', '。', result)
    result = re.sub(r'。[。、]+', '。', result)
    result = re.sub(r'、。', '。', result)

    # 。?→。, 、?→、 (punctuation + question mark → punctuation)
    result = re.sub(r'。[?？]+', '。', result)
    result = re.sub(r'、[?？]+', '、', result)

    # ?。→。, ?、→、 (question mark + punctuation → punctuation)
    result = re.sub(r'[?？]+。', '。', result)
    result = re.sub(r'[?？]+、', '、', result)

    # === Newline handling (preserve newlines, remove punctuation after them) ===
    # \n。→\n, \n、→\n, \n?→\n (actual newline character)
    result = re.sub(r'\n[。、?？]+', '\n', result)

    # \\n。→\\n (literal backslash-n string from dictionary)
    result = re.sub(r'\\n[。、?？]+', r'\\n', result)

    # === Special character handling ===
    # #。→#, -、→- (punctuation after special chars)
    result = re.sub(r'([#\-\*])([。、，．?？]+)', r'\1', result)

    # 、#→#, ?-→- (punctuation before special chars)
    result = re.sub(r'([。、，．?？]+)([#\-\*])', r'\2', result)

    # === Leading/trailing cleanup ===
    # Remove leading punctuation at start of text
    result = re.sub(r'^[\s\u3000。、．，・?？]+', '', result)

    # Remove standalone punctuation (just punctuation with nothing meaningful)
    result = re.sub(r'^[。、?？]+$', '', result)

    # Remove punctuation-only segments (spaces around lone punctuation)
    result = re.sub(r'\s+[。、?？]\s+', ' ', result)

    # === Whitespace normalization (preserve newlines) ===
    # Use [^\S\n]+ to match whitespace except newlines
    result = re.sub(r'[^\S\n]+', ' ', result).strip()

    # Remove spaces after Japanese punctuation
    result = re.sub(r'([。？！])\s+', r'\1', result)

    # Normalize question mark for Japanese output
    if settings.voice_language.lower() == "ja":
        result = result.replace("?", "？")

    return result


def remove_fillers(text: str) -> str:
    """Remove Japanese filler words from text.

    Args:
        text: The text to process

    Returns:
        The text with filler words removed
    """
    if not text:
        return text

    result = text

    # Remove filler words (with optional trailing comma/space)
    for filler in JAPANESE_FILLERS:
        # Remove filler followed by comma and optional space
        result = result.replace(filler + "、", "")
        result = result.replace(filler + "，", "")
        # Remove filler alone
        result = result.replace(filler, "")

    # Remove leading punctuation
    result = re.sub(r'^[、，\s]+', '', result)

    # Normalize whitespace (multiple spaces to single space)
    result = re.sub(r'\s+', ' ', result).strip()
    return result


async def apply_dictionary(text: str, user_id: int) -> str:
    """Apply dictionary replacements to text.

    Processing order:
    1. Remove Whisper annotations (音楽) etc. - before dictionary, no newlines yet
    2. Remove filler words (えーと) etc. - before dictionary, no newlines yet
    3. Apply dictionary replacements (user first, then global)
    4. Clean punctuation - after dictionary, newlines may exist from dictionary

    Note: clean_punctuation is called only once, after dictionary replacements,
    because newlines (\n) are generated by dictionary replacements and need
    to be preserved during punctuation cleanup.

    Args:
        text: The text to process
        user_id: The user ID for fetching user-specific dictionary

    Returns:
        The processed text with dictionary replacements applied
    """
    if not text:
        return text

    # Step 1: Remove Whisper annotations (音楽), (エンディング) etc.
    # Note: No newlines exist at this point, so \s+ is safe here
    result = remove_whisper_annotations(text)

    # Step 2: Remove filler words (えーと, あのー, etc.)
    # Note: No newlines exist at this point, so \s+ is safe here
    result = remove_fillers(result)

    # Step 3: Apply dictionary replacements
    async with async_session_factory() as session:
        user_entries = await get_user_entries(session, user_id)
        global_entries = await get_global_entries(session)

        # Apply user dictionary first (higher priority)
        applied_patterns = set()

        for entry in user_entries:
            pattern = entry.pattern
            replacement = entry.replacement
            result = _replace_case_insensitive(result, pattern, replacement)
            applied_patterns.add(pattern.lower())

        # Apply global dictionary for patterns not covered by user dictionary
        for entry in global_entries:
            if entry.pattern.lower() not in applied_patterns:
                pattern = entry.pattern
                replacement = entry.replacement
                result = _replace_case_insensitive(result, pattern, replacement)

    # Step 4: Clean punctuation (only once, after dictionary replacements)
    # Newlines from dictionary (e.g., カッパ→\n) are preserved here
    result = clean_punctuation(result)

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
