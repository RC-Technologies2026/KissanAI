import os
import asyncio
import logging
from routers.plots import router as plots_router
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from rate_limiter import limiter
from routers.auth import router as auth_router
from routers.images import router as images_router
from routers.weather import router as weather_router
from routers.disease import router as disease_router
from routers.pests import router as pests_router
from routers.pesticides import router as pesticides_router
from routers.insecticides import router as insecticides_router
from routers.irrigation import router as irrigation_router
from routers.history import router as history_router
from routers.chat import router as chat_router
from routers.plants import router as plants_router
import cloudinary_config  # noqa: F401 — configures Cloudinary on import

logger = logging.getLogger("kissanai")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # --- Startup: warm up EfficientNet model in background ---
    async def _warm_model():
        try:
            from vision.efficientnet import _get_model
            await asyncio.to_thread(_get_model)
            logger.info("EfficientNet-B0 model loaded and ready")
        except Exception as e:
            logger.warning(f"Model warm-up failed (will lazy-load on first request): {e}")

    asyncio.create_task(_warm_model())
    yield
    # --- Shutdown ---


app = FastAPI(title="KissanAI API", version="0.1.0", lifespan=lifespan)

# --- Rate limiter (slowapi) ---
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# --- CORS — origins from environment ---
_allowed_origins = os.getenv("ALLOWED_ORIGINS", "").strip()
_is_production = os.getenv("ENVIRONMENT", "development").lower() == "production"

if _allowed_origins:
    allow_origins = [o.strip() for o in _allowed_origins.split(",") if o.strip()]
    allow_credentials = True
else:
    # No explicit origins configured — use wildcard for development only.
    allow_origins = ["*"]
    allow_credentials = False
    if _is_production:
        logger.error(
            "ALLOWED_ORIGINS is not set in production. "
            "CORS is using wildcard '*' with credentials disabled. "
            "Set ALLOWED_ORIGINS to your frontend domain(s)."
        )

app.add_middleware(
    CORSMiddleware,
    allow_origins=allow_origins,
    allow_credentials=allow_credentials,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(images_router)
app.include_router(weather_router)
app.include_router(disease_router)
app.include_router(pests_router)
app.include_router(pesticides_router)
app.include_router(insecticides_router)
app.include_router(irrigation_router)
app.include_router(history_router)
app.include_router(chat_router)
app.include_router(plots_router)
app.include_router(plants_router)

@app.get("/health")
def health_check():
    return {"status": "ok", "service": "KissanAI API"}
