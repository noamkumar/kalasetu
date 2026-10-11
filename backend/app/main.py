import os
import uuid
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from starlette.middleware.base import BaseHTTPMiddleware

from app.config import get_settings
from app.db.base import Base
from app.db.session import engine, run_startup_migrations, SessionLocal
from app.services.demo_seeder import seed_demo_data
from app.routers import (
    auth, products, orders, media, sync, catalog, images, pricing,
    assistant, analytics, voice, marketplace, notifications
)

settings = get_settings()

def get_allowed_origins() -> list[str]:
    raw = getattr(settings, "ALLOWED_ORIGINS", "*") or getattr(settings, "CORS_ORIGINS", "*") or "*"
    if isinstance(raw, list):
        return raw
    if raw == "*":
        return ["*"]
    return [o.strip() for o in raw.split(",") if o.strip()]

@asynccontextmanager
async def lifespan(app: FastAPI):
    # 1. Automatic database schema and migration execution on startup
    run_startup_migrations()

    # 2. Production safety guard: enforce JWT_SECRET in production
    if settings.APP_ENV.lower() in ("production", "prod"):
        insecure_keys = {
            "kalasetu_secret_jwt_key",
            "kalasetu_super_secret_jwt_key_change_in_production",
            "",
            "change_me",
        }
        if not settings.JWT_SECRET or settings.JWT_SECRET in insecure_keys:
            raise RuntimeError(
                "CRITICAL: Production deployment error: JWT_SECRET must be set to a custom secure secret."
            )

    # 3. Seed demo accounts and multilingual catalogue if DEMO_MODE=True
    if settings.DEMO_MODE:
        with SessionLocal() as db:
            try:
                seed_demo_data(db)
            except Exception as e:
                import logging
                logging.getLogger("kalasetu").warning(f"Demo seeding failed on startup: {e}")

    yield

app = FastAPI(
    title="KalaSetu API",
    description="Bridging Artisans to the World with AI",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

# Request ID Middleware
class RequestIdMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        req_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))
        request.state.request_id = req_id
        response = await call_next(request)
        response.headers["X-Request-ID"] = req_id
        return response

app.add_middleware(RequestIdMiddleware)

# CORS Middleware from ALLOWED_ORIGINS
app.add_middleware(
    CORSMiddleware,
    allow_origins=get_allowed_origins(),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Standardized Error Handler
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    req_id = getattr(request.state, "request_id", str(uuid.uuid4()))
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "code": "INTERNAL_SERVER_ERROR",
            "message": str(exc) if settings.APP_ENV == "development" else "An unexpected error occurred.",
            "request_id": req_id
        },
        headers={"X-Request-ID": req_id}
    )

# Static files for uploaded images (mounted at both root and /api/v1 prefix)
os.makedirs(settings.STORAGE_LOCAL_PATH, exist_ok=True)
app.mount("/static/uploads", StaticFiles(directory=settings.STORAGE_LOCAL_PATH), name="uploads")
if settings.API_BASE_PATH:
    app.mount(f"{settings.API_BASE_PATH}/static/uploads", StaticFiles(directory=settings.STORAGE_LOCAL_PATH), name="uploads_prefixed")

# Include Routers (mounted at both API prefix and root for full flexibility)
api_prefix = settings.API_BASE_PATH
app.include_router(auth.router, prefix=api_prefix)
app.include_router(auth.router)
app.include_router(products.router, prefix=api_prefix)
app.include_router(products.router)
app.include_router(marketplace.router, prefix=api_prefix)
app.include_router(marketplace.router)
app.include_router(orders.router, prefix=api_prefix)
app.include_router(orders.router)
app.include_router(notifications.router, prefix=api_prefix)
app.include_router(notifications.router)
app.include_router(media.router, prefix=api_prefix)
app.include_router(media.router)
app.include_router(sync.router, prefix=api_prefix)
app.include_router(sync.router)
app.include_router(catalog.router, prefix=api_prefix)
app.include_router(catalog.router)
app.include_router(images.router, prefix=api_prefix)
app.include_router(images.router)
app.include_router(pricing.router, prefix=api_prefix)
app.include_router(pricing.router)
app.include_router(assistant.router, prefix=api_prefix)
app.include_router(assistant.router)
app.include_router(analytics.router, prefix=api_prefix)
app.include_router(analytics.router)
app.include_router(voice.router, prefix=api_prefix)
app.include_router(voice.router)

# Health endpoint (available both at root and /api/v1)
@app.get("/health", tags=["System"])
@app.get(f"{settings.API_BASE_PATH}/health", tags=["System"])
async def health_check(request: Request):
    req_id = getattr(request.state, "request_id", "unknown")
    key_configured = bool(settings.GEMINI_API_KEY and settings.GEMINI_API_KEY.strip())
    return {
        "status": "ok",
        "app": "KalaSetu",
        "version": "1.0.0",
        "environment": settings.APP_ENV,
        "ai_mode": settings.AI_MODE,
        "demo_mode": settings.DEMO_MODE,
        "storage_backend": settings.STORAGE_BACKEND,
        "key_configured": key_configured,
        "gemini_key_configured": key_configured,
        "request_id": req_id
    }
