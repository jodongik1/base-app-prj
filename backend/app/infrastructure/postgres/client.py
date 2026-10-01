from sqlalchemy.engine import URL
from sqlalchemy.ext.asyncio import AsyncEngine, create_async_engine

from app.core.settings import Settings


def create_postgres_engine(settings: Settings) -> AsyncEngine:
    url = URL.create(
        "postgresql+asyncpg",
        username=settings.postgres_user,
        password=settings.postgres_password,
        host=settings.postgres_host,
        port=settings.postgres_port,
        database=settings.postgres_db,
    )
    return create_async_engine(url, pool_pre_ping=True)
