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
from rules_engine.pesticide_rules import get_pesticide_recommendation, get_default_pesticide, PESTICIDE_RULES
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
    #
    # The AI returns disease_category as generic values ("fungal", "bacterial")
    # which never match the specific disease keys in PESTICIDE_RULES.
    # So we normalize disease_name to snake_case and try matching that first.
    products = None

    # Strategy 1: normalize disease_name to snake_case and try exact + fuzzy match
    if detection.disease_name:
        normalized = detection.disease_name.lower().strip()
        # Remove common prefixes that AI adds
        for prefix in ["leaf ", "stem ", "root ", "fruit "]:
            if normalized.startswith(prefix):
                normalized = normalized[len(prefix):]
        normalized = normalized.replace(" ", "_").replace("-", "_").replace("'", "").replace("/", "_")
        products = get_pesticide_recommendation(normalized)

        # Fuzzy match: check if any rule key is contained in the normalized name
        # e.g. "late_blight" contains "blight", "bacterial_leaf_blight" contains "blight"
        if not products:
            for key in PESTICIDE_RULES:
                if key in normalized or normalized in key:
                    products = get_pesticide_recommendation(key)
                    break

    # Strategy 2: try disease_category (may be generic like "fungal" — rarely matches)
    if not products and detection.disease_category:
        products = get_pesticide_recommendation(detection.disease_category)

    # Strategy 3: try disease_name as-is (for older rows)
    if not products and detection.disease_name:
        raw_key = detection.disease_name.lower().replace(" ", "_")
        products = get_pesticide_recommendation(raw_key)
        # Fuzzy match for older rows too
        if not products:
            for key in PESTICIDE_RULES:
                if key in raw_key or raw_key in key:
                    products = get_pesticide_recommendation(key)
                    break

    # Strategy 4: fallback to default broad-spectrum products
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
