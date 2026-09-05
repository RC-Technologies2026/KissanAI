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
    force: bool = Query(False, description="Bypass Redis cache"),
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
    cached_data = None if force else await redis_get(cache_key)
    if cached_data:
        logger.info("Cache HIT for %s", cache_key)
        data = json.loads(cached_data)
        return WeatherResponse(
            location=location,
            temperature=data["temperature"],
            feels_like=data.get("feels_like"),
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
    feels_like = owm["main"].get("feels_like", temperature)
    humidity = owm["main"]["humidity"]
    wind_speed = owm["wind"]["speed"]
    description = owm["weather"][0]["description"]

    # rain_probability: infer from weather description when no rain volume data
    rain_data = owm.get("rain", {})
    rain_1h = rain_data.get("1h", 0)
    if rain_1h > 0:
        rain_probability = min(rain_1h / 10.0 * 100, 80)
    else:
        # Use weather description to estimate probability (capped at 75%)
        desc_lower = description.lower()
        if "thunder" in desc_lower or "storm" in desc_lower:
            rain_probability = 75.0
        elif "heavy rain" in desc_lower:
            rain_probability = 70.0
        elif "rain" in desc_lower:
            rain_probability = 55.0
        elif "drizzle" in desc_lower or "light rain" in desc_lower:
            rain_probability = 45.0
        elif "shower" in desc_lower:
            rain_probability = 40.0
        elif "cloud" in desc_lower or "overcast" in desc_lower:
            rain_probability = 20.0
        else:
            rain_probability = 0.0

    weather_data = {
        "temperature": temperature,
        "feels_like": feels_like,
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
        feels_like=feels_like,
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
    force: bool = Query(False, description="Bypass Redis cache"),
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
    cached = None if force else await redis_get(forecast_key)
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

    # Build hourly forecast from the next 8 x 3-hour entries
    hourly_forecasts: list[dict] = []
    for item in owm.get("list", [])[:8]:
        dt = datetime.fromtimestamp(item["dt"])
        # Cap rain chance at 80% — OWM sometimes returns 1.0 (100%) unrealistically
        raw_pop = item.get("pop", 0)
        rain_chance = min(round(raw_pop * 100), 80)
        hourly_forecasts.append({
            "hour": dt.strftime("%I %p"),
            "temp": round(item["main"]["temp"]),
            "condition_icon": item["weather"][0]["description"],
            "rain_chance": rain_chance,
        })

    # --- 3. Get current weather ---
    current = await get_current_weather(
        request=request,
        lat=lat,
        lon=lon,
        force=force,
        db=db,
        current_user=current_user,
    )

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
            # Use OWM's 'pop' (probability of precipitation, 0-1)
            pop = e.get("pop", 0)
            rain_probs.append(pop * 100)

        dt = datetime.strptime(date_str, "%Y-%m-%d")
        day_name = day_names.get(dt.strftime("%a"), dt.strftime("%a"))

        # Most common condition
        from collections import Counter
        most_common_cond = Counter(conditions).most_common(1)[0][0] if conditions else "clear"

        # Use weighted rain chance: 70th percentile (realistic, not extreme max)
        rain_probs_sorted = sorted(rain_probs)
        if rain_probs_sorted:
            idx = int(len(rain_probs_sorted) * 0.7)
            daily_rain_chance = min(round(rain_probs_sorted[min(idx, len(rain_probs_sorted)-1)]), 80)
        else:
            daily_rain_chance = 0

        daily_forecasts.append(DailyForecastItem(
            day=day_name,
            high=round(max(temps)),
            low=round(min(temps)),
            condition=most_common_cond.title(),
            condition_icon=most_common_cond,
            rain_chance=daily_rain_chance,
            humidity=round(sum(humidities) / len(humidities)) if humidities else 65,
            wind_speed=round(max(winds)) if winds else 0,
        ))

    # --- 5. Generate agricultural alerts (max 1 per day, combined) ---
    alerts: list[str] = []
    day_alerts: dict[str, list[str]] = {}  # day -> list of issues

    for fc in daily_forecasts:
        issues: list[str] = []
        if fc.rain_chance >= 40:
            issues.append(f"rain expected ({fc.rain_chance}%)")
        if fc.wind_speed >= 20:
            issues.append(f"strong winds ({fc.wind_speed} km/h)")
        if fc.high >= 42:
            issues.append(f"extreme heat ({fc.high}°C)")
        elif fc.high >= 38 and fc.humidity < 25:
            issues.append(f"hot & dry ({fc.high}°C, {fc.humidity}% humidity)")
        if fc.low <= 4:
            issues.append(f"frost risk ({fc.low}°C)")
        if fc.humidity >= 75 and fc.high >= 28:
            issues.append(f"high humidity — fungal disease risk")

        if issues:
            day_alerts[fc.day] = issues

    # Build one combined alert per day
    for day, issues in day_alerts.items():
        combined = "; ".join(issues)
        if "rain" in combined:
            alerts.append(f"{day}: {combined.capitalize()} — avoid spraying pesticides")
        elif "heat" in combined or "dry" in combined:
            alerts.append(f"{day}: {combined.capitalize()} — irrigate in early morning")
        elif "frost" in combined:
            alerts.append(f"{day}: {combined.capitalize()} — protect sensitive crops")
        elif "wind" in combined:
            alerts.append(f"{day}: {combined.capitalize()} — do not spray crops")
        else:
            alerts.append(f"{day}: {combined.capitalize()}")

    # Current conditions
    if current.wind_speed >= 20:
        alerts.insert(0, "Today: High wind — spraying not recommended")
    if current.rain_probability >= 40:
        alerts.insert(0, "Today: Rain likely — hold off on irrigation")

    alerts = alerts[:4]

    result = WeatherForecastResponse(
        location=location,
        current=current,
        hourly=hourly_forecasts,
        daily=daily_forecasts,
        alerts=alerts,
    )

    # Cache for 30 minutes
    await redis_set(forecast_key, json.dumps(result.model_dump()), ex=1800)

    return result
