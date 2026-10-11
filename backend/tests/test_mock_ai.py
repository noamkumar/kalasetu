import io
import pytest
from httpx import AsyncClient, ASGITransport
from PIL import Image

from app.main import app
from app.config import get_settings


@pytest.fixture(autouse=True)
def setup_mock_ai_mode(monkeypatch):
    """Ensure AI_MODE is 'mock' for this test suite."""
    settings = get_settings()
    monkeypatch.setattr(settings, "AI_MODE", "mock")
    monkeypatch.setattr(settings, "GEMINI_API_KEY", "")


@pytest.mark.asyncio
async def test_health_reports_mock_mode():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["ai_mode"] == "mock"
        assert data["key_configured"] is False


@pytest.mark.asyncio
async def test_catalog_transcribe_mock():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        fake_wav = io.BytesIO(b"RIFF\x24\x00\x00\x00WAVEfmt \x10\x00\x00\x00\x01\x00\x01\x00D\xac\x00\x00\x88X\x01\x00\x02\x00\x10\x00data\x00\x00\x00\x00")
        files = {"audio": ("sample.wav", fake_wav, "audio/wav")}
        data = {"language_hint": "hi"}

        response = await client.post("/api/v1/catalog/transcribe", files=files, data=data)
        assert response.status_code == 200
        result = response.json()
        assert "text" in result
        assert result["detected_lang"] == "hi"
        assert result["clarity"] in ["high", "medium", "low"]
        assert len(result["text"]) > 5


@pytest.mark.asyncio
async def test_catalog_generate_mock():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        payload = {
            "transcript": "Handmade clay water pot naturally cools water",
            "source_lang": "en",
            "category": "pottery",
            "price": 350.0,
        }
        response = await client.post("/api/v1/catalog/generate", json=payload)
        assert response.status_code == 200
        result = response.json()
        assert "master" in result
        assert "translations" in result
        for lang in ["en", "hi", "ta", "te", "kn", "ml"]:
            assert lang in result["translations"]
            assert "title" in result["translations"][lang]
            assert "short_description" in result["translations"][lang]


@pytest.mark.asyncio
async def test_images_enhance_mock():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Create a small in-memory test image
        img = Image.new("RGB", (100, 100), color=(180, 120, 80))
        img_bytes = io.BytesIO()
        img.save(img_bytes, format="JPEG")
        img_bytes.seek(0)

        files = {"image": ("test_craft.jpg", img_bytes, "image/jpeg")}
        data = {"style": "linen"}

        response = await client.post("/api/v1/images/enhance", files=files, data=data)
        assert response.status_code == 200
        result = response.json()
        assert result["status"] == "done"
        assert result["quality_score"] > 50
        assert "original_url" in result
        assert "enhanced_url" in result
        assert "variants" in result
        assert "square" in result["variants"]
        assert "thumb" in result["variants"]


@pytest.mark.asyncio
async def test_pricing_suggest_mock():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        payload = {
            "category": "pottery",
            "materials": ["Terracotta clay"],
            "material_cost": 150.0,
            "labour_hours": 3.0,
            "lang": "ta",
        }
        response = await client.post("/api/v1/pricing/suggest", json=payload)
        assert response.status_code == 200
        result = response.json()
        assert "floor" in result
        assert "recommended" in result
        assert "budget" in result
        assert "premium" in result
        assert result["recommended"] >= result["floor"]
        assert "factors" in result
        assert "explanation" in result


@pytest.mark.asyncio
async def test_assistant_chat_mock():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Add product intent
        resp1 = await client.post(
            "/api/v1/assistant/chat",
            json={"message": "I want to add a new terracotta vase", "current_screen": "home", "language": "hi"}
        )
        assert resp1.status_code == 200
        res1 = resp1.json()
        assert res1["action"] == "navigate"
        assert res1["route"] == "/studio"

        # 2. Show orders intent
        resp2 = await client.post(
            "/api/v1/assistant/chat",
            json={"message": "Show pending orders please", "current_screen": "home", "language": "en"}
        )
        assert resp2.status_code == 200
        res2 = resp2.json()
        assert res2["action"] == "navigate"
        assert "/orders" in res2["route"]

        # 3. Change language intent
        resp3 = await client.post(
            "/api/v1/assistant/chat",
            json={"message": "Switch language to Tamil", "current_screen": "profile", "language": "en"}
        )
        assert resp3.status_code == 200
        res3 = resp3.json()
        assert res3["action"] == "change_language"
        assert res3["target_lang"] == "ta"

        # 4. Explain screen intent
        resp4 = await client.post(
            "/api/v1/assistant/chat",
            json={"message": "Explain this screen to me", "current_screen": "pricing", "language": "en"}
        )
        assert resp4.status_code == 200
        res4 = resp4.json()
        assert res4["action"] == "explain"
        assert "Fair Pricing Assistant" in res4["reply"]
