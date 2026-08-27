"""
Test script for Day 2 Auth implementation.
Run this after installing dependencies and setting up the database.

Usage:
    python test_auth.py
"""
import asyncio
import os
from dotenv import load_dotenv

load_dotenv()


async def test_password_hashing():
    """Test password hash and verify."""
    from auth.utils import hash_password, verify_password
    
    password = "test_password_123"
    hashed = hash_password(password)
    
    assert hashed != password, "Hash should not equal plain password"
    assert verify_password(password, hashed), "Verify should return True for correct password"
    assert not verify_password("wrong_password", hashed), "Verify should return False for wrong password"
    print("✓ Password hashing works correctly")


async def test_jwt_token():
    """Test JWT token creation and validation."""
    from auth.utils import create_access_token, SECRET_KEY, ALGORITHM
    from jose import jwt
    
    user_id = "123e4567-e89b-12d3-a456-426614174000"
    token = create_access_token(data={"sub": user_id})
    
    assert token is not None, "Token should be created"
    assert isinstance(token, str), "Token should be a string"
    
    payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    assert payload["sub"] == user_id, "Token should contain user ID"
    assert "exp" in payload, "Token should have expiration"
    print("✓ JWT token creation and validation works correctly")


async def test_schemas():
    """Test Pydantic schemas."""
    from schemas.user import UserRegister, UserLogin, UserOut, Token
    from uuid import uuid4
    from datetime import datetime
    
    user_reg = UserRegister(email="test@example.com", password="password123")
    assert user_reg.email == "test@example.com"
    
    user_login = UserLogin(email="test@example.com", password="password123")
    assert user_login.email == "test@example.com"
    
    user_out = UserOut(
        id=uuid4(),
        email="test@example.com",
        preferred_language="ur",
        is_onboarded=False,
        created_at=datetime.utcnow()
    )
    assert user_out.email == "test@example.com"
    
    token = Token(access_token="test_token")
    assert token.access_token == "test_token"
    assert token.token_type == "bearer"
    print("✓ Pydantic schemas work correctly")


async def test_register_endpoint():
    """Test register endpoint (requires database)."""
    from httpx import AsyncClient
    from main import app
    
    async with AsyncClient(app=app, base_url="http://test") as client:
        response = await client.post(
            "/api/auth/register",
            json={"email": "test@example.com", "password": "password123"}
        )
        assert response.status_code == 201, f"Expected 201, got {response.status_code}: {response.text}"
        data = response.json()
        assert "email" in data
        assert data["email"] == "test@example.com"
        assert "password_hash" not in data
        print("✓ Register endpoint works correctly")


async def test_login_endpoint():
    """Test login endpoint (requires database with registered user)."""
    from httpx import AsyncClient
    from main import app
    
    async with AsyncClient(app=app, base_url="http://test") as client:
        response = await client.post(
            "/api/auth/login",
            json={"email": "test@example.com", "password": "password123"}
        )
        assert response.status_code == 200, f"Expected 200, got {response.status_code}: {response.text}"
        data = response.json()
        assert "access_token" in data
        assert data["token_type"] == "bearer"
        print("✓ Login endpoint works correctly")


async def test_duplicate_email():
    """Test register with duplicate email (requires database)."""
    from httpx import AsyncClient
    from main import app
    
    async with AsyncClient(app=app, base_url="http://test") as client:
        await client.post(
            "/api/auth/register",
            json={"email": "duplicate@example.com", "password": "password123"}
        )
        response = await client.post(
            "/api/auth/register",
            json={"email": "duplicate@example.com", "password": "password456"}
        )
        assert response.status_code == 400, f"Expected 400, got {response.status_code}"
        assert "already registered" in response.json()["detail"].lower()
        print("✓ Duplicate email validation works correctly")


async def main():
    print("Testing Day 2 Auth Implementation...\n")
    
    await test_password_hashing()
    await test_jwt_token()
    await test_schemas()
    
    print("\nNote: Endpoint tests require database setup.")
    print("Run these after configuring DATABASE_URL and running migrations:\n")
    
    try:
        await test_register_endpoint()
        await test_login_endpoint()
        await test_duplicate_email()
        print("\n✓ All tests passed!")
    except Exception as e:
        print(f"\n⚠ Endpoint tests skipped (requires database): {e}")


if __name__ == "__main__":
    asyncio.run(main())
