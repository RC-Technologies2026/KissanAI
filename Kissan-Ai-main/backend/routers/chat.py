import asyncio
import logging
import os
from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select, desc
from sqlalchemy.ext.asyncio import AsyncSession
from db import get_db
from models.chat_history import ChatHistory
from models.user import User
from schemas.chat import ChatMessageRequest, ChatMessageResponse
from auth.utils import get_current_user
from rate_limiter import limiter
from services.gemini_service import gemini_service
from prompts import CHAT_USER_PROMPT_TEMPLATE

logger = logging.getLogger("kissanai.chat")
router = APIRouter(prefix="/api/chat", tags=["chat"])


@router.post("", response_model=ChatMessageResponse, status_code=status.HTTP_201_CREATED)
@limiter.limit("15/minute")
async def chat(
    request: Request,
    body: ChatMessageRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    try:
        prompt = CHAT_USER_PROMPT_TEMPLATE.format(message=body.message)
        # 15s timeout — fast enough for warm server, graceful on cold start
        ai_response = await gemini_service.generate_response(prompt, timeout=15.0)
        logger.info("Chat response generated successfully")
    except ValueError as e:
        logger.error("Chat ValueError: %s", e)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(e),
        )
    except Exception as e:
        logger.error("Chat Gemini API error: %s", e, exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Gemini API error: {str(e)}",
        )

    chat_entry = ChatHistory(
        user_id=current_user.id,
        message=body.message,
        response=ai_response,
    )
    db.add(chat_entry)
    await db.commit()
    await db.refresh(chat_entry)

    return chat_entry


@router.get("", response_model=list[ChatMessageResponse])
async def get_chat_history(
    limit: int = 50,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get user's chat history (most recent first)."""
    query = (
        select(ChatHistory)
        .where(ChatHistory.user_id == current_user.id)
        .order_by(desc(ChatHistory.created_at))
        .limit(limit)
    )
    result = await db.execute(query)
    records = result.scalars().all()
    return records


@router.delete("", status_code=status.HTTP_204_NO_CONTENT)
async def clear_chat_history(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Delete all chat history for the current user."""
    query = (
        select(ChatHistory)
        .where(ChatHistory.user_id == current_user.id)
    )
    result = await db.execute(query)
    records = result.scalars().all()
    for record in records:
        await db.delete(record)
    await db.commit()
