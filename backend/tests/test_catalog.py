import io
import wave
import struct
import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app

def create_dummy_wav() -> bytes:
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(1)  # Mono
        wf.setsampwidth(2)  # 16-bit
        wf.setframerate(16000)  # 16kHz
        # 0.5s of silence/tone
        silence_frames = struct.pack("<h", 0) * 8000
        wf.writeframes(silence_frames)
    return buf.getvalue()

@pytest.mark.asyncio
async def test_transcribe_audio_endpoint():
    wav_bytes = create_dummy_wav()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        files = {
            "audio": ("voice_note.wav", wav_bytes, "audio/wav")
        }
        data = {
            "language_hint": "te"
        }
        response = await client.post("/catalog/transcribe", files=files, data=data)
        assert response.status_code == 200
        result = response.json()
        assert "text" in result
        assert "detected_lang" in result
        assert "clarity" in result
        assert result["clarity"] in ["high", "medium", "low"]

@pytest.mark.asyncio
async def test_generate_catalog_endpoint():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        payload = {
            "transcript": "చేతితో చేసిన టెర్రకోట మట్టి కుండ, సహజంగా నీటిని చల్లబరుస్తుంది.",
            "source_lang": "te",
            "category": "pottery",
            "price": 350.0,
            "image_tags": {
                "category": "pottery",
                "materials": ["terracotta", "clay"]
            }
        }
        response = await client.post("/catalog/generate", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert data["source_lang"] == "te"
        assert "master" in data
        assert "translations" in data
        assert "original" in data
        
        # Verify 6 languages exist
        for lang in ["en", "hi", "ta", "te", "kn", "ml"]:
            assert lang in data["translations"]
            listing = data["translations"][lang]
            assert "title" in listing
            assert "short_description" in listing
            assert "seo_title" in listing
            assert len(listing["seo_title"]) <= 60

@pytest.mark.asyncio
async def test_refine_catalog_endpoint():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        current_listing = {
            "master": {
                "title": "Terracotta Pot",
                "short_description": "Handmade clay pot with lid.",
                "long_description": "Crafted from locally sourced clay by traditional artisans.",
                "bullet_points": ["Natural clay", "Eco friendly"],
                "materials": ["Terracotta clay"],
                "care_instructions": "Rinse with plain water.",
                "seo_title": "Handmade Terracotta Pot",
                "meta_description": "Eco friendly handmade terracotta pot.",
                "keywords": ["pottery", "clay"],
                "hashtags": ["#Terracotta"],
            }
        }
        payload = {
            "current_listing": current_listing,
            "instruction": "Make it shorter and add that my family made it by hand",
            "source_lang": "en",
            "category": "pottery",
        }
        response = await client.post("/catalog/refine", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert "master" in data
        assert "translations" in data
        for lang in ["en", "hi", "ta", "te", "kn", "ml"]:
            assert lang in data["translations"]
            assert "title" in data["translations"][lang]

