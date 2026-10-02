from urllib.parse import quote_plus

from pymongo import AsyncMongoClient

from app.core.settings import Settings


def create_mongodb_client(settings: Settings) -> AsyncMongoClient:
    username = quote_plus(settings.mongo_app_user)
    password = quote_plus(settings.mongo_app_password)
    auth_source = quote_plus(settings.mongo_db)
    uri = f"mongodb://{username}:{password}@{settings.mongodb_host}:{settings.mongo_port}/?authSource={auth_source}"
    return AsyncMongoClient(uri)
