from fastapi import APIRouter, Depends, HTTPException, status, Request, UploadFile, File
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from db import get_db
from models.user import User
from schemas.user import UserRegister, UserLogin, UserOut, Token, RefreshRequest, ProfileUpdateRequest
from auth.utils import hash_password, verify_password, create_access_token, create_refresh_token, get_current_user
from jose import JWTError, jwt
from auth.utils import SECRET_KEY, ALGORITHM
from rate_limiter import limiter
import cloudinary.uploader as cloudinary_uploader
import asyncio

router = APIRouter(prefix="/api/auth", tags=["auth"])


@router.post("/register", response_model=UserOut, status_code=status.HTTP_201_CREATED)
@limiter.limit("5/minute")
async def register(request: Request, user_data: UserRegister, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == user_data.email))
    existing_user = result.scalar_one_or_none()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )

    new_user = User(
        email=user_data.email,
        password_hash=hash_password(user_data.password),
        full_name=user_data.full_name,
        phone=user_data.phone,
    )
    db.add(new_user)
    await db.commit()
    await db.refresh(new_user)
    return new_user


@router.post("/login", response_model=Token)
@limiter.limit("10/minute")
async def login(request: Request, credentials: UserLogin, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == credentials.email))
    user = result.scalar_one_or_none()
    if not user or not verify_password(credentials.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    access_token = create_access_token(data={"sub": str(user.id)})
    refresh_token = create_refresh_token(data={"sub": str(user.id)})
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
    }


@router.post("/token", response_model=Token)
@limiter.limit("10/minute")
async def token(request: Request, form_data: OAuth2PasswordRequestForm = Depends(), db: AsyncSession = Depends(get_db)):
    """OAuth2 password-flow token endpoint for Swagger UI.

    Accepts form data with username (=email) and password.
    """
    result = await db.execute(select(User).where(User.email == form_data.username))
    user = result.scalar_one_or_none()
    if not user or not verify_password(form_data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    access_token = create_access_token(data={"sub": str(user.id)})
    refresh_token = create_refresh_token(data={"sub": str(user.id)})
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
    }


@router.post("/refresh", response_model=Token)
async def refresh(request: Request, body: RefreshRequest):
    """Exchange a valid refresh token for a new access + refresh token pair."""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired refresh token",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(body.refresh_token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        token_type: str = payload.get("type")
        if user_id is None or token_type != "refresh":
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    # Issue new pair (rotation)
    new_access = create_access_token(data={"sub": user_id})
    new_refresh = create_refresh_token(data={"sub": user_id})
    return {
        "access_token": new_access,
        "refresh_token": new_refresh,
        "token_type": "bearer",
    }


@router.get("/profile", response_model=UserOut)
async def get_profile(
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get current user's profile."""
    return current_user


@router.put("/profile", response_model=UserOut)
async def update_profile(
    request: Request,
    body: ProfileUpdateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Update user profile (name, phone, language, farm details)."""
    # Update fields if provided
    if body.full_name is not None:
        current_user.full_name = body.full_name
    if body.phone is not None:
        # Check if phone is already used by another user
        if body.phone:
            result = await db.execute(select(User).where(User.phone == body.phone, User.id != current_user.id))
            if result.scalar_one_or_none():
                raise HTTPException(status_code=400, detail="Phone number already in use")
        current_user.phone = body.phone
    if body.preferred_language is not None:
        current_user.preferred_language = body.preferred_language
    if body.farm_name is not None:
        current_user.farm_name = body.farm_name
    if body.farm_location is not None:
        current_user.farm_location = body.farm_location
    if body.province is not None:
        current_user.province = body.province
    if body.district is not None:
        current_user.district = body.district
    if body.city is not None:
        current_user.city = body.city
    if body.farm_size is not None:
        current_user.farm_size = body.farm_size
    if body.farm_size_unit is not None:
        current_user.farm_size_unit = body.farm_size_unit
    if body.farmer_type is not None:
        current_user.farmer_type = body.farmer_type
    
    await db.commit()
    await db.refresh(current_user)
    return current_user


@router.post("/profile/image", response_model=dict)
async def upload_profile_image(
    request: Request,
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Upload profile image to Cloudinary."""
    # Validate file type
    if file.content_type not in ["image/jpeg", "image/png", "image/webp"]:
        raise HTTPException(status_code=400, detail="Invalid file type. Only JPEG, PNG, and WebP are allowed.")
    
    # Read file
    contents = await file.read()
    if len(contents) > 5 * 1024 * 1024:  # 5MB limit
        raise HTTPException(status_code=413, detail="File too large. Maximum size is 5MB")
    
    # Upload to Cloudinary
    try:
        result = await asyncio.to_thread(
            cloudinary_uploader.upload,
            contents,
            folder="kissanai/profiles",
            resource_type="image"
        )
        image_url = result.get("secure_url")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Image upload failed: {str(e)}")
    
    # Update user's profile_image_url
    current_user.profile_image_url = image_url
    await db.commit()
    await db.refresh(current_user)
    
    return {"profile_image_url": image_url}
