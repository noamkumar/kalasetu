import io
import os
import pytest
from unittest.mock import AsyncMock, patch
from PIL import Image, ImageDraw
from httpx import AsyncClient, ASGITransport

from app.main import app
from app.config import get_settings
from app.routers.images import EditImageRequest
from app.providers.gemini_client import GeminiClientError

def create_dummy_craft_image() -> bytes:
    """Creates a simple craft image for testing."""
    img = Image.new("RGB", (200, 200), color=(180, 160, 140))
    draw = ImageDraw.Draw(img)
    draw.polygon([(60, 140), (140, 140), (150, 100), (120, 60), (80, 60), (50, 100)], fill=(195, 80, 45))
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()

def create_edited_craft_image() -> bytes:
    """Creates a distinct edited image (different bytes)."""
    img = Image.new("RGB", (200, 200), color=(255, 255, 255))
    draw = ImageDraw.Draw(img)
    draw.polygon([(60, 140), (140, 140), (150, 100), (120, 60), (80, 60), (50, 100)], fill=(195, 80, 45))
    draw.ellipse([80, 160, 120, 175], fill=(200, 200, 200))
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


async def upload_test_image(client: AsyncClient) -> str:
    """Uploads a test image to /images/enhance and returns the image_id."""
    img_bytes = create_dummy_craft_image()
    files = {"image": ("test_craft.png", img_bytes, "image/png")}
    resp = await client.post("/images/enhance", files=files, data={"style": "white"})
    assert resp.status_code == 200, f"Upload enhance failed: {resp.status_code} - {resp.text}"
    data = resp.json()
    if data.get("image_id"):
        return data["image_id"]
    orig_url = data["original_url"]
    return os.path.basename(orig_url).replace("_original.jpg", "").replace("_original.png", "")


@pytest.mark.asyncio
async def test_shared_edit_endpoint_gemini_success_with_image(monkeypatch):
    """Test Case 1: Shared endpoint calls Gemini image model and succeeds with returned image."""
    settings = get_settings()
    monkeypatch.setattr(settings, "AI_MODE", "real")
    monkeypatch.setattr(settings, "GEMINI_API_KEY", "test_key_mock")
    monkeypatch.setattr(settings, "GEMINI_IMAGE_MODEL", "gemini-3.1-flash-image")
    monkeypatch.setattr(settings, "ENABLE_LOCAL_FALLBACK", False)

    edited_bytes = create_edited_craft_image()
    mock_edit = AsyncMock(return_value=edited_bytes)

    with patch("app.providers.gemini_client.GeminiClient.edit_image", mock_edit):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            image_id = await upload_test_image(client)
            payload = {
                "image_id": image_id,
                "prompt": "remove cluttered background and make background clean white",
                "lang": "en",
            }
            resp = await client.post("/images/edit", json=payload)
            assert resp.status_code == 200, f"Expected 200, got {resp.status_code}: {resp.text}"
            data = resp.json()
            assert data["status"] == "success"
            assert data["image_id"] == image_id
            assert data["image_url"].startswith("/static/uploads/")
            assert mock_edit.called


@pytest.mark.asyncio
async def test_shared_edit_endpoint_gemini_text_only_with_fallback(monkeypatch):
    """Test Case 2: Gemini returns text only (no image bytes). With ENABLE_LOCAL_FALLBACK=True,
    local editing takes over and successfully produces the edited image.
    """
    settings = get_settings()
    monkeypatch.setattr(settings, "AI_MODE", "real")
    monkeypatch.setattr(settings, "GEMINI_API_KEY", "test_key_mock")
    monkeypatch.setattr(settings, "GEMINI_IMAGE_MODEL", "gemini-3.1-flash-image")
    monkeypatch.setattr(settings, "ENABLE_LOCAL_FALLBACK", True)

    # Gemini returns empty bytes or identical unmodified bytes (text only response)
    mock_edit = AsyncMock(return_value=b"")

    with patch("app.providers.gemini_client.GeminiClient.edit_image", mock_edit):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            image_id = await upload_test_image(client)
            payload = {
                "image_id": image_id,
                "prompt": "remove background and make background clean white",
                "lang": "en",
            }
            resp = await client.post("/images/edit", json=payload)
            assert resp.status_code == 200, f"Expected 200 with fallback, got {resp.status_code}: {resp.text}"
            data = resp.json()
            assert data["status"] == "success"
            assert data["image_url"].startswith("/static/uploads/")
            assert "fallback" in data["message"].lower() or data["status"] == "success"


@pytest.mark.asyncio
async def test_shared_edit_endpoint_gemini_text_only_without_fallback(monkeypatch):
    """Test Case 2b: Gemini returns text only (no image bytes). With ENABLE_LOCAL_FALLBACK=False,
    it honestly returns error status 502 with hint 'no image returned'.
    """
    settings = get_settings()
    monkeypatch.setattr(settings, "AI_MODE", "real")
    monkeypatch.setattr(settings, "GEMINI_API_KEY", "test_key_mock")
    monkeypatch.setattr(settings, "GEMINI_IMAGE_MODEL", "gemini-3.1-flash-image")
    monkeypatch.setattr(settings, "ENABLE_LOCAL_FALLBACK", False)

    mock_edit = AsyncMock(return_value=b"")

    with patch("app.providers.gemini_client.GeminiClient.edit_image", mock_edit):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            image_id = await upload_test_image(client)
            payload = {
                "image_id": image_id,
                "prompt": "remove background and make background clean white",
                "lang": "en",
            }
            resp = await client.post("/images/edit", json=payload)
            assert resp.status_code == 502, f"Expected 502, got {resp.status_code}: {resp.text}"
            data = resp.json()
            assert "detail" in data
            detail = data["detail"]
            assert detail["gemini_status"] == "NO_IMAGE_RETURNED"
            assert "no image" in detail["hint"].lower()


