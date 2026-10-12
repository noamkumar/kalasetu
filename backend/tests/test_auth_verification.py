import time
import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app
from app.config import get_settings
from app.services.auth_service import (
    normalize_phone,
    is_demo_phone,
    send_otp,
    verify_otp,
    _otp_store,
)

def test_normalize_phone_formats():
    assert normalize_phone("+919876543210") == "+919876543210"
    assert normalize_phone("9876543210") == "+919876543210"
    assert normalize_phone("09876543210") == "+919876543210"
    assert normalize_phone("919876543210") == "+919876543210"
    assert normalize_phone("+91 98765-43210") == "+919876543210"
    assert normalize_phone(" 98765 43210 ") == "+919876543210"

def test_is_demo_phone_detection():
    # Both 10-digit and E.164 formats for all 5 documented demo accounts
    demo_numbers = [
        "9876543210", "+919876543210",
        "9876543211", "+919876543211",
        "9876543212", "+919876543212",
        "9876543220", "+919876543220",
        "9876543221", "+919876543221",
    ]
    for num in demo_numbers:
        assert is_demo_phone(num) is True, f"{num} should be recognized as a demo phone"

    assert is_demo_phone("9999999999") is False
    assert is_demo_phone("+919999999999") is False
    assert is_demo_phone("9123456789") is False

@pytest.mark.asyncio
async def test_demo_phone_flow_with_10_digits():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        # Send OTP for 10-digit demo number
        send_resp = await ac.post("/api/v1/auth/otp/send", json={"phone": "9876543210"})
        assert send_resp.status_code == 200
        send_data = send_resp.json()
        assert send_data["message"] == "OTP sent successfully"
        assert send_data["debug_otp"] == "123456"

        # Verify with 123456
        verify_resp = await ac.post("/api/v1/auth/otp/verify", json={
            "phone": "9876543210",
            "otp": "123456"
        })
        assert verify_resp.status_code == 200
        tokens = verify_resp.json()
        assert "access_token" in tokens
        assert "refresh_token" in tokens
        assert tokens["token_type"] == "bearer"

@pytest.mark.asyncio
async def test_demo_phone_flow_with_plus_91():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        # Send OTP with E.164 +91 prefix
        send_resp = await ac.post("/api/v1/auth/otp/send", json={"phone": "+919876543211"})
        assert send_resp.status_code == 200
        assert send_resp.json()["debug_otp"] == "123456"

        # Verify with 123456
        verify_resp = await ac.post("/api/v1/auth/otp/verify", json={
            "phone": "+919876543211",
            "otp": "123456"
        })
        assert verify_resp.status_code == 200
        assert "access_token" in verify_resp.json()

@pytest.mark.asyncio
async def test_demo_phone_rejects_invalid_otp():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        verify_resp = await ac.post("/api/v1/auth/otp/verify", json={
            "phone": "9876543210",
            "otp": "654321"
        })
        assert verify_resp.status_code == 400
        assert verify_resp.json()["detail"] == "Invalid or expired OTP code"

@pytest.mark.asyncio
async def test_non_demo_phone_production_behavior():
    settings = get_settings()
    orig_env = settings.APP_ENV
    try:
        settings.APP_ENV = "production"
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            real_phone = "9112233445"
            # 1. Send OTP in production for a real phone
            send_resp = await ac.post("/api/v1/auth/otp/send", json={"phone": real_phone})
            assert send_resp.status_code == 200
            send_data = send_resp.json()
            # In production, debug_otp is NOT exposed for non-demo phones
            assert send_data["debug_otp"] is None

            # 2. Universal demo OTP 123456 MUST BE REJECTED for real phones
            bad_verify = await ac.post("/api/v1/auth/otp/verify", json={
                "phone": real_phone,
                "otp": "123456"
            })
            assert bad_verify.status_code == 400
            assert bad_verify.json()["detail"] == "Invalid or expired OTP code"

            # 3. Dynamic OTP from store MUST WORK
            norm = normalize_phone(real_phone)
            stored = _otp_store.get(norm)
            assert stored is not None
            dynamic_otp = stored["otp"]
            assert dynamic_otp != "123456"

            good_verify = await ac.post("/api/v1/auth/otp/verify", json={
                "phone": real_phone,
                "otp": dynamic_otp
            })
            assert good_verify.status_code == 200
            assert "access_token" in good_verify.json()
    finally:
        settings.APP_ENV = orig_env

@pytest.mark.asyncio
async def test_expired_otp_is_rejected():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        test_phone = "9555666777"
        send_resp = await ac.post("/api/v1/auth/otp/send", json={"phone": test_phone})
        assert send_resp.status_code == 200

        norm = normalize_phone(test_phone)
        # Artificially expire the record
        if norm in _otp_store:
            _otp_store[norm]["expires_at"] = time.time() - 100

        verify_resp = await ac.post("/api/v1/auth/otp/verify", json={
            "phone": test_phone,
            "otp": "123456"
        })
        assert verify_resp.status_code == 400
        assert verify_resp.json()["detail"] == "Invalid or expired OTP code"
