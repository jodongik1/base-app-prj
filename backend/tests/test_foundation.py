import asyncio
import unittest
from types import SimpleNamespace
from unittest.mock import patch

from app.api.health import health
from app.core.settings import Settings
from app.infrastructure.mongodb.client import create_mongodb_client
from app.infrastructure.redis.client import create_redis_client


class FoundationTests(unittest.TestCase):
    def test_backend_settings_do_not_require_mongodb_root_credentials(self):
        settings = Settings(
            _env_file=None,
            postgres_port=5432,
            postgres_user="app",
            postgres_password="secret",
            postgres_db="app",
            mongo_port=27017,
            mongo_app_user="app",
            mongo_app_password="secret",
            mongo_db="app",
            redis_port=6379,
            redis_password="secret",
            backend_port=8000,
            host_bind_ip="127.0.0.1",
        )
        self.assertEqual(settings.mongo_app_user, "app")

    def test_health_response(self):
        self.assertEqual(asyncio.run(health()), {"status": "ok"})

    def test_mongodb_uses_app_user_and_database_for_authentication(self):
        settings = SimpleNamespace(
            mongo_app_user="app-user",
            mongo_app_password="app:p@ss",
            mongo_root_user="root-user",
            mongo_root_password="root-secret",
            mongodb_host="mongodb",
            mongo_port=27017,
            mongo_db="myapp",
        )
        with patch("app.infrastructure.mongodb.client.AsyncMongoClient") as client:
            create_mongodb_client(settings)

        uri = client.call_args.args[0]
        self.assertIn("app-user:app%3Ap%40ss@mongodb:27017", uri)
        self.assertIn("authSource=myapp", uri)
        self.assertNotIn("root-secret", uri)

    def test_redis_uses_password(self):
        settings = SimpleNamespace(redis_host="redis", redis_port=6379, redis_password="secret")
        with patch("app.infrastructure.redis.client.Redis") as client:
            create_redis_client(settings)

        self.assertEqual(client.call_args.kwargs["password"], "secret")


if __name__ == "__main__":
    unittest.main()
