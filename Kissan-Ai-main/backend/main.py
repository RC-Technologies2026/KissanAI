from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers.auth import router as auth_router
from routers.images import router as images_router
from routers.weather import router as weather_router
from routers.disease import router as disease_router
from routers.pests import router as pests_router
from routers.pesticides import router as pesticides_router
from routers.insecticides import router as insecticides_router
import cloudinary_config  # noqa: F401 — configures Cloudinary on import

app = FastAPI(title="KissanAI API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
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

@app.get("/health")
def health_check():
    return {"status": "ok", "service": "KissanAI API"}
