from fastapi import APIRouter, Depends, Query, status
from sqlalchemy import select, desc
from sqlalchemy.ext.asyncio import AsyncSession
from db import get_db
from models.analysis_history import AnalysisHistory
from models.user import User
from schemas.history import AnalysisHistoryResponse
from auth.utils import get_current_user
from typing import Optional

router = APIRouter(prefix="/api/history", tags=["history"])


@router.get("", response_model=list[AnalysisHistoryResponse])
async def get_analysis_history(
    analysis_type: Optional[str] = Query(None, description="Filter by type: disease, pest, crop, etc."),
    limit: int = Query(50, ge=1, le=200, description="Max results to return"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = select(AnalysisHistory).where(AnalysisHistory.user_id == current_user.id)

    if analysis_type:
        query = query.where(AnalysisHistory.analysis_type == analysis_type)

    query = query.order_by(desc(AnalysisHistory.created_at)).limit(limit)

    result = await db.execute(query)
    records = result.scalars().all()

    return records
