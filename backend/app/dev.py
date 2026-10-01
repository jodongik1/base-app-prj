"""Run the local API with the port from the root .env file."""

import uvicorn

from app.core.settings import get_settings

if __name__ == "__main__":
    settings = get_settings()
    uvicorn.run(
        "app.main:app",
        host=settings.host_bind_ip,
        port=settings.backend_port,
        reload=True,
    )
