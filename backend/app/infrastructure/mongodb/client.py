from urllib.parse import quote_plus

from pymongo import AsyncMongoClient

from app.core.settings import Settings


def create_mongodb_client(settings: Settings) -> AsyncMongoClient:
    username = quote_plus(settings.mongo_root_user)
    password = quote_plus(settings.mongo_root_password)
    uri = f"mongodb://{username}:{password}@{settings.mongodb_host}:{settings.mongo_port}/?authSource={settings.mongo_auth_source}"
    return AsyncMongoClient(uri)
