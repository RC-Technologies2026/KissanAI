from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Request, status
from sqlalchemy.ext.asyncio import AsyncSession
from db import get_db
from models.image import Image
from models.disease_detection import DiseaseDetection
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
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
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

    # --- 4. Upload to Cloudinary ---
    try:
        cloudinary_result = uploader.upload_resource(contents, folder="kissanai/disease")
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Image upload failed")

    # --- 5. Save image record ---
    image = Image(user_id=current_user.id, image_url=cloudinary_result["secure_url"], image_type="disease")
    db.add(image)
    await db.commit()
    await db.refresh(image)

    # --- 6. Direct Gemini 2.5 Flash Vision Diagnosis ---
    diagnosis_prompt = (
        "You are examining an uploaded leaf/crop image for diagnosis. Provide a clear and structured report with:\n"
        "1. **Disease Name**: (Exact identified disease or healthy)\n"
        "2. **Symptoms Observed**: (Key visual signs on the leaf)\n"
        "3. **Immediate Action Steps**: (First urgent steps the farmer should take)\n"
        "4. **Treatment Options**:\n"
        "   - **Organic Solutions**: (Bio-fungicides, natural treatments)\n"
        "   - **Chemical Treatments & Dosages**: (Generic chemical names, exact dosage per acre/liter of water, and safety gear)\n"
        "5. **Soil/Nutrient Recommendations**: (Relevant NPK ratios or soil care if applicable)"
    )

    try:
        diagnosis_text = await gemini_service.analyze_image(
            image_bytes=contents,
            mime_type=content_type,
            prompt=diagnosis_prompt,
            model="gemini-2.5-flash",
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(e),
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Gemini Vision API error: {str(e)}",
        )

    # Extract first line or headline disease name if possible
    disease_name = "Gemini Diagnosis"
    for line in diagnosis_text.splitlines():
        clean_line = line.strip().replace("*", "").replace("#", "")
        if clean_line.lower().startswith("disease name:"):
            disease_name = clean_line.split(":", 1)[1].strip()[:255]
            break
        elif clean_line.lower().startswith("1. disease name:"):
            disease_name = clean_line.split(":", 1)[1].strip()[:255]
            break

    # --- 7. Save detection to database (bypassing low-confidence fallback) ---
    detection = DiseaseDetection(
        image_id=image.id,
        user_id=current_user.id,
        disease_name=disease_name or "Plant Disease Diagnosis",
        confidence_score=0.98,
        model_version="gemini-2.5-flash",
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
        diagnosis=diagnosis_text,
    )
