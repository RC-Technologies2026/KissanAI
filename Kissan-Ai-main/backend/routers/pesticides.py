from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, desc
from sqlalchemy.ext.asyncio import AsyncSession
from db import get_db
from models.disease_detection import DiseaseDetection
from models.pesticide_recommendation import PesticideRecommendation
from models.weather_cache import WeatherCache
from models.user import User
from schemas.pesticide import PesticideRecommendationRequest, PesticideRecommendationResponse, PesticideProduct
from auth.utils import get_current_user
from rules_engine.pesticide_rules import get_pesticide_recommendation, get_default_pesticide
from rules_engine.weather_gate import is_weather_safe

router = APIRouter(prefix="/api/pesticides", tags=["pesticides"])


@router.post("/recommend", response_model=PesticideRecommendationResponse, status_code=status.HTTP_201_CREATED)
async def recommend_pesticide(
    body: PesticideRecommendationRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(DiseaseDetection).where(DiseaseDetection.id == body.disease_detection_id)
    )
    detection = result.scalar_one_or_none()
    if not detection:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Disease detection not found")
    if detection.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized")

    # Prefer the fixed English category (set by Gemini alongside the
    # localized disease_name) since disease_name may be translated/free-form
    # and won't reliably match the rules engine's fixed keys. Fall back to
    # disease_name for older rows saved before disease_category existed.
    products = get_pesticide_recommendation(detection.disease_category or detection.disease_name)
    if not products:
        products = get_default_pesticide()

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

    # Save primary (first) product to DB
    primary = products[0]
    recommendation = PesticideRecommendation(
        disease_detection_id=detection.id,
        product_name=primary["product_name"],
        dosage=primary["dosage"],
        application_method=primary.get("application_method"),
        weather_blocked=weather_blocked,
        application_guidance=primary.get("application_guidance"),
        safety_precautions=primary.get("safety_precautions"),
    )
    db.add(recommendation)
    await db.commit()
    await db.refresh(recommendation)

    # Return all product options in response
    return PesticideRecommendationResponse(
        id=recommendation.id,
        disease_detection_id=recommendation.disease_detection_id,
        products=[PesticideProduct(**p) for p in products],
        weather_blocked=recommendation.weather_blocked,
        created_at=recommendation.created_at,
    )
