import time
import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app
from app.config import get_settings
from app.services.auth_service import (
    normalize_phone,
    validate_and_normalize_phone,
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

def test_validate_and_normalize_phone_valid():
    valid_numbers = [
        "9876543210",
        "8123456789",
        "7000111222",
        "6999888777",
        "+919876543210",
        "918123456789",
        "07000111222",
    ]
    for num in valid_numbers:
        norm = validate_and_normalize_phone(num)
        assert norm.startswith("+91")
        assert len(norm) == 13
        assert norm[3] in "6789"

def test_validate_and_normalize_phone_invalid():
    invalid_cases = [
        ("1234567890", "starts with 1"),
        ("5555555555", "starts with 5"),
        ("0123456789", "starts with 0/1"),
        ("98765", "too short"),
        ("98765432101234", "too long"),
        ("98765abcde", "contains letters"),
        ("", "empty"),
        ("          ", "whitespace"),
    ]
    for bad_num, reason in invalid_cases:
        with pytest.raises(ValueError):
            validate_and_normalize_phone(bad_num)

def test_is_demo_phone_detection():
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
        send_resp = await ac.post("/api/v1/auth/otp/send", json={"phone": "9876543210"})
        assert send_resp.status_code == 200
        send_data = send_resp.json()
        assert "Demo mode" in send_data["message"]
        assert send_data["debug_otp"] == "123456"

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
async def test_any_valid_indian_mobile_number_can_login_with_demo_otp():
    """Verify that multiple different valid 10-digit Indian numbers can log in with 123456."""
    test_numbers = ["9123456789", "8987654321", "7890123456", "6789012345"]
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        for phone in test_numbers:
            send_resp = await ac.post("/api/v1/auth/otp/send", json={"phone": phone})
            assert send_resp.status_code == 200
            send_data = send_resp.json()
            assert "Demo mode" in send_data["message"]
            assert send_data["debug_otp"] == "123456"

            verify_resp = await ac.post("/api/v1/auth/otp/verify", json={
                "phone": phone,
                "otp": "123456"
            })
            assert verify_resp.status_code == 200
            tokens = verify_resp.json()
            assert "access_token" in tokens
            assert "refresh_token" in tokens

@pytest.mark.asyncio
async def test_repeated_login_resolves_to_same_user_account():
    """Ensure logging in again with the same number does not create duplicate user accounts."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        unique_suffix = f"{int(time.time() * 1000) % 100000000:08d}"
        phone_raw = f"98{unique_suffix}"

        # First login
        send_1 = await ac.post("/api/v1/auth/otp/send", json={"phone": phone_raw})
        assert send_1.status_code == 200
        verify_1 = await ac.post("/api/v1/auth/otp/verify", json={"phone": phone_raw, "otp": "123456"})
        assert verify_1.status_code == 200
        data_1 = verify_1.json()
        assert data_1["is_new_user"] is True
        token_1 = data_1["access_token"]

        me_1 = await ac.get("/api/v1/me", headers={"Authorization": f"Bearer {token_1}"})
        assert me_1.status_code == 200
        user_id_1 = me_1.json()["id"]

        # Second login with E.164 +91 prefix for the exact same number
        phone_e164 = f"+91{phone_raw}"
        send_2 = await ac.post("/api/v1/auth/otp/send", json={"phone": phone_e164})
        assert send_2.status_code == 200
        verify_2 = await ac.post("/api/v1/auth/otp/verify", json={"phone": phone_e164, "otp": "123456"})
        assert verify_2.status_code == 200
        data_2 = verify_2.json()
        assert data_2["is_new_user"] is False
        token_2 = data_2["access_token"]

        me_2 = await ac.get("/api/v1/me", headers={"Authorization": f"Bearer {token_2}"})
        assert me_2.status_code == 200
        user_id_2 = me_2.json()["id"]

        # Must map to the exact same user ID
        assert user_id_1 == user_id_2

@pytest.mark.asyncio
async def test_invalid_mobile_numbers_rejected_by_api():
    """Ensure invalid lengths, non-digits, and invalid mobile prefixes are rejected with HTTP 400."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        invalid_phones = [
            "1234567890", # Starts with 1
            "5555555555", # Starts with 5
            "98765",      # Too short
            "98765abcde", # Letters
            "",           # Empty
        ]
        for bad_phone in invalid_phones:
            send_resp = await ac.post("/api/v1/auth/otp/send", json={"phone": bad_phone})
            assert send_resp.status_code == 400

            verify_resp = await ac.post("/api/v1/auth/otp/verify", json={"phone": bad_phone, "otp": "123456"})
            assert verify_resp.status_code == 400

@pytest.mark.asyncio
async def test_incorrect_otp_rejected():
    """Ensure wrong OTP values are rejected with HTTP 400."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        test_phone = "9345678901"
        await ac.post("/api/v1/auth/otp/send", json={"phone": test_phone})

        bad_verify = await ac.post("/api/v1/auth/otp/verify", json={
            "phone": test_phone,
            "otp": "999999"
        })
        assert bad_verify.status_code == 400
        assert bad_verify.json()["detail"] == "Invalid or expired OTP code"

@pytest.mark.asyncio
async def test_no_session_issued_without_verification():
    """Ensure access tokens are never returned unless verification succeeds."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        test_phone = "9456789012"
        send_resp = await ac.post("/api/v1/auth/otp/send", json={"phone": test_phone})
        assert send_resp.status_code == 200
        assert "access_token" not in send_resp.json()

        fail_resp = await ac.post("/api/v1/auth/otp/verify", json={
            "phone": test_phone,
            "otp": "000000"
        })
        assert fail_resp.status_code == 400
        assert "access_token" not in fail_resp.json()

@pytest.mark.asyncio
async def test_strict_production_mode_safeguard():
    """Ensure that if demo mode is explicitly disabled in production, real numbers require dynamic OTP."""
    settings = get_settings()
    orig_env = settings.APP_ENV
    orig_demo = settings.DEMO_MODE
    orig_univ = settings.ENABLE_UNIVERSAL_DEMO_OTP
    try:
        settings.APP_ENV = "production"
        settings.DEMO_MODE = False
        settings.ENABLE_UNIVERSAL_DEMO_OTP = False

        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            real_phone = "9112233445"
            send_resp = await ac.post("/api/v1/auth/otp/send", json={"phone": real_phone})
            assert send_resp.status_code == 200
            send_data = send_resp.json()
            assert send_data["debug_otp"] is None

            # Universal demo OTP 123456 must be rejected when demo mode is disabled in production
            bad_verify = await ac.post("/api/v1/auth/otp/verify", json={
                "phone": real_phone,
                "otp": "123456"
            })
            assert bad_verify.status_code == 400

            # Documented demo accounts MUST STILL WORK even when universal demo OTP is off
            demo_verify = await ac.post("/api/v1/auth/otp/verify", json={
                "phone": "9876543210",
                "otp": "123456"
            })
            assert demo_verify.status_code == 200
            assert "access_token" in demo_verify.json()
    finally:
        settings.APP_ENV = orig_env
        settings.DEMO_MODE = orig_demo
        settings.ENABLE_UNIVERSAL_DEMO_OTP = orig_univ
