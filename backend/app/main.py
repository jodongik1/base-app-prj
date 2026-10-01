from contextlib import asynccontextmanager

from fastapi import FastAPI
from sqlalchemy import text

from app.api.health import router as health_router
from app.core.settings import get_settings
from app.infrastructure.mongodb.client import create_mongodb_client
from app.infrastructure.postgres.client import create_postgres_engine
from app.infrastructure.redis.client import create_redis_client


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    postgres = create_postgres_engine(settings)
    mongodb = create_mongodb_client(settings)
    redis = create_redis_client(settings)

    try:
        async with postgres.connect() as connection:
            await connection.execute(text("SELECT 1"))
        await mongodb.admin.command("ping")
        await redis.ping()

        app.state.postgres = postgres
        app.state.mongodb = mongodb
        app.state.redis = redis
        yield
    finally:
        await redis.aclose()
        await mongodb.close()
        await postgres.dispose()


app = FastAPI(title="Base App API", lifespan=lifespan)
app.include_router(health_router)
