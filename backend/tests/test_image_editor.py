import os
import io
import pytest
from PIL import Image, ImageDraw
from httpx import AsyncClient, ASGITransport

from app.main import app
from app.config import get_settings

def create_sample_craft_image(
    craft_type: str = "pottery",
    canvas_size: tuple = (400, 400),
    bg_color: tuple = (215, 210, 205)
) -> bytes:
    """Creates synthetic sample craft images for testing:
    - pottery: terracotta clay pot
    - wood: carved wooden elephant figure
    - brass: peacock brass diya lamp
    """
    img = Image.new("RGB", canvas_size, color=bg_color)
    draw = ImageDraw.Draw(img)

    if craft_type == "pottery":
        # Terracotta Pot
        pot_color = (195, 80, 45)
        rim_color = (160, 60, 30)
        draw.polygon([(140, 280), (260, 280), (280, 200), (230, 130), (170, 130), (120, 200)], fill=pot_color)
        draw.rectangle([170, 100, 230, 130], fill=pot_color)
        draw.ellipse([160, 95, 240, 110], fill=rim_color)
        draw.ellipse([180, 180, 220, 230], fill=(210, 95, 60))
    elif craft_type == "wood":
        # Carved Wood Elephant
        wood_color = (115, 75, 45)
        detail_color = (85, 50, 30)
        draw.ellipse([120, 150, 280, 260], fill=wood_color) # Body
        draw.ellipse([80, 130, 160, 210], fill=wood_color)  # Head
        draw.polygon([(90, 180), (60, 270), (80, 270), (105, 195)], fill=wood_color) # Trunk
        draw.rectangle([135, 240, 175, 300], fill=detail_color) # Legs
        draw.rectangle([225, 240, 265, 300], fill=detail_color)
    else:
        # Peacock Brass Diya
        brass_color = (212, 175, 55)
        flame_color = (255, 120, 0)
        draw.ellipse([130, 230, 270, 290], fill=brass_color) # Diya base
        draw.rectangle([190, 140, 210, 230], fill=brass_color) # Stem
        draw.polygon([(170, 140), (230, 140), (200, 90)], fill=brass_color) # Peacock crest
        draw.ellipse([192, 60, 208, 90], fill=flame_color) # Flame

    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=90)
    return buf.getvalue()


@pytest.fixture(autouse=True)
def setup_test_mode(monkeypatch):
    """Ensure AI_MODE is mock for deterministic unit testing."""
    settings = get_settings()
    monkeypatch.setattr(settings, "AI_MODE", "mock")
    monkeypatch.setattr(settings, "GEMINI_IMAGE_MODEL", "")


@pytest.mark.asyncio
async def test_three_photos_enhancement_and_editing():
    """Test 1: Tests 3 distinct craft photos (pottery, wood, brass), verifies enhancement
    and executes non-destructive editing operations.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        photos = [
            ("pottery", "test_pottery.jpg"),
            ("wood", "test_wood_elephant.jpg"),
            ("brass", "test_brass_diya.jpg"),
        ]

        for craft_type, filename in photos:
            img_bytes = create_sample_craft_image(craft_type=craft_type)
            files = {"image": (filename, img_bytes, "image/jpeg")}
            data = {"style": "white"}

            # 1. Enhance base image
            resp = await client.post("/images/enhance", files=files, data=data)
            assert resp.status_code == 200, f"Enhance failed for {craft_type}: {resp.text}"
            res_json = resp.json()
            assert "enhanced_url" in res_json
            orig_url = res_json["original_url"]
            image_id = os.path.basename(orig_url).replace("_original.jpg", "").replace("_original.png", "")

            # 2. Test edit operations on each photo
            edit_ops = [
                {"type": "brightness", "value": 1.25},
                {"type": "replace_background", "value": "linen"},
                {"type": "shadow", "value": True},
            ]
            edit_resp = await client.post("/images/edit", json={
                "image_id": image_id,
                "operations": edit_ops,
                "action": "apply",
            })
            assert edit_resp.status_code == 200, f"Edit failed for {craft_type}: {edit_resp.text}"
            edit_data = edit_resp.json()
            assert edit_data["status"] == "success"
            assert edit_data["can_undo"] is True
            assert len(edit_data["operations"]) == 3
            assert edit_data["image_url"].endswith(".webp")


@pytest.mark.asyncio
async def test_non_destructive_history_undo_redo_reset():
    """Test 2: Verifies non-destructive history:
    apply -> undo -> redo -> reset with original cutout preserved.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        img_bytes = create_sample_craft_image(craft_type="pottery")
        files = {"image": ("test_history_pot.jpg", img_bytes, "image/jpeg")}
        resp = await client.post("/images/enhance", files=files, data={"style": "white"})
        assert resp.status_code == 200
        image_id = os.path.basename(resp.json()["original_url"]).replace("_original.jpg", "")

        # 1. Apply two operations: rotate & blue background
        ops = [
            {"type": "rotate", "value": 90},
            {"type": "replace_background", "value": "blue"},
        ]
        r1 = await client.post("/images/edit", json={"image_id": image_id, "operations": ops, "action": "apply"})
        assert r1.status_code == 200
        assert r1.json()["can_undo"] is True
        assert len(r1.json()["operations"]) == 2

        # 2. Undo: pops last operation ("replace_background")
        r_undo = await client.post("/images/edit", json={"image_id": image_id, "action": "undo"})
        assert r_undo.status_code == 200
        data_undo = r_undo.json()
        assert len(data_undo["operations"]) == 1
        assert data_undo["operations"][0]["type"] == "rotate"
        assert data_undo["can_redo"] is True

        # 3. Redo: restores "replace_background"
        r_redo = await client.post("/images/edit", json={"image_id": image_id, "action": "redo"})
        assert r_redo.status_code == 200
        data_redo = r_redo.json()
        assert len(data_redo["operations"]) == 2
        assert data_redo["operations"][1]["type"] == "replace_background"

        # 4. Reset: clears all operations
        r_reset = await client.post("/images/edit", json={"image_id": image_id, "action": "reset"})
        assert r_reset.status_code == 200
        data_reset = r_reset.json()
        assert len(data_reset["operations"]) == 0
        assert data_reset["can_undo"] is False


