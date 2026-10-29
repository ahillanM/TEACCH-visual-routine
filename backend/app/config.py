from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_env: str = "dev"
    cors_origins: str = ""
    ai_backend_api_key: str = ""

    openrouter_api_key: str = ""
    openrouter_base_url: str = "https://openrouter.ai/api/v1"
    openrouter_model_primary: str = "google/gemma-4-31b-it:free"
    openrouter_model_fallback: str = "nvidia/nemotron-3.5-super-vl:free"
    openrouter_timeout_s: float = 60

    gladia_api_key: str = ""
    gladia_base_url: str = "https://api.gladia.io"
    gladia_model: str = "solaria-1"
    gladia_languages: str = "de,en"
    gladia_poll_timeout_s: float = 60
    gladia_poll_interval_s: float = 1

    max_audio_bytes: int = 10_000_000
    max_audio_seconds: int = 60
    max_instruction_chars: int = 2000
    default_timezone: str = "Europe/Berlin"


@lru_cache
def get_settings() -> Settings:
    return Settings()
