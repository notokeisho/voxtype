"""Tests for the postprocess service."""

import asyncio

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.config import settings
from app.services.postprocess import apply_dictionary, remove_fillers


def run_async(coro):
    """Run async coroutine in a new event loop."""
    loop = asyncio.new_event_loop()
    try:
        return loop.run_until_complete(coro)
    finally:
        loop.close()


async def _setup_test_data(github_id: str = "postprocess_test_user"):
    """Set up test user and dictionary entries."""
    from app.models.user import User

    engine = create_async_engine(settings.database_url)
    async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as session:
        # Clean up first
        await session.execute(
            text(
                f"DELETE FROM user_dictionary WHERE user_id IN "
                f"(SELECT id FROM users WHERE github_id = '{github_id}')"
            )
        )
        await session.execute(
            text("DELETE FROM global_dictionary WHERE pattern IN ('くろーど', 'AI', 'claude')")
        )
        await session.execute(text(f"DELETE FROM users WHERE github_id = '{github_id}'"))
        await session.commit()

        # Create user
        user = User(github_id=github_id)
        session.add(user)
        await session.commit()
        await session.refresh(user)
        user_id = user.id

    await engine.dispose()
    return user_id


async def _cleanup_test_data(github_id: str = "postprocess_test_user"):
    """Clean up test data."""
    engine = create_async_engine(settings.database_url)
    async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as session:
        await session.execute(
            text(
                f"DELETE FROM user_dictionary WHERE user_id IN "
                f"(SELECT id FROM users WHERE github_id = '{github_id}')"
            )
        )
        await session.execute(
            text("DELETE FROM global_dictionary WHERE pattern IN ('くろーど', 'AI', 'claude')")
        )
        await session.execute(text(f"DELETE FROM users WHERE github_id = '{github_id}'"))
        await session.commit()

    await engine.dispose()


async def _add_global_entry(pattern: str, replacement: str):
    """Add a global dictionary entry."""
    from app.models.global_dictionary import add_global_entry

    engine = create_async_engine(settings.database_url)
    async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as session:
        await add_global_entry(session, pattern, replacement)

    await engine.dispose()


async def _add_user_entry(user_id: int, pattern: str, replacement: str):
    """Add a user dictionary entry."""
    from app.models.user_dictionary import add_user_entry

    engine = create_async_engine(settings.database_url)
    async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as session:
        await add_user_entry(session, user_id, pattern, replacement)

    await engine.dispose()


def setup_test_data(github_id: str = "postprocess_test_user") -> int:
    """Sync wrapper."""
    return run_async(_setup_test_data(github_id))


def cleanup_test_data(github_id: str = "postprocess_test_user"):
    """Sync wrapper."""
    run_async(_cleanup_test_data(github_id))


def add_global_entry(pattern: str, replacement: str):
    """Sync wrapper."""
    run_async(_add_global_entry(pattern, replacement))


def add_user_entry(user_id: int, pattern: str, replacement: str):
    """Sync wrapper."""
    run_async(_add_user_entry(user_id, pattern, replacement))


class TestGlobalDictionaryReplacement:
    """Tests for global dictionary replacement."""

    def test_global_dictionary_replacement(self):
        """Test that global dictionary entries are replaced."""
        github_id = "global_dict_test_1"
        try:
            user_id = setup_test_data(github_id)
            add_global_entry("くろーど", "Claude")

            text_input = "くろーどを使っています"
            result = run_async(apply_dictionary(text_input, user_id))

            assert result == "Claudeを使っています"
        finally:
            cleanup_test_data(github_id)

    def test_multiple_global_replacements(self):
        """Test multiple global dictionary replacements in one text."""
        github_id = "global_dict_test_2"
        try:
            user_id = setup_test_data(github_id)
            add_global_entry("くろーど", "Claude")
            add_global_entry("AI", "人工知能")

            text_input = "くろーどはAIです"
            result = run_async(apply_dictionary(text_input, user_id))

            assert "Claude" in result
            assert "人工知能" in result
        finally:
            cleanup_test_data(github_id)

    def test_no_replacement_when_no_match(self):
        """Test that text is unchanged when no patterns match."""
        github_id = "global_dict_test_3"
        try:
            user_id = setup_test_data(github_id)

            text_input = "これはテストです"
            result = run_async(apply_dictionary(text_input, user_id))

            assert result == "これはテストです"
        finally:
            cleanup_test_data(github_id)


class TestUserDictionaryPriority:
    """Tests for user dictionary priority over global dictionary."""

    def test_user_dictionary_overrides_global(self):
        """Test that user dictionary takes priority over global dictionary."""
        github_id = "user_priority_test_1"
        try:
            user_id = setup_test_data(github_id)
            # Global: AI -> 人工知能
            add_global_entry("AI", "人工知能")
            # User: AI -> AI（エーアイ）
            add_user_entry(user_id, "AI", "AI（エーアイ）")

            text_input = "AIは便利です"
            result = run_async(apply_dictionary(text_input, user_id))

            assert result == "AI（エーアイ）は便利です"
        finally:
            cleanup_test_data(github_id)

    def test_user_entry_only_affects_own_user(self):
        """Test that user dictionary entries only affect that user."""
        github_id_1 = "user_priority_test_2a"
        github_id_2 = "user_priority_test_2b"
        try:
            user_id_1 = setup_test_data(github_id_1)
            user_id_2 = setup_test_data(github_id_2)

            add_global_entry("AI", "人工知能")
            add_user_entry(user_id_1, "AI", "AI（エーアイ）")

            text_input = "AIは便利です"

            # User 1 should use their personal dictionary
            result_1 = run_async(apply_dictionary(text_input, user_id_1))
            assert result_1 == "AI（エーアイ）は便利です"

            # User 2 should use global dictionary
            result_2 = run_async(apply_dictionary(text_input, user_id_2))
            assert result_2 == "人工知能は便利です"
        finally:
            cleanup_test_data(github_id_1)
            cleanup_test_data(github_id_2)


