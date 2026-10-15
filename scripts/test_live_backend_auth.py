import json
import sys
import urllib.request
import urllib.error

LIVE_BASE = "https://kalasetu-backend-s3uq.onrender.com"
API_BASE = f"{LIVE_BASE}/api/v1"

def mask_token(token: str) -> str:
    if not token or len(token) < 12:
        return "[REDACTED]"
    return f"{token[:6]}...{token[-4:]} [REDACTED]"

def test_live_auth_flow():
    print("=============================================================")
    print("      KalaSetu Live Backend Verification & Auth Flow")
    print("=============================================================")
    print(f"Target Backend: {LIVE_BASE}\n")

    # 1. Health Check
    health_url = f"{LIVE_BASE}/health"
    print(f"[1/6] Testing Health Endpoint: {health_url}")
    req = urllib.request.Request(health_url)
    with urllib.request.urlopen(req, timeout=15) as resp:
        assert resp.status == 200, f"Health check failed with {resp.status}"
        health_data = json.loads(resp.read().decode())
        print(f"      Status: {health_data.get('status')} | Version: {health_data.get('version')} | Env: {health_data.get('environment')}")
        print(f"      Demo Mode: {health_data.get('demo_mode')} | AI Mode: {health_data.get('ai_mode')}")
        print(f"      Git Commit: {health_data.get('git_commit', 'n/a')}")

    # 2. Send OTP for Demo Account (10-digit raw format)
    demo_phone_raw = "9876543210"
    send_url = f"{API_BASE}/auth/otp/send"
    print(f"\n[2/6] Testing OTP Send for demo phone '{demo_phone_raw}': {send_url}")
    req = urllib.request.Request(
        send_url,
        data=json.dumps({"phone": demo_phone_raw}).encode(),
        headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        assert resp.status == 200
        send_data = json.loads(resp.read().decode())
        print(f"      Response: status={resp.status} | message='{send_data.get('message')}'")
        print(f"      Demo OTP Returned: '{send_data.get('debug_otp')}' (matches expected '123456')")
        assert send_data.get("debug_otp") == "123456", "debug_otp must be 123456 for demo account"

    # 3. Verify OTP for Demo Account (10-digit format)
    verify_url = f"{API_BASE}/auth/otp/verify"
    print(f"\n[3/6] Testing OTP Verify for demo phone '{demo_phone_raw}' with code '123456': {verify_url}")
    req = urllib.request.Request(
        verify_url,
        data=json.dumps({"phone": demo_phone_raw, "otp": "123456"}).encode(),
        headers={"Content-Type": "application/json"}
    )
    access_token = None
    with urllib.request.urlopen(req, timeout=15) as resp:
        assert resp.status == 200
        verify_data = json.loads(resp.read().decode())
        access_token = verify_data.get("access_token")
        refresh_token = verify_data.get("refresh_token")
        assert access_token, "access_token must be returned"
        assert refresh_token, "refresh_token must be returned"
        print(f"      Verification Success! Status: {resp.status}")
        print(f"      Access Token: {mask_token(access_token)}")
        print(f"      Refresh Token: {mask_token(refresh_token)}")
        print(f"      Is New User: {verify_data.get('is_new_user')}")

    # 4. Verify Authenticated Profile via Bearer Token
    profile_url = f"{API_BASE}/me"
    print(f"\n[4/6] Testing Authenticated Profile Fetch: {profile_url}")
    req = urllib.request.Request(
        profile_url,
        headers={
            "Authorization": f"Bearer {access_token}",
            "Accept": "application/json"
        }
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        assert resp.status == 200
        profile_data = json.loads(resp.read().decode())
        print(f"      Profile Artisan Name: {profile_data.get('name')}")
        print(f"      Profile Phone (E.164): {profile_data.get('phone')} (Expected +919876543210)")
        print(f"      Craft: {profile_data.get('craft_type')} | Cluster: {profile_data.get('cluster_location')}")
        assert profile_data.get("phone") == "+919876543210", "Phone must be normalized E.164 +919876543210"

    # 5. Verify All 5 Documented Demo Accounts & E.164 Variants
    print("\n[5/6] Verifying All 5 Documented Demo Accounts with Demo Code 123456:")
    demo_accounts = [
        ("9876543210", "+919876543210"),
        ("9876543211", "+919876543211"),
        ("9876543212", "+919876543212"),
        ("9876543220", "+919876543220"),
        ("9876543221", "+919876543221"),
    ]
    for raw_10, e164 in demo_accounts:
        for p in [raw_10, e164]:
            req = urllib.request.Request(
                verify_url,
                data=json.dumps({"phone": p, "otp": "123456"}).encode(),
                headers={"Content-Type": "application/json"}
            )
            with urllib.request.urlopen(req, timeout=15) as resp:
                assert resp.status == 200
                d = json.loads(resp.read().decode())
                print(f"      Phone: {p:15} -> HTTP {resp.status} OK (tokens returned)")

    # 6. Verify Security Guards (Non-Demo and Invalid Codes)
    print("\n[6/6] Verifying Security Guards (Tamper & Fraud Prevention):")
    # 6a. Wrong OTP for demo account must be rejected
    req = urllib.request.Request(
        verify_url,
        data=json.dumps({"phone": "9876543210", "otp": "000000"}).encode(),
        headers={"Content-Type": "application/json"}
    )
    try:
        urllib.request.urlopen(req, timeout=15)
        assert False, "Wrong OTP should have been rejected"
    except urllib.error.HTTPError as e:
        assert e.code == 400
        err_data = json.loads(e.read().decode())
        print(f"      Wrong code on demo account -> HTTP {e.code} correctly rejected: '{err_data.get('detail')}'")

    # 6b. Universal code 123456 on non-demo phone must be rejected
    req = urllib.request.Request(
        verify_url,
        data=json.dumps({"phone": "9123456789", "otp": "123456"}).encode(),
        headers={"Content-Type": "application/json"}
    )
    try:
        urllib.request.urlopen(req, timeout=15)
        assert False, "Non-demo phone with 123456 should have been rejected"
    except urllib.error.HTTPError as e:
        assert e.code == 400
        err_data = json.loads(e.read().decode())
        print(f"      Code 123456 on non-demo phone -> HTTP {e.code} correctly rejected: '{err_data.get('detail')}'")

    print("\n=============================================================")
    print("      ALL LIVE INTEGRATION TESTS PASSED SUCCESSFULLY!        ")
    print("=============================================================")

if __name__ == "__main__":
    test_live_auth_flow()
