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

    # OAuth callback destinations the server is willing to redirect to.
    # The callback carries a JWT, so an unvalidated value leaks it.
    oauth_callback_allowlist: str = (
        "voxtype://callback,"
        "https://voxtype-admin.oshiruko.dev/auth/callback,"
        "http://localhost:5173/auth/callback,"
        "http://localhost:5174/auth/callback,"
        "http://localhost:5175/auth/callback,"
        "http://localhost:5176/auth/callback,"
        "http://localhost:5177/auth/callback,"
        "http://localhost:3000/auth/callback"
    )

    # Browser origins allowed to call the API with credentials.
    cors_allow_origins: str = (
        "http://localhost:5173,"
        "http://localhost:5174,"
        "http://localhost:5175,"
        "http://localhost:5176,"
        "http://localhost:5177,"
        "http://localhost:3000,"
        "https://voxtype-admin.oshiruko.dev"
    )

    @property
    def oauth_callback_list(self) -> list[str]:
        """Allowed OAuth callback URLs, parsed from the comma separated value."""
        return [item.strip() for item in self.oauth_callback_allowlist.split(",") if item.strip()]

    @property
    def cors_origin_list(self) -> list[str]:
        """Allowed CORS origins, parsed from the comma separated value."""
        return [item.strip() for item in self.cors_allow_origins.split(",") if item.strip()]

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
