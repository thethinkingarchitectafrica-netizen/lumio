"""Entry point for Lumio's backend."""

import os
from datetime import datetime, timezone

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

frontend_origins = [
    os.getenv("VERCEL_FRONTEND_URL", "https://lumio.vercel.app"),
    "http://localhost:3000",
]

app = FastAPI(title="Lumio API")
app.add_middleware(
    CORSMiddleware,
    allow_origins=[origin for origin in frontend_origins if origin],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["*"]
)


@app.get("/health", summary="Health check", tags=["Status"])
def health_check() -> dict[str, str]:
    """A public, authentication-free health endpoint."""
    now = datetime.now(timezone.utc)
    return {
        "status": "ok",
        "service": "lumio-api",
        "timestamp": now.isoformat(),
    }
