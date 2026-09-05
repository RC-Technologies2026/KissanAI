import asyncio
from typing import Optional, List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, Header, Request, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from db import get_db
from models.image import Image
from models.plant import Plant
from models.plant_diagnosis import PlantDiagnosis
from models.analysis_history import AnalysisHistory
from models.user import User
from schemas.plant import (
    PlantCreate,
    PlantResponse,
    PlantDiagnosisResponse,
    PlantDiagnosisFallbackResponse,
)
from auth.utils import get_current_user
from cloudinary import uploader
from utils.validation import check_magic_bytes, validate_extension, MAX_FILE_SIZE, ALLOWED_EXTENSIONS
from services.gemini_service import gemini_service
from rate_limiter import limiter

router = APIRouter(prefix="/api/plants", tags=["plants"])


# ---------------------------------------------------------------------------
# Plant CRUD endpoints
# ---------------------------------------------------------------------------

@router.post("", response_model=PlantResponse, status_code=status.HTTP_201_CREATED)
async def create_plant(
    payload: PlantCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Register / create a new plant for the authenticated user."""
    plant = Plant(
        user_id=current_user.id,
        plant_name=payload.plant_name,
        species=payload.species,
        image_url=payload.image_url,
        health_status=payload.health_status or "healthy",
        notes=payload.notes,
    )
    db.add(plant)
    await db.commit()
    await db.refresh(plant)
    return plant


@router.get("", response_model=List[PlantResponse])
async def list_plants(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List all plants belonging to the authenticated user."""
    result = await db.execute(
        select(Plant).where(Plant.user_id == current_user.id).order_by(Plant.created_at.desc())
    )
    return result.scalars().all()


@router.get("/{plant_id}", response_model=PlantResponse)
async def get_plant(
    plant_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get a single plant by ID (must belong to the authenticated user)."""
    result = await db.execute(
        select(Plant).where(Plant.id == plant_id, Plant.user_id == current_user.id)
    )
    plant = result.scalar_one_or_none()
    if not plant:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Plant not found")
    return plant


# ---------------------------------------------------------------------------
# Plant Diagnosis endpoint
# ---------------------------------------------------------------------------

@router.post("/{plant_id}/diagnose", response_model=PlantDiagnosisResponse, status_code=status.HTTP_200_OK)
@limiter.limit("10/minute")
async def diagnose_plant(
    request: Request,
    plant_id: UUID,
    file: UploadFile = File(...),
    language: Optional[str] = Form("english"),
    accept_language: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Upload an image of a plant, run Gemini vision diagnosis, and store the result."""

    # --- 0. Verify the plant belongs to this user ---
    result = await db.execute(
        select(Plant).where(Plant.id == plant_id, Plant.user_id == current_user.id)
    )
    plant = result.scalar_one_or_none()
    if not plant:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Plant not found")

    selected_language = language or accept_language or "english"

    # --- 1. Read and validate file size ---
    contents = await file.read()
    if len(contents) > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"File too large. Maximum size is {MAX_FILE_SIZE // (1024 * 1024)} MB",
        )

    # --- 2. Validate extension & content type ---
    if not validate_extension(file.filename or ""):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid file type. Allowed: {', '.join(sorted(ALLOWED_EXTENSIONS))}",
        )

    content_type = file.content_type or "image/jpeg"
    if content_type not in {"image/jpeg", "image/png", "image/gif", "image/webp"}:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid content type")

    # --- 3. Validate magic bytes ---
    if not check_magic_bytes(contents[:16]):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File content does not match a valid image format",
        )

    # --- 4. Upload to Cloudinary (non-blocking) ---
    try:
        cloudinary_result = await asyncio.to_thread(
            uploader.upload_resource, contents, folder="kissanai/plants"
        )
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Image upload failed")

    # --- 5. Extract image_url & save image record ---
    if isinstance(cloudinary_result, dict):
        image_url = cloudinary_result.get("secure_url") or cloudinary_result.get("url")
    else:
        if hasattr(cloudinary_result, "build_url"):
            try:
                image_url = cloudinary_result.build_url(secure=True)
            except Exception:
                image_url = getattr(cloudinary_result, "secure_url", None) or getattr(cloudinary_result, "url", str(cloudinary_result))
        else:
            image_url = getattr(cloudinary_result, "secure_url", None) or getattr(cloudinary_result, "url", str(cloudinary_result))

    image = Image(user_id=current_user.id, image_url=image_url, image_type="plant")
    db.add(image)
    await db.commit()
    await db.refresh(image)

    # --- 6. Gemini plant diagnosis ---
    diagnosis_result = await gemini_service.diagnose_plant_image(
        image_bytes=contents,
        mime_type=content_type,
        language=selected_language,
        timeout=15.0,
    )

    # --- 6b. Handle genuinely-unusable image fallback ---
    if isinstance(diagnosis_result, PlantDiagnosisFallbackResponse):
        return diagnosis_result

    parsed_data, formatted_markdown, model_used = diagnosis_result

    # Extract fields from parsed response
    issue_name = parsed_data.get("issue_name") or "Plant Issue Diagnosis"
    issue_category = parsed_data.get("issue_category")
    confidence_val = parsed_data.get("confidence_score")
    try:
        confidence_score = float(confidence_val) if confidence_val is not None else None
    except (ValueError, TypeError):
        confidence_score = None

    # Ensure minimum confidence for valid diagnoses (Groq often returns low values)
    if confidence_score is not None and confidence_score < 0.75:
        confidence_score = 0.75

    # --- 7. Save plant diagnosis record ---
    diagnosis = PlantDiagnosis(
        plant_id=plant.id,
        image_id=image.id,
        issue_name=issue_name[:255],
        issue_category=issue_category[:50] if issue_category else None,
        confidence_score=confidence_score,
        diagnosis=formatted_markdown,
    )
    db.add(diagnosis)
    await db.flush()

    # Update plant health_status based on diagnosis
    plant.health_status = "sick" if issue_category and issue_category != "healthy" else "healthy"

    # --- 7b. Log to analysis history ---
    history_entry = AnalysisHistory(
        user_id=current_user.id,
        analysis_type="plant_diagnosis",
        reference_id=diagnosis.id,
        result_snapshot={
            "plant_name": plant.plant_name,
            "issue_name": diagnosis.issue_name,
            "issue_category": diagnosis.issue_category,
            "confidence_score": diagnosis.confidence_score,
            "plant_species": parsed_data.get("plant_species"),
            "diagnosis_summary": formatted_markdown[:500],
        },
    )
    db.add(history_entry)

    await db.commit()
    await db.refresh(diagnosis)

    # --- 8. Return response ---
    return PlantDiagnosisResponse(
        id=diagnosis.id,
        plant_id=diagnosis.plant_id,
        image_id=diagnosis.image_id,
        issue_name=diagnosis.issue_name,
        issue_category=diagnosis.issue_category,
        confidence_score=diagnosis.confidence_score,
        diagnosis=diagnosis.diagnosis,
        detected_at=diagnosis.detected_at,
    )
