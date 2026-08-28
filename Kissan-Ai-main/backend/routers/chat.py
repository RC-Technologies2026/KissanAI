import asyncio
import os
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, desc
from sqlalchemy.ext.asyncio import AsyncSession
from db import get_db
from models.chat_history import ChatHistory
from models.user import User
from schemas.chat import ChatMessageRequest, ChatMessageResponse
from auth.utils import get_current_user
import google.generativeai as genai

router = APIRouter(prefix="/api/chat", tags=["chat"])

# Configure Gemini API
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)
    model = genai.GenerativeModel("gemini-2.0-flash")
else:
    model = None


@router.post("", response_model=ChatMessageResponse, status_code=status.HTTP_201_CREATED)
async def chat(
    body: ChatMessageRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # --- 1. Call Gemini API ---
    if model is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Gemini API not configured",
        )

    try:
        # Run sync Gemini call in thread pool to avoid blocking
        response = await asyncio.to_thread(model.generate_content, body.message)
        ai_response = response.text
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Gemini API error: {str(e)}",
        )

    # --- 2. Save to CHAT_HISTORY ---
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
