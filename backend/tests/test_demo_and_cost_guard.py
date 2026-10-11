import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app
from app.config import get_settings
from app.services.cost_guard import (
    check_and_increment_quota,
    LOCALIZED_QUOTA_MESSAGES,
    _user_usage,
    _ip_usage,
)
from app.services.auth_service import verify_otp, DEMO_PHONE_NUMBERS
from fastapi import HTTPException

@pytest.mark.asyncio
async def test_demo_accounts_seeded_and_auth():
    settings = get_settings()
    # Verify demo phones are defined
    assert "+919876543210" in DEMO_PHONE_NUMBERS
    assert "+919876543220" in DEMO_PHONE_NUMBERS

    # Demo phone accepts 123456
    assert verify_otp("+919876543210", "123456") is True

    # Real phone with wrong OTP is rejected
    assert verify_otp("+919999999999", "wrong_otp") is False

def test_cost_guard_ip_and_user_limits():
    test_ip = "192.168.1.99"
    test_user = "test-artisan-quota-01"

    # Reset test entries
    for key in list(_ip_usage.keys()):
        if key[1] == test_ip:
            del _ip_usage[key]
    for key in list(_user_usage.keys()):
        if key[1] == test_user:
            del _user_usage[key]

    # Calling within limit succeeds
    check_and_increment_quota(client_ip=test_ip, user_id=test_user, is_demo=False, lang="hi")

    # Six languages are supported with localized messages
    for lang in ["en", "hi", "ta", "te", "kn", "ml"]:
        assert lang in LOCALIZED_QUOTA_MESSAGES
        assert len(LOCALIZED_QUOTA_MESSAGES[lang]) > 10

    # Exhaust user demo cap (15)
    demo_user = "demo-artisan-exhaust"
    for _ in range(15):
        check_and_increment_quota(client_ip="10.0.0.1", user_id=demo_user, is_demo=True, lang="en")

    # 16th call raises HTTP 429
    with pytest.raises(HTTPException) as exc_info:
        check_and_increment_quota(client_ip="10.0.0.1", user_id=demo_user, is_demo=True, lang="ta")

    assert exc_info.value.status_code == 429
    assert exc_info.value.detail["code"] == "QUOTA_EXCEEDED"
    assert exc_info.value.detail["message"] == LOCALIZED_QUOTA_MESSAGES["ta"]