class TestCaseInsensitiveReplacement:
    """Tests for case-insensitive replacement."""

    def test_case_insensitive_replacement(self):
        """Test that replacement is case-insensitive."""
        github_id = "case_test_1"
        try:
            user_id = setup_test_data(github_id)
            add_global_entry("claude", "Claude")

            # Uppercase input should still be replaced
            text_input = "CLAUDEを使っています"
            result = run_async(apply_dictionary(text_input, user_id))

            assert result == "Claudeを使っています"
        finally:
            cleanup_test_data(github_id)

    def test_mixed_case_replacement(self):
        """Test replacement with mixed case input."""
        github_id = "case_test_2"
        try:
            user_id = setup_test_data(github_id)
            add_global_entry("claude", "Claude")

            text_input = "ClAuDeを使っています"
            result = run_async(apply_dictionary(text_input, user_id))

            assert result == "Claudeを使っています"
        finally:
            cleanup_test_data(github_id)


class TestEmptyAndEdgeCases:
    """Tests for empty and edge cases."""

    def test_empty_text(self):
        """Test with empty text input."""
        github_id = "edge_test_1"
        try:
            user_id = setup_test_data(github_id)

            result = run_async(apply_dictionary("", user_id))

            assert result == ""
        finally:
            cleanup_test_data(github_id)

    def test_text_with_only_whitespace(self):
        """Test with whitespace-only text."""
        github_id = "edge_test_2"
        try:
            user_id = setup_test_data(github_id)

            result = run_async(apply_dictionary("   ", user_id))

            assert result == "   "
        finally:
            cleanup_test_data(github_id)

    def test_pattern_appears_multiple_times(self):
        """Test when pattern appears multiple times."""
        github_id = "edge_test_3"
        try:
            user_id = setup_test_data(github_id)
            add_global_entry("AI", "人工知能")

            text_input = "AIとAIとAI"
            result = run_async(apply_dictionary(text_input, user_id))

            assert result == "人工知能と人工知能と人工知能"
        finally:
            cleanup_test_data(github_id)


class TestFillerRemoval:
    """Tests for Japanese filler word removal."""

    def test_remove_single_filler(self):
        """Test removal of a single filler word."""
        assert remove_fillers("えーとこんにちは") == "こんにちは"
        assert remove_fillers("えっとテストです") == "テストです"
        assert remove_fillers("ええとわかりました") == "わかりました"

    def test_remove_multiple_fillers(self):
        """Test removal of multiple filler words."""
        assert remove_fillers("えーとまあテストです") == "テストです"
        assert remove_fillers("なんかえーとうーん") == ""

    def test_filler_with_long_vowel(self):
        """Test removal of fillers with long vowels."""
        assert remove_fillers("あのーテストです") == "テストです"
        assert remove_fillers("うーん難しいですね") == "難しいですね"

    def test_maa_filler(self):
        """Test removal of まあ/まぁ filler."""
        assert remove_fillers("まあいいでしょう") == "いいでしょう"
        assert remove_fillers("まぁそうですね") == "そうですね"

    def test_nanka_filler(self):
        """Test removal of なんか filler."""
        assert remove_fillers("なんかよくわからない") == "よくわからない"

    def test_safe_words_not_removed(self):
        """Test that safe words containing filler patterns are not affected."""
        # あの without long vowel should NOT be removed (excluded from list)
        assert remove_fillers("あの人が来ました") == "あの人が来ました"
        # その should NOT be removed (excluded from list)
        assert remove_fillers("その通りです") == "その通りです"
        # こう should NOT be removed (excluded from list)
        assert remove_fillers("こういうことです") == "こういうことです"

    def test_empty_text(self):
        """Test with empty text."""
        assert remove_fillers("") == ""
        assert remove_fillers(None) is None

    def test_whitespace_normalization(self):
        """Test that multiple spaces are normalized to single space."""
        assert remove_fillers("えーと  テストです") == "テストです"
        assert remove_fillers("まあ   いいでしょう") == "いいでしょう"

    def test_filler_removal_in_apply_dictionary(self):
        """Test that fillers are removed before dictionary replacement."""
        github_id = "filler_dict_test_1"
        try:
            user_id = setup_test_data(github_id)
            add_global_entry("テスト", "test")

            # Filler should be removed, then dictionary applied
            text_input = "えーとテストです"
            result = run_async(apply_dictionary(text_input, user_id))

            assert "えーと" not in result
            assert "test" in result
        finally:
            cleanup_test_data(github_id)
