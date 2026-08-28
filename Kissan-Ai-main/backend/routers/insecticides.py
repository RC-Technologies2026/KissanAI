from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, desc
from sqlalchemy.ext.asyncio import AsyncSession
from db import get_db
from models.pest_detection import PestDetection
from models.insecticide_recommendation import InsecticideRecommendation
from models.weather_cache import WeatherCache
from models.user import User
from schemas.insecticide import InsecticideRecommendationRequest, InsecticideRecommendationResponse
from auth.utils import get_current_user
from rules_engine.insecticide_rules import get_insecticide_recommendation, get_default_insecticide
from rules_engine.weather_gate import is_weather_safe

router = APIRouter(prefix="/api/insecticides", tags=["insecticides"])


@router.post("/recommend", response_model=InsecticideRecommendationResponse, status_code=status.HTTP_201_CREATED)
async def recommend_insecticide(
    body: InsecticideRecommendationRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # --- 1. Look up the pest detection ---
    result = await db.execute(
        select(PestDetection).where(PestDetection.id == body.pest_detection_id)
    )
    detection = result.scalar_one_or_none()
    if not detection:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pest detection not found")
    if detection.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized")

    # --- 2. Get Rules Engine recommendation ---
    rule = get_insecticide_recommendation(detection.pest_name)
    if rule is None:
        rule = get_default_insecticide()

    # --- 3. Check weather gate (if location provided) ---
    weather_blocked = False
    if body.lat is not None and body.lon is not None:
        location = f"{body.lat},{body.lon}"
        weather_result = await db.execute(
            select(WeatherCache)
            .where(WeatherCache.location == location)
            .order_by(desc(WeatherCache.cached_at))
            .limit(1)
        )
        weather = weather_result.scalar_one_or_none()
        if weather:
            weather_blocked = not is_weather_safe(weather.rain_probability, weather.wind_speed)

    # --- 4. Save recommendation to database ---
    recommendation = InsecticideRecommendation(
        pest_detection_id=detection.id,
        product_name=rule["product_name"],
        dosage=rule["dosage"],
        application_method=rule.get("application_method"),
        weather_blocked=weather_blocked,
        usage_guidance=rule.get("usage_guidance"),
        safety_precautions=rule.get("safety_precautions"),
    )
    db.add(recommendation)
    await db.commit()
    await db.refresh(recommendation)

    return recommendation
