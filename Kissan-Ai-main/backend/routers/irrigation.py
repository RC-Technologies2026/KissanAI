from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, desc
from sqlalchemy.ext.asyncio import AsyncSession
from db import get_db
from models.plot import Plot
from models.crop_recommendation import CropRecommendation
from models.irrigation_guidance import IrrigationGuidance
from models.analysis_history import AnalysisHistory
from models.user import User
from schemas.crop import CropRecommendationRequest, CropRecommendationResponse, IrrigationGuideResponse
from auth.utils import get_current_user
from rules_engine.crop_rules import get_crop_recommendation, get_irrigation_guidance

router = APIRouter(prefix="/api/irrigation", tags=["irrigation"])


@router.post("/recommend", response_model=CropRecommendationResponse, status_code=status.HTTP_201_CREATED)
async def recommend_crops(
    body: CropRecommendationRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # --- 1. Look up the plot ---
    result = await db.execute(select(Plot).where(Plot.id == body.plot_id))
    plot = result.scalar_one_or_none()
    if not plot:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Plot not found")
    if plot.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized")

    # --- 2. Get crop recommendation from Rules Engine ---
    crops, reasoning = get_crop_recommendation(plot.soil_type)
    recommended_crops_str = ", ".join(crops)

    # --- 3. Save crop recommendation ---
    crop_rec = CropRecommendation(
        plot_id=plot.id,
        recommended_crops=recommended_crops_str,
        reasoning=reasoning,
    )
    db.add(crop_rec)
    await db.flush()  # get crop_rec.id before creating irrigation

    # --- 4. Generate irrigation guidance for top recommended crop ---
    top_crop = crops[0] if crops else "vegetables"
    irrigation_data = get_irrigation_guidance(top_crop)

    irrigation = IrrigationGuidance(
        crop_recommendation_id=crop_rec.id,
        schedule=irrigation_data["schedule"],
        water_amount_liters=irrigation_data["water_amount_liters"],
        method=irrigation_data.get("method"),
    )
    db.add(irrigation)

    # --- 5. Log to ANALYSIS_HISTORY ---
    history_entry = AnalysisHistory(
        user_id=current_user.id,
        analysis_type="crop",
        reference_id=crop_rec.id,
        result_snapshot={
            "recommended_crops": crops,
            "reasoning": reasoning,
            "soil_type": plot.soil_type,
            "top_crop_for_irrigation": top_crop,
            "irrigation": irrigation_data,
        },
    )
    db.add(history_entry)

    await db.commit()
    await db.refresh(crop_rec)

    return crop_rec


@router.get("/guide/{crop_recommendation_id}", response_model=IrrigationGuideResponse)
async def get_irrigation_guide(
    crop_recommendation_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # --- 1. Look up the crop recommendation ---
    result = await db.execute(
        select(IrrigationGuidance).where(
            IrrigationGuidance.crop_recommendation_id == crop_recommendation_id
        )
    )
    guidance = result.scalar_one_or_none()
    if not guidance:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Irrigation guide not found")

    # --- 2. Verify ownership through plot ---
    crop_result = await db.execute(
        select(CropRecommendation).where(CropRecommendation.id == crop_recommendation_id)
    )
    crop_rec = crop_result.scalar_one_or_none()
    if crop_rec:
        plot_result = await db.execute(select(Plot).where(Plot.id == crop_rec.plot_id))
        plot = plot_result.scalar_one_or_none()
        if plot and plot.user_id != current_user.id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized")

    return guidance