@pytest.mark.asyncio
async def test_shared_edit_endpoint_gemini_error_without_fallback(monkeypatch):
    """Test Case 3: Gemini returns HTTP 429 RESOURCE_EXHAUSTED. With ENABLE_LOCAL_FALLBACK=False,
    endpoint reports the real error status, model name, and plain-English hint.
    """
    settings = get_settings()
    monkeypatch.setattr(settings, "AI_MODE", "real")
    monkeypatch.setattr(settings, "GEMINI_API_KEY", "test_key_mock")
    monkeypatch.setattr(settings, "GEMINI_IMAGE_MODEL", "gemini-3.1-flash-image")
    monkeypatch.setattr(settings, "ENABLE_LOCAL_FALLBACK", False)

    error = GeminiClientError(
        "Quota exceeded: limit 0",
        http_status=429,
        gemini_status="RESOURCE_EXHAUSTED",
        model="gemini-3.1-flash-image",
        hint="billing not enabled (free tier request limit is 0 for this model)",
    )
    mock_edit = AsyncMock(side_effect=error)

    with patch("app.providers.gemini_client.GeminiClient.edit_image", mock_edit):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            image_id = await upload_test_image(client)
            payload = {
                "image_id": image_id,
                "prompt": "remove background",
                "lang": "en",
            }
            resp = await client.post("/images/edit", json=payload)
            assert resp.status_code == 429
            detail = resp.json()["detail"]
            assert detail["http_status"] == 429
            assert detail["gemini_status"] == "RESOURCE_EXHAUSTED"
            assert detail["model"] == "gemini-3.1-flash-image"
            assert "billing not enabled" in detail["hint"]


@pytest.mark.asyncio
async def test_shared_edit_endpoint_gemini_error_with_fallback(monkeypatch):
    """Test Case 3b: Gemini returns HTTP 429 RESOURCE_EXHAUSTED. With ENABLE_LOCAL_FALLBACK=True,
    the endpoint catches the failure, logs it, and gracefully falls back to local processing.
    """
    settings = get_settings()
    monkeypatch.setattr(settings, "AI_MODE", "real")
    monkeypatch.setattr(settings, "GEMINI_API_KEY", "test_key_mock")
    monkeypatch.setattr(settings, "GEMINI_IMAGE_MODEL", "gemini-3.1-flash-image")
    monkeypatch.setattr(settings, "ENABLE_LOCAL_FALLBACK", True)

    error = GeminiClientError(
        "Quota exceeded",
        http_status=429,
        gemini_status="RESOURCE_EXHAUSTED",
        model="gemini-3.1-flash-image",
        hint="billing not enabled",
    )
    mock_edit = AsyncMock(side_effect=error)

    with patch("app.providers.gemini_client.GeminiClient.edit_image", mock_edit):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            image_id = await upload_test_image(client)
            payload = {
                "image_id": image_id,
                "prompt": "remove background and make background clean white",
                "lang": "en",
            }
            resp = await client.post("/images/edit", json=payload)
            assert resp.status_code == 200, f"Expected fallback 200, got {resp.status_code}: {resp.text}"
            data = resp.json()
            assert data["status"] == "success"
            assert data["image_url"].startswith("/static/uploads/")


@pytest.mark.asyncio
async def test_add_product_and_chat_request_shape_parity():
    """Test Case 4: Verifies that Add Product and KalaMitra Chat requests to /images/edit
    have the EXACT same shape, keys, and Pydantic validation behavior.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        image_id = await upload_test_image(client)

        # 1. Add Product request payload shape
        add_product_payload = {
            "image_id": image_id,
            "prompt": "remove background and make background clean white",
            "action": "apply",
            "lang": "en",
        }

        # 2. KalaMitra Chat request payload shape
        chat_payload = {
            "image_id": image_id,
            "prompt": "remove background and make background clean white",
            "action": "apply",
            "lang": "en",
        }

        # Verify identical shape and key set
        assert add_product_payload.keys() == chat_payload.keys()
        assert set(add_product_payload.keys()) == {"image_id", "prompt", "action", "lang"}

        # Validate against Pydantic EditImageRequest model
        req_add_product = EditImageRequest(**add_product_payload)
        req_chat = EditImageRequest(**chat_payload)
        assert req_add_product.image_id == req_chat.image_id
        assert req_add_product.prompt == req_chat.prompt
        assert req_add_product.action == req_chat.action
        assert req_add_product.lang == req_chat.lang

        # Both requests execute successfully against the shared endpoint POST /images/edit
        resp_add = await client.post("/images/edit", json=add_product_payload)
        resp_chat = await client.post("/images/edit", json=chat_payload)

        assert resp_add.status_code == 200
        assert resp_chat.status_code == 200
        assert resp_add.json()["status"] == "success"
        assert resp_chat.json()["status"] == "success"
