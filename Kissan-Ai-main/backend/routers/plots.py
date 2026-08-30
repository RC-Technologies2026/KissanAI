from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession
from db import get_db
from models.plot import Plot
from models.plot_crop import PlotCrop
from models.plot_livestock import PlotLivestock
from models.user import User
from schemas.plot import (
    PlotCreate,
    PlotResponse,
    PlotDetailResponse,
    PlotCropCreate,
    PlotCropResponse,
    PlotLivestockCreate,
    PlotLivestockResponse,
)
from auth.utils import get_current_user
from redis_client import cache_get_json, cache_set_json, redis_delete

import logging

logger = logging.getLogger("kissanai.plots")

router = APIRouter(prefix="/api/plots", tags=["plots"])

CACHE_TTL = 600  # 10 min


def _plots_list_key(user_id) -> str:
    return f"plots:list:{user_id}"


def _plot_detail_key(plot_id) -> str:
    return f"plots:detail:{plot_id}"


async def _get_owned_plot(
    plot_id: str, db: AsyncSession, current_user: User
) -> Plot:
    """Fetch a plot scoped to the current user.  Returns 404 whether the
    plot doesn't exist OR belongs to someone else — no existence leak."""
    result = await db.execute(
        select(Plot).where(Plot.id == plot_id, Plot.user_id == current_user.id)
    )
    plot = result.scalar_one_or_none()
    if not plot:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Plot not found"
        )
    return plot


async def _invalidate_plot_cache(user_id, plot_id: str | None = None):
    """Remove the user's list cache and optionally a detail key."""
    await redis_delete(_plots_list_key(user_id))
    if plot_id:
        await redis_delete(_plot_detail_key(plot_id))


@router.post("", response_model=PlotResponse, status_code=status.HTTP_201_CREATED)
async def create_plot(
    body: PlotCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    plot = Plot(
        user_id=current_user.id,
        name=body.name,
        location=body.location,
        area_hectares=body.area_hectares,
        soil_type=body.soil_type,
        latitude=body.latitude,
        longitude=body.longitude,
    )
    db.add(plot)
    await db.commit()
    await db.refresh(plot)
    await _invalidate_plot_cache(current_user.id)
    return plot


@router.get("", response_model=list[PlotResponse])
async def list_plots(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    cache_key = _plots_list_key(current_user.id)

    # --- Cache-aside: try Redis first ---
    cached = await cache_get_json(cache_key)
    if cached is not None:
        logger.info("Plots list cache HIT user=%s", current_user.id)
        return cached

    # --- Cache miss: query DB ---
    result = await db.execute(
        select(Plot).where(Plot.user_id == current_user.id)
    )
    plots = result.scalars().all()
    # Serialize to plain list[dict] so it round-trips through JSON cleanly
    payload = [PlotResponse.model_validate(p).model_dump(mode="json") for p in plots]

    await cache_set_json(cache_key, payload, ex=CACHE_TTL)
    return payload


@router.get("/{plot_id}", response_model=PlotDetailResponse)
async def get_plot(
    plot_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    cache_key = _plot_detail_key(plot_id)

    # --- Cache-aside ---
    cached = await cache_get_json(cache_key)
    if cached is not None:
        logger.info("Plot detail cache HIT plot=%s", plot_id)
        return cached

    # --- DB (ownership baked into WHERE — no 403 leak) ---
    result = await db.execute(
        select(Plot)
        .options(selectinload(Plot.plot_crops), selectinload(Plot.plot_livestock))
        .where(Plot.id == plot_id, Plot.user_id == current_user.id)
    )
    plot = result.scalar_one_or_none()
    if not plot:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Plot not found"
        )

    payload = PlotDetailResponse.model_validate(plot).model_dump(mode="json")
    await cache_set_json(cache_key, payload, ex=CACHE_TTL)
    return payload


@router.post("/{plot_id}/crops", response_model=PlotCropResponse, status_code=status.HTTP_201_CREATED)
async def add_plot_crop(
    plot_id: str,
    body: PlotCropCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _get_owned_plot(plot_id, db, current_user)

    # DB column is TIMESTAMP WITHOUT TIME ZONE — strip tzinfo if the client
    # sent a timezone-aware value (e.g. trailing "Z"), or asyncpg raises
    # "can't subtract offset-naive and offset-aware datetimes".
    sowing_date = body.sowing_date
    if sowing_date is not None and sowing_date.tzinfo is not None:
        sowing_date = sowing_date.replace(tzinfo=None)

    plot_crop = PlotCrop(
        plot_id=plot_id,
        crop_type=body.crop_type,
        sowing_date=sowing_date,
        growth_stage=body.growth_stage,
    )
    db.add(plot_crop)
    await db.commit()
    await db.refresh(plot_crop)
    await _invalidate_plot_cache(current_user.id, plot_id)
    return plot_crop


@router.post("/{plot_id}/livestock", response_model=PlotLivestockResponse, status_code=status.HTTP_201_CREATED)
async def add_plot_livestock(
    plot_id: str,
    body: PlotLivestockCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _get_owned_plot(plot_id, db, current_user)

    livestock = PlotLivestock(
        plot_id=plot_id,
        species=body.species,
        count=body.count,
        health_status=body.health_status,
    )
    db.add(livestock)
    await db.commit()
    await db.refresh(livestock)
    await _invalidate_plot_cache(current_user.id, plot_id)
    return livestock
