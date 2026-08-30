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

router = APIRouter(prefix="/api/plots", tags=["plots"])


async def _get_owned_plot(plot_id: str, db: AsyncSession, current_user: User) -> Plot:
    """Fetch a plot and verify the current user owns it, or raise 404/403."""
    result = await db.execute(select(Plot).where(Plot.id == plot_id))
    plot = result.scalar_one_or_none()
    if not plot:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Plot not found")
    if plot.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized")
    return plot


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
    return plot


@router.get("", response_model=list[PlotResponse])
async def list_plots(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(select(Plot).where(Plot.user_id == current_user.id))
    return result.scalars().all()


@router.get("/{plot_id}", response_model=PlotDetailResponse)
async def get_plot(
    plot_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Plot)
        .options(selectinload(Plot.plot_crops), selectinload(Plot.plot_livestock))
        .where(Plot.id == plot_id)
    )
    plot = result.scalar_one_or_none()
    if not plot:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Plot not found")
    if plot.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized")
    return plot


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
    return livestock
