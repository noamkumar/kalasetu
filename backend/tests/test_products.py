import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app

@pytest.mark.asyncio
async def test_products_multilingual_and_crud():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        # 1. List products in English
        resp_en = await ac.get("/api/v1/products?lang=en")
        assert resp_en.status_code == 200
        products_en = resp_en.json()
        assert len(products_en) >= 12
        first_p = products_en[0]
        assert "title" in first_p
        assert "price" in first_p

        # 2. List products in Hindi
        resp_hi = await ac.get("/api/v1/products?lang=hi")
        assert resp_hi.status_code == 200
        products_hi = resp_hi.json()
        assert len(products_hi) >= 12
        # Verify localized text exists
        titles = [p["title"] for p in products_hi]
        assert any("जयपुर" in t or "पोचमपल्ली" in t or "चन्नापटना" in t for t in titles)

        # 3. List products in Tamil
        resp_ta = await ac.get("/api/v1/products?lang=ta")
        assert resp_ta.status_code == 200
        products_ta = resp_ta.json()
        titles_ta = [p["title"] for p in products_ta]
        assert any("ஜெய்ப்பூர்" in t or "போச்சம்பள்ளி" in t or "சன்னபட்னா" in t for t in titles_ta)

        # 4. Filter by category
        resp_cat = await ac.get("/api/v1/products?category=Pottery")
        assert resp_cat.status_code == 200
        pottery_prods = resp_cat.json()
        for p in pottery_prods:
            assert "pottery" in p["category"].lower()

        # 5. Search
        resp_search = await ac.get("/api/v1/products?search=Ikat")
        assert resp_search.status_code == 200
        search_results = resp_search.json()
        assert len(search_results) >= 1
