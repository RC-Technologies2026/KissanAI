from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, desc
from sqlalchemy.ext.asyncio import AsyncSession
from db import get_db
from models.plot import Plot
from models.crop_recommendation import CropRecommendation
from models.irrigation_guidance import IrrigationGuidance
from models.analysis_history import AnalysisHistory
from models.user import User
from schemas.crop import (
    CropRecommendationRequest,
    CropRecommendationResponse,
    IrrigationGuideResponse,
    DirectIrrigationGuideRequest,
    DirectIrrigationGuideResponse,
)
from auth.utils import get_current_user
from rules_engine.crop_rules import (
    get_crop_recommendation,
    get_irrigation_guidance,
    get_fertilizer_guidance,
    get_pest_disease_alerts,
    get_crop_metadata,
)

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
    # Use soil type from the request if the farmer picked one on this
    # screen, otherwise fall back to the plot's saved soil type. Season and
    # water availability come only from the request. Pass plot area / GPS
    # for regional adaptation of the reasoning text.
    soil_type = body.soil_type or plot.soil_type
    crops, reasoning = get_crop_recommendation(
        soil_type,
        season=body.season,
        water_availability=body.water_availability,
        area_hectares=plot.area_hectares,
        latitude=plot.latitude,
        longitude=plot.longitude,
    )
    recommended_crops_str = ", ".join(crops)

    # --- 3. Save crop recommendation ---
    crop_rec = CropRecommendation(
        plot_id=plot.id,
        recommended_crops=recommended_crops_str,
        reasoning=reasoning,
    )
    db.add(crop_rec)
    await db.flush()  # get crop_rec.id before creating irrigation

    # --- 4. Generate guidance for top recommended crop ---
    top_crop = crops[0] if crops else "vegetables"
    irrigation_data = get_irrigation_guidance(top_crop, water_availability=body.water_availability)
    fertilizer_advice = get_fertilizer_guidance(top_crop)
    pest_alerts = get_pest_disease_alerts(top_crop)
    crop_meta = get_crop_metadata(top_crop)

    irrigation = IrrigationGuidance(
        crop_recommendation_id=crop_rec.id,
        schedule=irrigation_data["schedule"],
        water_amount_liters=irrigation_data["water_amount_liters"],
        method=irrigation_data.get("method"),
    )
    db.add(irrigation)

    # Build a rich, farmer-friendly recommendation summary.
    enriched_reasoning_parts = [reasoning]
    enriched_reasoning_parts.append(
        f" Top pick '{top_crop.title()}': fertilize with {fertilizer_advice}"
    )
    enriched_reasoning_parts.append(f" Watch for: {pest_alerts}")
    if irrigation_data.get("note"):
        enriched_reasoning_parts.append(irrigation_data["note"])
    crop_rec.reasoning = " ".join(enriched_reasoning_parts)

    # --- 5. Log to ANALYSIS_HISTORY ---
    history_entry = AnalysisHistory(
        user_id=current_user.id,
        analysis_type="crop",
        reference_id=crop_rec.id,
        result_snapshot={
            "recommended_crops": crops,
            "reasoning": reasoning,
            "soil_type": soil_type,
            "season": body.season,
            "water_availability": body.water_availability,
            "top_crop_for_irrigation": top_crop,
            "irrigation": irrigation_data,
            "fertilizer": fertilizer_advice,
            "pest_alerts": pest_alerts,
            "crop_metadata": crop_meta,
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


@router.post("/direct-guide", response_model=DirectIrrigationGuideResponse, status_code=status.HTTP_201_CREATED)
async def direct_irrigation_guide(
    body: DirectIrrigationGuideRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Standalone irrigation guide for a selected plot + crop.
    Works like crop recommendation but focused only on irrigation scheduling.
    """
    # --- 1. Look up the plot ---
    result = await db.execute(select(Plot).where(Plot.id == body.plot_id))
    plot = result.scalar_one_or_none()
    if not plot:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Plot not found")
    if plot.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized")

    crop_name = body.crop_name.strip()

    # --- 2. Generate guidance from rules engine ---
    irrigation_data = get_irrigation_guidance(crop_name, water_availability=body.water_availability)
    fertilizer = get_fertilizer_guidance(crop_name)
    pest_alerts = get_pest_disease_alerts(crop_name)
    crop_meta = get_crop_metadata(crop_name)

    # Pick a sensible growth stage if not provided.
    growth_stage = body.growth_stage
    if not growth_stage:
        schedule_text = irrigation_data.get("schedule", "")
        if "seedling" in schedule_text.lower():
            growth_stage = "Seedling"
        elif "vegetative" in schedule_text.lower():
            growth_stage = "Vegetative"
        elif "flowering" in schedule_text.lower() or "reproductive" in schedule_text.lower():
            growth_stage = "Reproductive"
        elif "tillering" in schedule_text.lower():
            growth_stage = "Tillering"
        else:
            growth_stage = "Active growth"

    # --- 3. Log to ANALYSIS_HISTORY ---
    history_entry = AnalysisHistory(
        user_id=current_user.id,
        analysis_type="irrigation",
        reference_id=plot.id,
        result_snapshot={
            "crop_name": crop_name,
            "plot_name": plot.name,
            "soil_type": plot.soil_type,
            "water_availability": body.water_availability,
            "growth_stage": growth_stage,
            "schedule": irrigation_data.get("schedule"),
            "water_amount_liters": irrigation_data.get("water_amount_liters"),
            "method": irrigation_data.get("method"),
            "note": irrigation_data.get("note"),
            "fertilizer": fertilizer,
            "pest_alerts": pest_alerts,
            "duration_days": crop_meta.get("duration_days"),
        },
    )
    db.add(history_entry)
    await db.commit()

    return DirectIrrigationGuideResponse(
        plot_id=plot.id,
        crop_name=crop_name.title(),
        schedule=irrigation_data.get("schedule", "Irrigate as needed based on soil moisture."),
        water_amount_liters=irrigation_data.get("water_amount_liters", 0.0),
        method=irrigation_data.get("method"),
        note=irrigation_data.get("note"),
        fertilizer=fertilizer,
        pest_alerts=pest_alerts,
        growth_stage=growth_stage,
        next_irrigation=irrigation_data.get("next_irrigation", "Check soil moisture daily."),
        duration_days=crop_meta.get("duration_days"),
    )
