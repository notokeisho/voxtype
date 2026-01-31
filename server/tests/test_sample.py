"""Sample tests to verify pytest setup."""


def test_sample():
    """Simple test to verify pytest is working."""
    assert 1 + 1 == 2


def test_sample_fixture(sample_audio_content: bytes):
    """Test that fixtures work."""
    # WAV files start with RIFF header
    assert sample_audio_content[:4] == b"RIFF"
