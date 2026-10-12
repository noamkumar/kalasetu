import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app

@pytest.mark.asyncio
async def test_auth_otp_flow_and_me():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        # 1. Send OTP
        resp = await ac.post("/api/v1/auth/otp/send", json={"phone": "9998887776"})
        assert resp.status_code == 200
        data = resp.json()
        assert "Demo mode" in data["message"] or "OTP" in data["message"]
        assert data["debug_otp"] == "123456"

        # 2. Verify OTP
        verify_resp = await ac.post("/api/v1/auth/otp/verify", json={
            "phone": "9998887776",
            "otp": "123456"
        })
        assert verify_resp.status_code == 200
        tokens = verify_resp.json()
        assert "access_token" in tokens
        assert "refresh_token" in tokens
        token = tokens["access_token"]

        # 3. GET /me
        me_resp = await ac.get(
            "/api/v1/me",
            headers={"Authorization": f"Bearer {token}"}
        )
        assert me_resp.status_code == 200
        me = me_resp.json()
        assert me["phone"] in ["9998887776", "+919998887776"]

        # 4. PATCH /me
        update_resp = await ac.patch(
            "/api/v1/me",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "name": "Dev Artisan",
                "craft_type": "Pottery",
                "cluster_location": "Khurja",
                "state": "Uttar Pradesh"
            }
        )
        assert update_resp.status_code == 200
        updated = update_resp.json()
        assert updated["name"] == "Dev Artisan"
        assert updated["craft_type"] == "Pottery"
