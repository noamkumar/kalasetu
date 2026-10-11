import io
import pytest
from PIL import Image, ImageDraw
from httpx import AsyncClient, ASGITransport
from app.main import app

def generate_test_craft_image(bg_color=(200, 200, 200), craft_color=(175, 75, 45)) -> bytes:
    """Generate a test craft image (pottery vase shape on solid background)."""
    img = Image.new("RGB", (400, 400), color=bg_color)
    draw = ImageDraw.Draw(img)
    # Draw clay pot / vase
    draw.polygon(
        [(140, 280), (260, 280), (280, 200), (220, 130), (180, 130), (120, 200)],
        fill=craft_color,
        outline=(120, 50, 30),
    )
    # Neck and rim
    draw.rectangle([180, 100, 220, 130], fill=craft_color, outline=(120, 50, 30))
    draw.ellipse([175, 95, 225, 105], fill=(190, 85, 55), outline=(120, 50, 30))

    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=90)
    return buf.getvalue()

@pytest.mark.asyncio
async def test_enhance_image_endpoint_white_style():
    img_bytes = generate_test_craft_image()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        files = {
            "image": ("test_pot.jpg", img_bytes, "image/jpeg")
        }
        data = {
            "style": "white"
        }
        response = await client.post("/images/enhance", files=files, data=data)
        assert response.status_code == 200
        result = response.json()
        assert "status" in result
        assert result["status"] in ["done", "partial_fallback"]
        assert "quality_score" in result
        assert 0.0 <= result["quality_score"] <= 100.0
        assert "variants" in result
        assert "square" in result["variants"]
        assert "portrait" in result["variants"]
        assert "thumb" in result["variants"]
        assert "tips" in result
        assert len(result["tips"]) > 0

@pytest.mark.asyncio
async def test_enhance_image_endpoint_linen_style():
    img_bytes = generate_test_craft_image()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        files = {
            "file": ("test_pot_linen.jpg", img_bytes, "image/jpeg")
        }
        data = {
            "style": "linen"
        }
        response = await client.post("/images/enhance", files=files, data=data)
        assert response.status_code == 200
        result = response.json()
        assert "variants" in result
        assert result["variants"]["square"].endswith(".webp")
