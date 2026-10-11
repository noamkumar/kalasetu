import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app
from app.db.session import SessionLocal
from app.models.db_models import Artisan, Product, ProductTranslation, Order
from app.services.auth_service import create_access_token

@pytest.fixture
def db_session():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@pytest.fixture
def artisan_user(db_session):
    artisan = db_session.query(Artisan).filter(Artisan.phone == "9876500001").first()
    if not artisan:
        artisan = Artisan(
            phone="9876500001",
            name="Ramesh Potter",
            role="artisan",
            craft_type="Pottery",
            cluster_location="Khurja, UP",
            state="Uttar Pradesh",
        )
        db_session.add(artisan)
        db_session.commit()
        db_session.refresh(artisan)
    return artisan

@pytest.fixture
def buyer_user(db_session):
    buyer = db_session.query(Artisan).filter(Artisan.phone == "9876500002").first()
    if not buyer:
        buyer = Artisan(
            phone="9876500002",
            name="Priya Buyer",
            role="buyer",
            cluster_location="Bangalore, KA",
            state="Karnataka",
        )
        db_session.add(buyer)
        db_session.commit()
        db_session.refresh(buyer)
    return buyer

@pytest.fixture
def artisan_token(artisan_user):
    return create_access_token(data={"sub": artisan_user.id, "phone": artisan_user.phone})

@pytest.fixture
def buyer_token(buyer_user):
    return create_access_token(data={"sub": buyer_user.id, "phone": buyer_user.phone})