@pytest.mark.asyncio
async def test_all_supported_operations():
    """Test 3: Verifies all supported operations:
    remove_background, keep_background, replace_background (white, linen, blue, gradient, blur, textured),
    brightness, contrast, warmth, saturation, sharpness, shadow, zoom, rotate, flip, add_border,
    product_size, auto_enhance.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        img_bytes = create_sample_craft_image(craft_type="brass")
        files = {"image": ("test_all_ops.jpg", img_bytes, "image/jpeg")}
        resp = await client.post("/images/enhance", files=files, data={"style": "white"})
        image_id = os.path.basename(resp.json()["original_url"]).replace("_original.jpg", "")

        bg_styles = ["white", "linen", "blue", "soft gradient", "blur", "textured"]
        for bg in bg_styles:
            r = await client.post("/images/edit", json={
                "image_id": image_id,
                "operations": [{"type": "replace_background", "value": bg}],
                "action": "apply"
            })
            assert r.status_code == 200, f"Failed for bg style {bg}"

        # Test composite adjustments: brightness, contrast, warmth, saturation, sharpness, shadow, zoom, rotate, flip, border, product_size, auto_enhance
        comprehensive_ops = [
            {"type": "auto_enhance", "value": True},
            {"type": "brightness", "value": 1.2},
            {"type": "contrast", "value": 1.15},
            {"type": "warmth", "value": 0.25},
            {"type": "saturation", "value": 1.2},
            {"type": "sharpness", "value": 1.3},
            {"type": "shadow", "value": False},
            {"type": "zoom", "value": 1.2},
            {"type": "rotate", "value": 90},
            {"type": "flip", "value": "horizontal"},
            {"type": "add_border", "width": 8, "color": "terracotta"},
            {"type": "product_size", "value": 0.85},
            {"type": "keep_background", "value": True},
            {"type": "remove_background", "value": True},
        ]
        r_all = await client.post("/images/edit", json={
            "image_id": image_id,
            "operations": comprehensive_ops,
            "action": "apply",
        })
        assert r_all.status_code == 200
        assert r_all.json()["status"] == "success"
        assert len(r_all.json()["operations"]) == len(comprehensive_ops)


@pytest.mark.asyncio
async def test_five_voice_commands_in_three_languages():
    """Test 4: Verifies the 5 specified voice commands in 3 languages:
    1. Hindi: "background neela karo"
    2. Tamil: "konjam brightaa"
    3. Telugu: "shadow theeseyyi"
    4. Telugu: "pot ni peddadi cheyyi"
    5. Hindi/English: "reset karo" / "linen background"
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        img_bytes = create_sample_craft_image(craft_type="pottery")
        files = {"image": ("test_voice_pot.jpg", img_bytes, "image/jpeg")}
        resp = await client.post("/images/enhance", files=files, data={"style": "white"})
        image_id = os.path.basename(resp.json()["original_url"]).replace("_original.jpg", "")

        # Command 1 (Hindi): "background neela karo"
        r1 = await client.post("/images/voice-command", json={
            "image_id": image_id,
            "text": "background neela karo",
            "lang": "hi",
        })
        assert r1.status_code == 200
        d1 = r1.json()
        assert d1["status"] == "success"
        assert any(op["type"] == "replace_background" and op["value"] == "blue" for op in d1["new_operations"])
        assert "नीला" in d1["confirmation"] or "blue" in d1["confirmation"].lower()

        # Command 2 (Tamil): "konjam brightaa"
        r2 = await client.post("/images/voice-command", json={
            "image_id": image_id,
            "text": "konjam brightaa",
            "lang": "ta",
        })
        assert r2.status_code == 200
        d2 = r2.json()
        assert d2["status"] == "success"
        assert any(op["type"] == "brightness" for op in d2["new_operations"])
        assert "வெளிச்சம்" in d2["confirmation"] or "bright" in d2["confirmation"].lower()

        # Command 3 (Telugu): "shadow theeseyyi"
        r3 = await client.post("/images/voice-command", json={
            "image_id": image_id,
            "text": "shadow theeseyyi",
            "lang": "te",
        })
        assert r3.status_code == 200
        d3 = r3.json()
        assert d3["status"] == "success"
        assert any(op["type"] == "shadow" and op["value"] is False for op in d3["new_operations"])
        assert "నీడ" in d3["confirmation"] or "shadow" in d3["confirmation"].lower()

        # Command 4 (Telugu): "pot ni peddadi cheyyi"
        r4 = await client.post("/images/voice-command", json={
            "image_id": image_id,
            "text": "pot ni peddadi cheyyi",
            "lang": "te",
        })
        assert r4.status_code == 200
        d4 = r4.json()
        assert d4["status"] == "success"
        assert any(op["type"] == "product_size" for op in d4["new_operations"])
        assert "పరిమాణం" in d4["confirmation"] or "size" in d4["confirmation"].lower()

        # Command 5 (Hindi/English): "linen background"
        r5 = await client.post("/images/voice-command", json={
            "image_id": image_id,
            "text": "linen background",
            "lang": "hi",
        })
        assert r5.status_code == 200
        d5 = r5.json()
        assert d5["status"] == "success"
        assert any(op["type"] == "replace_background" and op["value"] == "linen" for op in d5["new_operations"])
        assert "लिनन" in d5["confirmation"] or "linen" in d5["confirmation"].lower()


