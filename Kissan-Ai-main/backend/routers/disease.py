from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Request, status
from sqlalchemy.ext.asyncio import AsyncSession
from db import get_db
from models.image import Image
from models.disease_detection import DiseaseDetection
from models.user import User
from schemas.disease import DiseaseDetectionResponse, DiseaseFallbackResponse
from auth.utils import get_current_user
from cloudinary import uploader
from utils.validation import check_magic_bytes, validate_extension, MAX_FILE_SIZE, ALLOWED_EXTENSIONS
from vision.efficientnet import predict_disease, CONFIDENCE_THRESHOLD, MODEL_VERSION, DISEASE_CLASSES
from rate_limiter import limiter

router = APIRouter(prefix="/api/disease", tags=["disease"])


@router.post("/detect")
@limiter.limit("10/minute")
async def detect_disease(
    request: Request,
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # --- Read and validate file size ---
    contents = await file.read()
    if len(contents) > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"File too large. Maximum size is {MAX_FILE_SIZE // (1024 * 1024)} MB",
        )

    # --- Validate extension ---
    if not validate_extension(file.filename or ""):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid file type. Allowed: {', '.join(sorted(ALLOWED_EXTENSIONS))}",
        )

    # --- Validate content type ---
    if file.content_type not in {"image/jpeg", "image/png", "image/gif", "image/webp"}:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid content type")

    # --- Validate magic bytes ---
    if not check_magic_bytes(contents[:16]):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File content does not match a valid image format",
        )

    # --- Upload to Cloudinary ---
    try:
        cloudinary_result = uploader.upload_resource(contents, folder="kissanai/disease")
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Image upload failed")

    # --- Save image record ---
    image = Image(user_id=current_user.id, image_url=cloudinary_result["secure_url"], image_type="disease")
    db.add(image)
    await db.commit()
    await db.refresh(image)

    # --- Run EfficientNet-B0 inference ---
    try:
        disease_name, confidence = predict_disease(contents)
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Detection failed")

    # --- Confidence gate (threshold = 0.70) ---
    if confidence < CONFIDENCE_THRESHOLD:
        # Build top-2 candidate guesses from model output
        top_candidates = [disease_name]
        for cls in DISEASE_CLASSES:
            if cls != disease_name and len(top_candidates) < 2:
                top_candidates.append(cls)

        return DiseaseFallbackResponse(
            message="Consult an agronomist",
            top_candidates=top_candidates,
            confidence_score=round(confidence, 4),
            threshold=CONFIDENCE_THRESHOLD,
            image_id=image.id,
        )

    # --- Save detection to database ---
    detection = DiseaseDetection(
        image_id=image.id,
        user_id=current_user.id,
        disease_name=disease_name,
        confidence_score=confidence,
        model_version=MODEL_VERSION,
    )
    db.add(detection)
    await db.commit()
    await db.refresh(detection)

    return DiseaseDetectionResponse(
        id=detection.id,
        image_id=image.id,
        disease_name=detection.disease_name,
        confidence_score=detection.confidence_score,
        model_version=detection.model_version,
        detected_at=detection.detected_at,
    )
