from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, status
from sqlalchemy.ext.asyncio import AsyncSession
from db import get_db
from models.image import Image
from models.user import User
from schemas.image import ImageUploadResponse
from auth.utils import get_current_user
from cloudinary import uploader

router = APIRouter(prefix="/api/images", tags=["images"])

MAX_FILE_SIZE = 10 * 1024 * 1024  # 10 MB
ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".gif", ".webp"}
ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/gif", "image/webp"}

IMAGE_MAGIC_BYTES = {
    b"\xff\xd8\xff": "jpeg",
    b"\x89PNG": "png",
    b"GIF87a": "gif",
    b"GIF89a": "gif",
    b"RIFF": "webp",
    b"BM": "bmp",
}


def _check_magic_bytes(header: bytes) -> bool:
    for magic in IMAGE_MAGIC_BYTES:
        if header.startswith(magic):
            return True
    return False


@router.post("/upload", response_model=ImageUploadResponse, status_code=status.HTTP_201_CREATED)
async def upload_image(
    file: UploadFile = File(...),
    image_type: str = "crop",
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # --- File size validation ---
    contents = await file.read()
    if len(contents) > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"File too large. Maximum size is {MAX_FILE_SIZE // (1024 * 1024)} MB",
        )

    # --- File extension validation ---
    filename = (file.filename or "").lower()
    ext = "." + filename.rsplit(".", 1)[-1] if "." in filename else ""
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid file type. Allowed: {', '.join(sorted(ALLOWED_EXTENSIONS))}",
        )

    # --- Content-type validation ---
    if file.content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid content type",
        )

    # --- Magic bytes validation (don't trust extension alone) ---
    if not _check_magic_bytes(contents[:16]):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File content does not match a valid image format",
        )

    # --- Upload to Cloudinary ---
    try:
        result = uploader.upload_resource(contents, folder="kissanai")
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Image upload failed",
        )

    # --- Save to database ---
    image = Image(
        user_id=current_user.id,
        image_url=result["secure_url"],
        image_type=image_type,
    )
    db.add(image)
    await db.commit()
    await db.refresh(image)

    return ImageUploadResponse(
        id=image.id,
        image_url=image.image_url,
        image_type=image.image_type,
        public_id=result.get("public_id"),
        uploaded_at=image.uploaded_at,
    )
