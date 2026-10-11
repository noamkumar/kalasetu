import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app
from app.db.session import SessionLocal
from app.models.db_models import Artisan, Order, Product

@pytest.fixture
def auth_headers():
    db = SessionLocal()
    artisan = db.query(Artisan).first()
    db.close()
    if not artisan:
        # Mock token fallback or headers
        return {}
    from app.services.auth_service import create_access_token
    token = create_access_token(data={"sub": artisan.id, "phone": artisan.phone})
    return {"Authorization": f"Bearer {token}"}

@pytest.mark.asyncio
async def test_orders_status_update_and_timeline(auth_headers):
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        # 1. List orders
        orders_resp = await ac.get("/api/v1/orders", headers=auth_headers)
        assert orders_resp.status_code == 200
        orders = orders_resp.json()
        assert len(orders) > 0

        target_order = orders[0]
        order_id = target_order["id"]
        assert "timeline" in target_order
        assert len(target_order["timeline"]) >= 2

        # 2. Update status to 'packed'
        patch_resp = await ac.patch(
            f"/api/v1/orders/{order_id}/status",
            headers=auth_headers,
            json={"status": "packed"}
        )
        assert patch_resp.status_code == 200
        updated = patch_resp.json()
        assert updated["status"] == "packed"
        # Verify timeline step for packed is current or completed
        packed_step = next((s for s in updated["timeline"] if s["key"] == "packed"), None)
        assert packed_step is not None
        assert packed_step["completed"] is True

        # 3. Update status to 'shipped'
        ship_resp = await ac.patch(
            f"/api/v1/orders/{order_id}/status",
            headers=auth_headers,
            json={"status": "shipped"}
        )
        assert ship_resp.status_code == 200
        assert ship_resp.json()["status"] == "shipped"

@pytest.mark.asyncio
async def test_orders_unread_count(auth_headers):
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        resp = await ac.get("/api/v1/orders/unread-count", headers=auth_headers)
        assert resp.status_code == 200
        data = resp.json()
        assert "unread_count" in data
        assert isinstance(data["unread_count"], int)

@pytest.mark.asyncio
async def test_kalamitra_assistant_intents():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        # Intent 1: Add product
        resp_add = await ac.post("/api/v1/assistant/chat", json={
            "message": "I want to add a new terracotta vase photo",
            "current_screen": "home",
            "language": "en"
        })
        assert resp_add.status_code == 200
        data_add = resp_add.json()
        assert data_add["action"] == "navigate"
        assert "/studio" in data_add["route"]

        # Intent 2: Pending orders
        resp_orders = await ac.post("/api/v1/assistant/chat", json={
            "message": "Show me my pending customer orders",
            "current_screen": "catalogue",
            "language": "en"
        })
        assert resp_orders.status_code == 200
        data_orders = resp_orders.json()
        assert data_orders["action"] == "navigate"
        assert "orders" in data_orders["route"]

        # Intent 3: Change language
        resp_lang = await ac.post("/api/v1/assistant/chat", json={
            "message": "Change language to Hindi",
            "current_screen": "home",
            "language": "en"
        })
        assert resp_lang.status_code == 200
        data_lang = resp_lang.json()
        assert data_lang["action"] == "change_language"
        assert data_lang["target_lang"] == "hi"

        # Intent 4: Explain screen
        resp_explain = await ac.post("/api/v1/assistant/chat", json={
            "message": "Explain this screen to me",
            "current_screen": "pricing",
            "language": "en"
        })
        assert resp_explain.status_code == 200
        data_explain = resp_explain.json()
        assert data_explain["action"] == "explain"
        assert len(data_explain["reply"]) > 10

@pytest.mark.asyncio
async def test_analytics_summary():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        resp = await ac.get("/api/v1/analytics/summary")
        assert resp.status_code == 200
        data = resp.json()
        assert "total_revenue" in data
        assert "total_orders" in data
        assert "pending_orders" in data
        assert "active_products" in data
        assert "popular_crafts" in data
        assert len(data["popular_crafts"]) >= 3
        assert "trend_30_days" in data
        assert len(data["trend_30_days"]) == 30
