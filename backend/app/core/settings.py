from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        extra="ignore",
        env_file=Path(__file__).resolve().parents[3] / ".env",
        env_file_encoding="utf-8",
    )

    postgres_host: str = "localhost"
    postgres_port: int
    postgres_user: str
    postgres_password: str
    postgres_db: str
    mongodb_host: str = "localhost"
    mongo_port: int
    mongo_root_user: str
    mongo_root_password: str
    mongo_auth_source: str
    mongo_db: str
    redis_host: str = "localhost"
    redis_port: int
    backend_port: int
    host_bind_ip: str


@lru_cache
def get_settings() -> Settings:
    return Settings()
