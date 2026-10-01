from redis.asyncio import Redis

from app.core.settings import Settings


def create_redis_client(settings: Settings) -> Redis:
    return Redis(host=settings.redis_host, port=settings.redis_port, decode_responses=True)
