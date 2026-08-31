import asyncio
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, Header, Request, status
from sqlalchemy.ext.asyncio import AsyncSession
from db import get_db
from models.image import Image
from models.disease_detection import DiseaseDetection
from models.analysis_history import AnalysisHistory
from models.user import User
from schemas.disease import DiseaseDetectionResponse
from auth.utils import get_current_user
from cloudinary import uploader
from utils.validation import check_magic_bytes, validate_extension, MAX_FILE_SIZE, ALLOWED_EXTENSIONS
from services.gemini_service import gemini_service
from rate_limiter import limiter

router = APIRouter(prefix="/api/disease", tags=["disease"])


@router.post("/detect", response_model=DiseaseDetectionResponse, status_code=status.HTTP_200_OK)
@limiter.limit("10/minute")
async def detect_disease(
    request: Request,
    file: UploadFile = File(...),
    language: Optional[str] = Form("english"),
    crop_name: Optional[str] = Form(None, description="Known crop type (e.g. Pomegranate) — prioritized over visual identification"),
    accept_language: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Determine requested language from Form or Header
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
            uploader.upload_resource, contents, folder="kissanai/disease"
        )
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Image upload failed")

    # --- 5. Safely extract image_url & Save image record ---
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

    image = Image(user_id=current_user.id, image_url=image_url, image_type="disease")
    db.add(image)
    await db.commit()
    await db.refresh(image)

    # --- 6. Structured Multi-Model Fallback Leaf Diagnosis in Requested Language ---
    parsed_data, formatted_markdown, model_used = await gemini_service.diagnose_leaf_image(
        image_bytes=contents,
        mime_type=content_type,
        language=selected_language,
        timeout=15.0,
        crop_name=crop_name,
    )

    # Dynamically extract localized disease_name and confidence_score
    disease_name = parsed_data.get("disease_name") or "Plant Disease Diagnosis"
    disease_category = parsed_data.get("disease_category")
    confidence_val = parsed_data.get("confidence_score", 0.95)
    try:
        confidence_score = float(confidence_val)
    except (ValueError, TypeError):
        confidence_score = 0.95

    # --- 7. Save detection record to database ---
    detection = DiseaseDetection(
        image_id=image.id,
        user_id=current_user.id,
        disease_name=disease_name[:255],
        disease_category=disease_category[:50] if disease_category else None,
        confidence_score=confidence_score,
        model_version=model_used,
    )
    db.add(detection)
    await db.flush()  # get detection.id before creating history

    # --- 7b. Log to analysis history ---
    history_entry = AnalysisHistory(
        user_id=current_user.id,
        analysis_type="disease",
        reference_id=detection.id,
        result_snapshot={
            "disease_name": detection.disease_name,
            "disease_category": detection.disease_category,
            "confidence_score": detection.confidence_score,
            "crop_name": parsed_data.get("crop_name"),
            "diagnosis_summary": formatted_markdown[:500],
        },
    )
    db.add(history_entry)

    await db.commit()
    await db.refresh(detection)

    # --- 8. Return response containing localized diagnosis & dynamic disease name ---
    return DiseaseDetectionResponse(
        id=detection.id,
        image_id=image.id,
        crop_name=parsed_data.get("crop_name"),
        disease_name=detection.disease_name,
        disease_category=detection.disease_category,
        confidence_score=detection.confidence_score,
        model_version=detection.model_version,
        detected_at=detection.detected_at,
        diagnosis=formatted_markdown,
    )
