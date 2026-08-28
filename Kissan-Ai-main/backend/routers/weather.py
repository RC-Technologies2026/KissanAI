import json
import httpx
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from db import get_db
from models.weather_cache import WeatherCache
from models.user import User
from schemas.weather import WeatherResponse
from auth.utils import get_current_user
from redis_client import redis_get, redis_set
import os

router = APIRouter(prefix="/api/weather", tags=["weather"])

CACHE_TTL = 900  # 15 minutes in seconds
OPENWEATHERMAP_KEY = os.getenv("OPENWEATHERMAP_KEY", "")
OPENWEATHERMAP_URL = "https://api.openweathermap.org/data/2.5/weather"


@router.get("/current", response_model=WeatherResponse)
async def get_current_weather(
    lat: float = Query(..., description="Latitude"),
    lon: float = Query(..., description="Longitude"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not OPENWEATHERMAP_KEY:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Weather service not configured",
        )

    location = f"{lat},{lon}"
    cache_key = f"weather:{location}"

    # --- 1. Check Redis cache ---
    cached_data = await redis_get(cache_key)
    if cached_data:
        data = json.loads(cached_data)
        return WeatherResponse(
            location=location,
            temperature=data["temperature"],
            humidity=data["humidity"],
            rain_probability=data["rain_probability"],
            wind_speed=data["wind_speed"],
            description=data["description"],
            cached=True,
            cached_at=datetime.fromisoformat(data["cached_at"]),
        )

    # --- 2. Fetch from OpenWeatherMap ---
    try:
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                OPENWEATHERMAP_URL,
                params={
                    "lat": lat,
                    "lon": lon,
                    "appid": OPENWEATHERMAP_KEY,
                    "units": "metric",
                },
                timeout=10.0,
            )
        if resp.status_code != 200:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Failed to fetch weather data",
            )
        owm = resp.json()
    except httpx.RequestError:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Weather service unavailable",
        )

    # --- 3. Parse OpenWeatherMap response ---
    temperature = owm["main"]["temp"]
    humidity = owm["main"]["humidity"]
    wind_speed = owm["wind"]["speed"]
    description = owm["weather"][0]["description"]

    # rain_probability: use rain/1h volume if available, else 0
    rain_data = owm.get("rain", {})
    rain_1h = rain_data.get("1h", 0)
    rain_probability = min(rain_1h / 10.0 * 100, 100) if rain_1h > 0 else 0.0

    weather_data = {
        "temperature": temperature,
        "humidity": humidity,
        "rain_probability": rain_probability,
        "wind_speed": wind_speed,
        "description": description,
        "cached_at": datetime.now(timezone.utc).isoformat(),
    }

    # --- 4. Write to Redis cache (fire-and-forget) ---
    await redis_set(cache_key, json.dumps(weather_data), ex=CACHE_TTL)

    # --- 5. Write to PostgreSQL (persistent record) ---
    weather_record = WeatherCache(
        location=location,
        temperature=temperature,
        humidity=humidity,
        rain_probability=rain_probability,
        wind_speed=wind_speed,
    )
    db.add(weather_record)
    await db.commit()

    return WeatherResponse(
        location=location,
        temperature=temperature,
        humidity=humidity,
        rain_probability=rain_probability,
        wind_speed=wind_speed,
        description=description,
        cached=False,
        cached_at=None,
    )