@pytest.mark.asyncio
async def test_full_marketplace_loop(artisan_token, buyer_token, artisan_user, buyer_user):
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        # 1. Artisan publishes a product with stock = 2
        artisan_headers = {"Authorization": f"Bearer {artisan_token}"}
        create_resp = await ac.post(
            "/api/v1/products",
            headers=artisan_headers,
            json={
                "category": "Pottery",
                "price": 850.0,
                "cost_price": 400.0,
                "status": "live",
                "stock_quantity": 2,
                "primary_image_url": "https://example.com/terracotta_pot.jpg",
                "translations": [
                    {
                        "language_code": "en",
                        "title": "Handcrafted Terracotta Clay Pot",
                        "description": "Authentic organic clay pot for traditional cooking.",
                        "materials": "Riverbed Clay",
                        "care_instructions": "Season with rice water before first use."
                    },
                    {
                        "language_code": "hi",
                        "title": "हस्तनिर्मित टेराकोटा मिट्टी का बर्तन",
                        "description": "पारंपरिक खाना पकाने के लिए शुद्ध मिट्टी का बर्तन।",
                        "materials": "प्राकृतिक मिट्टी",
                        "care_instructions": "उपयोग से पहले पानी में भिगोएं।"
                    }
                ]
            }
        )
        assert create_resp.status_code == 201
        prod_data = create_resp.json()
        product_id = prod_data["id"]
        assert prod_data["status"] == "live"
        assert prod_data["stock_quantity"] == 2
        assert "Terracotta Clay Pot" in prod_data["title"]

        # 2. Buyer browses marketplace products (public endpoint, localized in Hindi)
        market_resp = await ac.get(f"/api/v1/marketplace/products?lang=hi&category=Pottery")
        assert market_resp.status_code == 200
        market_data = market_resp.json()
        assert "items" in market_data
        assert market_data["total"] >= 1
        found_product = next((p for p in market_data["items"] if p["id"] == product_id), None)
        assert found_product is not None
        assert "मिट्टी का बर्तन" in found_product["title"]

        # 3. Buyer places an order for 1 unit (Buy Now flow)
        buyer_headers = {"Authorization": f"Bearer {buyer_token}"}
        order_resp = await ac.post(
            "/api/v1/orders",
            headers=buyer_headers,
            json={
                "product_id": product_id,
                "quantity": 1,
                "unit_price": 850.0,
                "customer_name": "Priya Buyer",
                "customer_phone": "9876500002",
                "customer_address": "Flat 402, Lotus Residency, Indiranagar, Bangalore",
                "payment_method": "cash_on_delivery",
                "buyer_id": buyer_user.id
            }
        )
        assert order_resp.status_code == 201
        order_data = order_resp.json()
        order_id = order_data["id"]
        assert order_data["status"] == "new"
        assert order_data["total_amount"] == 850.0
        assert order_data["payment_method"] == "cash_on_delivery"
        assert len(order_data["items"]) == 1

        # Check product stock decreased from 2 to 1
        prod_check = await ac.get(f"/api/v1/products/{product_id}")
        assert prod_check.status_code == 200
        assert prod_check.json()["stock_quantity"] == 1
        assert prod_check.json()["status"] == "live"

        # Check artisan received notification
        notif_resp = await ac.get(f"/api/v1/notifications?user_id={artisan_user.id}")
        assert notif_resp.status_code == 200
        artisan_notifs = notif_resp.json()
        assert any(n["order_id"] == order_id for n in artisan_notifs)

        # 4. Artisan accepts the order
        accept_resp = await ac.patch(f"/api/v1/orders/{order_id}/accept", headers=artisan_headers)
        assert accept_resp.status_code == 200
        assert accept_resp.json()["status"] == "accepted"

        # 5. Artisan marks the order as packed
        pack_resp = await ac.patch(
            f"/api/v1/orders/{order_id}/status",
            headers=artisan_headers,
            json={"status": "packed"}
        )
        assert pack_resp.status_code == 200
        assert pack_resp.json()["status"] == "packed"

        # 6. Artisan ships the order with tracking details
        ship_resp = await ac.patch(
            f"/api/v1/orders/{order_id}/status",
            headers=artisan_headers,
            json={
                "status": "shipped",
                "tracking_id": "BD-IND-778899",
                "courier_name": "BlueDart Express"
            }
        )
        assert ship_resp.status_code == 200
        shipped_data = ship_resp.json()
        assert shipped_data["status"] == "shipped"
        assert shipped_data["tracking_id"] == "BD-IND-778899"
        assert shipped_data["courier_name"] == "BlueDart Express"

        # 7. Buyer views order tracking screen with timeline and tracking ID
        buyer_order_resp = await ac.get(f"/api/v1/orders/{order_id}", headers=buyer_headers)
        assert buyer_order_resp.status_code == 200
        buyer_view = buyer_order_resp.json()
        assert buyer_view["tracking_id"] == "BD-IND-778899"
        assert buyer_view["courier_name"] == "BlueDart Express"
        assert len(buyer_view["timeline"]) >= 4

        # Verify all steps in timeline: new, accepted, packed, shipped
        timeline_keys = [t["key"] for t in buyer_view["timeline"]]
        assert "new" in timeline_keys
        assert "accepted" in timeline_keys
        assert "packed" in timeline_keys
        assert "shipped" in timeline_keys

        # 8. Artisan marks delivered
        deliv_resp = await ac.patch(
            f"/api/v1/orders/{order_id}/status",
            headers=artisan_headers,
            json={"status": "delivered"}
        )
        assert deliv_resp.status_code == 200
        assert deliv_resp.json()["status"] == "delivered"

        # 9. Verify buyer cannot cancel delivered order
        cancel_delivered = await ac.patch(f"/api/v1/orders/{order_id}/cancel", headers=buyer_headers)
        assert cancel_delivered.status_code == 400

        # 10. Order remaining stock (quantity = 1) -> product should become sold_out
        order2_resp = await ac.post(
            "/api/v1/orders",
            headers=buyer_headers,
            json={
                "product_id": product_id,
                "quantity": 1,
                "customer_name": "Second Buyer",
                "customer_phone": "9876500003",
                "customer_address": "Chennai, TN",
                "payment_method": "pay_later"
            }
        )
        assert order2_resp.status_code == 201

        # Check product status is now sold_out
        prod_check2 = await ac.get(f"/api/v1/products/{product_id}")
        assert prod_check2.json()["stock_quantity"] == 0
        assert prod_check2.json()["status"] == "sold_out"

        # 11. Third attempt to order when stock is 0 -> fails with 400 Insufficient stock
        order3_resp = await ac.post(
            "/api/v1/orders",
            headers=buyer_headers,
            json={
                "product_id": product_id,
                "quantity": 1,
                "customer_name": "Third Buyer",
                "customer_phone": "9876500004",
                "customer_address": "Mumbai, MH",
            }
        )
        assert order3_resp.status_code == 400
        assert "Insufficient stock" in order3_resp.json()["detail"]

        # 12. Buyer cancel before shipping restores inventory
        new_order_id = order2_resp.json()["id"]
        cancel_resp = await ac.patch(f"/api/v1/orders/{new_order_id}/cancel", headers=buyer_headers)
        assert cancel_resp.status_code == 200
        assert cancel_resp.json()["status"] == "cancelled"

        # Stock should be restored to 1 and status back to live
        prod_restored = await ac.get(f"/api/v1/products/{product_id}")
        assert prod_restored.json()["stock_quantity"] == 1
        assert prod_restored.json()["status"] == "live"
