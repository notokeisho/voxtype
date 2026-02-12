"""Application configuration."""

import os
from pathlib import Path

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # Application
    app_name: str = "VoxType"
    debug: bool = False

    # Database
    database_url: str = "postgresql+asyncpg://voice:password@localhost:5434/voice_server"

    # Whisper Server
    whisper_server_url_fast: str = "http://localhost:8080"
    whisper_server_url_smart: str = "http://localhost:8081"
    rms_check_enabled: bool = True
    rms_silence_threshold: float = 0.005
    vad_enabled: bool = True
    vad_speech_threshold: float = 0.3
    voice_language: str = "ja"

    # JWT
    jwt_secret: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"
    jwt_expire_days: int = 7

    # GitHub OAuth
    github_client_id: str = ""
    github_client_secret: str = ""

    # Initial admin (optional, for bootstrapping)
    initial_admin_github_id: str | None = None
    initial_admin_github_username: str | None = None

    _default_env = Path(__file__).resolve().parents[2] / ".env"
    _env_file = Path(os.environ.get("ENV_FILE", str(_default_env)))

    model_config = {
        "env_file": str(_env_file),
        "env_file_encoding": "utf-8",
        "extra": "ignore",
    }


settings = Settings()
