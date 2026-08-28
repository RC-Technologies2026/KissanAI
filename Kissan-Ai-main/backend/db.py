from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker, declarative_base
from dotenv import load_dotenv
import os

load_dotenv()

Base = declarative_base()

_engine = None
_async_session = None

def _get_engine():
    global _engine
    if _engine is None:
        database_url = os.getenv("DATABASE_URL")
        if not database_url:
            raise ValueError("DATABASE_URL not set in environment")
        # Ensure async driver: postgresql+asyncpg://
        if database_url.startswith("postgres://"):
            database_url = database_url.replace("postgres://", "postgresql+asyncpg://", 1)
        elif database_url.startswith("postgresql://"):
            database_url = database_url.replace("postgresql://", "postgresql+asyncpg://", 1)
        _engine = create_async_engine(database_url, echo=False, future=True)
    return _engine

def _get_session_factory():
    global _async_session
    if _async_session is None:
        _async_session = sessionmaker(_get_engine(), class_=AsyncSession, expire_on_commit=False)
    return _async_session

async def get_db():
    async with _get_session_factory()() as session:
        yield session
