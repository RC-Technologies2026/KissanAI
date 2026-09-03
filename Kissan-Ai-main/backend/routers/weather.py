import json
import logging
import httpx
from datetime import datetime, timezone, timedelta
from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from db import get_db
from models.weather_cache import WeatherCache
from models.user import User
from schemas.weather import WeatherResponse, WeatherForecastResponse, DailyForecastItem
from auth.utils import get_current_user
from redis_client import redis_get, redis_set
from rate_limiter import limiter
import os

logger = logging.getLogger("kissanai.weather")

router = APIRouter(prefix="/api/weather", tags=["weather"])

CACHE_TTL = 900  # 15 minutes in seconds
OPENWEATHERMAP_KEY = os.getenv("OPENWEATHERMAP_KEY", "")
OPENWEATHERMAP_URL = "https://api.openweathermap.org/data/2.5/weather"
OPENWEATHERMAP_FORECAST_URL = "https://api.openweathermap.org/data/2.5/forecast"

# Reusable async HTTP client for OWM calls (connection pooling)
_owm_client: httpx.AsyncClient | None = None


def _get_owm_client() -> httpx.AsyncClient:
    global _owm_client
    if _owm_client is None or _owm_client.is_closed:
        _owm_client = httpx.AsyncClient(timeout=10.0)
    return _owm_client


@router.get("/current", response_model=WeatherResponse)
@limiter.limit("20/minute")
async def get_current_weather(
    request: Request,
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
        logger.info("Cache HIT for %s", cache_key)
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
        client = _get_owm_client()
        resp = await client.get(
            OPENWEATHERMAP_URL,
            params={
                "lat": lat,
                "lon": lon,
                "appid": OPENWEATHERMAP_KEY,
                "units": "metric",
            },
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

    # --- 4. Write to Redis cache ---
    redis_ok = await redis_set(cache_key, json.dumps(weather_data), ex=CACHE_TTL)
    if not redis_ok:
        logger.warning("Redis cache write failed for %s — weather still returned from OWM", cache_key)

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


@router.get("/forecast", response_model=WeatherForecastResponse)
@limiter.limit("10/minute")
async def get_weather_forecast(
    request: Request,
    lat: float = Query(..., description="Latitude"),
    lon: float = Query(..., description="Longitude"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    3-day weather forecast with agricultural alerts.
    Uses OpenWeatherMap 5-day/3-hour forecast API and aggregates to daily.
    """
    if not OPENWEATHERMAP_KEY:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Weather service not configured",
        )

    location = f"{lat},{lon}"
    forecast_key = f"forecast:{location}"

    # --- 1. Check Redis cache ---
    cached = await redis_get(forecast_key)
    if cached:
        data = json.loads(cached)
        return WeatherForecastResponse(**data)

    # --- 2. Fetch 5-day/3-hour forecast from OWM ---
    try:
        client = _get_owm_client()
        resp = await client.get(
            OPENWEATHERMAP_FORECAST_URL,
            params={
                "lat": lat,
                "lon": lon,
                "appid": OPENWEATHERMAP_KEY,
                "units": "metric",
            },
        )
        if resp.status_code != 200:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Failed to fetch forecast data",
            )
        owm = resp.json()
    except httpx.RequestError:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Forecast service unavailable",
        )

    # --- 3. Get current weather ---
    current = await get_current_weather(request, lat, lon, db, current_user)

    # --- 4. Aggregate 3-hour data into daily ---
    daily_map: dict[str, list] = {}  # date_str -> list of 3-hour entries
    for item in owm.get("list", []):
        dt = datetime.fromtimestamp(item["dt"])
        date_str = dt.strftime("%Y-%m-%d")
        if date_str not in daily_map:
            daily_map[date_str] = []
        daily_map[date_str].append(item)

    # Build 3-day forecast (skip today, take next 3 days)
    today_str = datetime.now().strftime("%Y-%m-%d")
    sorted_dates = sorted(daily_map.keys())
    future_dates = [d for d in sorted_dates if d > today_str][:3]

    day_names = {"Mon": "Mon", "Tue": "Tue", "Wed": "Wed", "Thu": "Thu",
                 "Fri": "Fri", "Sat": "Sat", "Sun": "Sun"}

    daily_forecasts: list[DailyForecastItem] = []
    for date_str in future_dates:
        entries = daily_map[date_str]
        temps = [e["main"]["temp"] for e in entries]
        humidities = [e["main"]["humidity"] for e in entries]
        winds = [e["wind"]["speed"] for e in entries]
        conditions = [e["weather"][0]["description"] for e in entries]
        rain_probs = []
        for e in entries:
            rain_data = e.get("rain", {})
            rain_3h = rain_data.get("3h", 0)
            rain_probs.append(min(rain_3h / 10.0 * 100, 100) if rain_3h > 0 else 0)

        dt = datetime.strptime(date_str, "%Y-%m-%d")
        day_name = day_names.get(dt.strftime("%a"), dt.strftime("%a"))

        # Most common condition
        from collections import Counter
        most_common_cond = Counter(conditions).most_common(1)[0][0] if conditions else "clear"

        daily_forecasts.append(DailyForecastItem(
            day=day_name,
            high=round(max(temps)),
            low=round(min(temps)),
            condition=most_common_cond.title(),
            condition_icon=most_common_cond,
            rain_chance=round(max(rain_probs)) if rain_probs else 0,
            humidity=round(sum(humidities) / len(humidities)) if humidities else 65,
            wind_speed=round(max(winds)) if winds else 0,
        ))

    # --- 5. Generate agricultural alerts ---
    alerts: list[str] = []

    # Check all 3 days for extreme conditions
    for fc in daily_forecasts:
        if fc.rain_chance > 60:
            alerts.append(f"{fc.day}: Heavy rain expected ({fc.rain_chance}% chance) — avoid spraying pesticides")
        if fc.wind_speed > 15:
            alerts.append(f"{fc.day}: Strong winds ({fc.wind_speed} km/h) — do not spray crops")
        if fc.high > 42:
            alerts.append(f"{fc.day}: Extreme heat ({fc.high}°C) — irrigate crops in early morning")
        if fc.low < 5:
            alerts.append(f"{fc.day}: Frost risk ({fc.low}°C) — protect sensitive crops")
        if fc.high > 38 and fc.humidity < 30:
            alerts.append(f"{fc.day}: Hot and dry — increase irrigation frequency")

    # Check current conditions
    if current.wind_speed > 15:
        alerts.insert(0, "Today: High wind — spraying not recommended")
    if current.rain_probability > 60:
        alerts.insert(0, "Today: Rain expected — irrigation may not be needed")

    # Limit to top 5 alerts
    alerts = alerts[:5]

    result = WeatherForecastResponse(
        location=location,
        current=current,
        daily=daily_forecasts,
        alerts=alerts,
    )

    # Cache for 30 minutes
    await redis_set(forecast_key, json.dumps(result.model_dump()), ex=1800)

    return result
