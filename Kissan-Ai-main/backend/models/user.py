from sqlalchemy import Column, String, Boolean, DateTime, Float
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from db import Base
import uuid
from datetime import datetime

class User(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(String(255), unique=True, nullable=False)
    phone = Column(String(20), unique=True, nullable=True)
    password_hash = Column(String(255), nullable=False)
    full_name = Column(String(255), nullable=True)
    profile_image_url = Column(String(500), nullable=True)
    preferred_language = Column(String(10), default="ur")
    is_onboarded = Column(Boolean, default=False)

    # Farm / profile details
    farm_name = Column(String(255), nullable=True)
    farm_location = Column(String(255), nullable=True)
    province = Column(String(100), nullable=True)
    district = Column(String(100), nullable=True)
    city = Column(String(100), nullable=True)
    farm_size = Column(Float, nullable=True)
    farm_size_unit = Column(String(20), nullable=True)
    farmer_type = Column(String(100), nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    plots = relationship("Plot", back_populates="user")
    images = relationship("Image", back_populates="user")
    chat_history = relationship("ChatHistory", back_populates="user")
    analysis_history = relationship("AnalysisHistory", back_populates="user")
    plants = relationship("Plant", back_populates="user", cascade="all, delete-orphan")