@pytest.mark.asyncio
async def test_unclear_command_returns_clarification():
    """Test 5: Unclear request returns clarifying question in user's language."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        img_bytes = create_sample_craft_image(craft_type="pottery")
        files = {"image": ("test_unclear.jpg", img_bytes, "image/jpeg")}
        resp = await client.post("/images/enhance", files=files, data={"style": "white"})
        image_id = os.path.basename(resp.json()["original_url"]).replace("_original.jpg", "")

        # Ambiguous command in Hindi
        r_hi = await client.post("/images/voice-command", json={
            "image_id": image_id,
            "text": "kuch alag karo",
            "lang": "hi",
        })
        assert r_hi.status_code == 200
        d_hi = r_hi.json()
        assert d_hi["clarification_needed"] is True
        assert "?" in d_hi["clarifying_question"]
        assert "बदलना" in d_hi["clarifying_question"]

        # Ambiguous command in Tamil
        r_ta = await client.post("/images/voice-command", json={
            "image_id": image_id,
            "text": "edhavadhu maathu",
            "lang": "ta",
        })
        assert r_ta.status_code == 200
        d_ta = r_ta.json()
        assert d_ta["clarification_needed"] is True
        assert "?" in d_ta["clarifying_question"]


@pytest.mark.asyncio
async def test_free_form_generative_ai_edit_unavailable_polite_reply():
    """Test 6: Free-form edit when GEMINI_IMAGE_MODEL is not set replies politely."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        img_bytes = create_sample_craft_image(craft_type="pottery")
        files = {"image": ("test_freeform.jpg", img_bytes, "image/jpeg")}
        resp = await client.post("/images/enhance", files=files, data={"style": "white"})
        image_id = os.path.basename(resp.json()["original_url"]).replace("_original.jpg", "")

        # Request to generate flowers in the pot
        r = await client.post("/images/voice-command", json={
            "image_id": image_id,
            "text": "draw flowers inside the pot",
            "lang": "hi",
        })
        assert r.status_code == 200
        d = r.json()
        assert d["status"] == "unavailable"
        assert d["ai_edit_available"] is False
        assert "क्षमा करें" in d["confirmation"] or "not available" in d["confirmation"].lower()
