import pytest
import base64
from httpx import AsyncClient, ASGITransport

from app.main import app
from app.config import get_settings
from app.routers.assistant import FAQ_APP_SPECIAL, FAQ_WHO_MADE, FAQ_ECOMMERCE_DIFF, _check_faq

@pytest.fixture(autouse=True)
def setup_mock_ai_mode(monkeypatch):
    """Ensure AI_MODE is 'mock' for these unit tests."""
    settings = get_settings()
    monkeypatch.setattr(settings, "AI_MODE", "mock")
    monkeypatch.setattr(settings, "GEMINI_API_KEY", "")

@pytest.mark.asyncio
async def test_voice_speak_and_cache():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        payload = {
            "text": "Namaste, welcome to KalaSetu!",
            "lang": "en",
        }
        res1 = await client.post("/voice/speak", json=payload)
        assert res1.status_code == 200
        data1 = res1.json()
        assert "audio_base64" in data1
        assert data1["mime_type"] == "audio/wav"
        assert len(data1["hash"]) == 64
        assert data1["voice"] == "Kore"
        assert data1["lang"] == "en"

        # Verify decoded audio has standard RIFF/WAVE header
        audio_bytes = base64.b64decode(data1["audio_base64"])
        assert audio_bytes.startswith(b"RIFF")
        assert b"WAVE" in audio_bytes[:16]

        # Second identical call should return cached=True with identical audio
        res2 = await client.post("/voice/speak", json=payload)
        assert res2.status_code == 200
        data2 = res2.json()
        assert data2["cached"] is True
        assert data2["hash"] == data1["hash"]
        assert data2["audio_base64"] == data1["audio_base64"]

        # Verify GET /voice/audio/{hash} returns audio/wav file
        res_audio = await client.get(f"/voice/audio/{data1['hash']}")
        assert res_audio.status_code == 200
        assert res_audio.headers["content-type"] == "audio/wav"
        assert len(res_audio.content) == len(audio_bytes)

@pytest.mark.asyncio
async def test_voice_speak_all_six_languages():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        phrases = {
            "en": "Artisan AI lets artisans sell by simply taking a photo.",
            "hi": "नमस्ते, कलासेतु में आपका स्वागत है।",
            "ta": "வணக்கம், கலாசேதுவிற்கு வரவேற்கிறோம்.",
            "te": "నమస్కారం, కలాసేతుకు స్వాగతం.",
            "kn": "ನಮಸ್ಕಾರ, ಕಲಾಸೇತುಗೆ ಸುಸ್ವಾಗತ.",
            "ml": "നമസ്കാരം, കലാസേതുവിലേക്ക് സ്വാഗതം.",
        }
        for lang, text in phrases.items():
            res = await client.post("/voice/speak", json={"text": text, "lang": lang})
            assert res.status_code == 200
            data = res.json()
            assert data["lang"] == lang
            assert len(data["audio_base64"]) > 50

@pytest.mark.asyncio
async def test_voice_empty_text_returns_400():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.post("/voice/speak", json={"text": "   ", "lang": "en"})
        assert res.status_code == 400
        assert "empty" in res.json()["detail"].lower()

@pytest.mark.asyncio
async def test_voice_unsupported_language_falls_back():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.post("/voice/speak", json={"text": "Hello artisans", "lang": "fr"})
        assert res.status_code == 200
        data = res.json()
        # Should gracefully normalize to en
        assert data["lang"] == "en"

@pytest.mark.asyncio
async def test_voice_missing_tts_model_fallback(monkeypatch):
    settings = get_settings()
    monkeypatch.setattr(settings, "AI_MODE", "real")
    monkeypatch.setattr(settings, "GEMINI_TTS_MODEL", "")
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.post("/voice/speak", json={"text": "Testing missing model fallback", "lang": "en"})
        assert res.status_code == 503
        assert "fallback" in res.json()["detail"].lower()

@pytest.mark.asyncio
async def test_voice_concurrent_requests():
    import asyncio
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        payload = {"text": "Concurrent speech test phrase", "lang": "en"}
        res1, res2 = await asyncio.gather(
            client.post("/voice/speak", json=payload),
            client.post("/voice/speak", json=payload)
        )
        assert res1.status_code == 200
        assert res2.status_code == 200
        assert res1.json()["hash"] == res2.json()["hash"]

@pytest.mark.asyncio
async def test_kalamitra_faq_who_made_all_six_languages():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        queries = {
            "en": "Who made you?",
            "hi": "तुम्हें किसने बनाया?",
            "ta": "உங்களை யார் உருவாக்கியது?",
            "te": "నిన్ను ఎవరు తయారు చేశారు?",
            "kn": "ನಿಮ್ಮನ್ನು ಯಾರು ಮಾಡಿದ್ದು?",
            "ml": "നിങ്ങളെ ആരാണ് ഉണ്ടാക്കിയത്?",
        }
        for lang, query in queries.items():
            res = await client.post(
                "/assistant/chat",
                json={"message": query, "current_screen": "home", "language": lang}
            )
            assert res.status_code == 200
            data = res.json()
            expected = FAQ_WHO_MADE[lang]
            assert data["reply"] == expected, f"Failed for {lang}: expected '{expected}', got '{data['reply']}'"
            assert "Noam" in data["reply"]

@pytest.mark.asyncio
async def test_kalamitra_faq_app_special_all_six_languages():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        queries = {
            "en": "What is special about this app?",
            "hi": "इस ऐप में क्या खास है?",
            "ta": "இந்த பயன்பாட்டில் என்ன சிறப்பு?",
            "te": "ఈ యాప్‌లో ప్రత్యేకత ఏమిటి?",
            "kn": "ಈ ಆ್ಯಪ್‌ನಲ್ಲಿ ಏನು ವಿಶೇಷ?",
            "ml": "ഈ ആപ്പിൽ എന്താണ് പ്രത്യേകത?",
        }
        for lang, query in queries.items():
            res = await client.post(
                "/assistant/chat",
                json={"message": query, "current_screen": "home", "language": lang}
            )
            assert res.status_code == 200
            data = res.json()
            expected = FAQ_APP_SPECIAL[lang]
            assert data["reply"] == expected, f"Failed for {lang}: expected '{expected}', got '{data['reply']}'"

@pytest.mark.asyncio
async def test_kalamitra_faq_ecommerce_difference_all_six_languages():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        queries = {
            "en": "How are you different from Amazon?",
            "hi": "अमेज़न से कैसे अलग है यह ऐप?",
            "ta": "அமேசானிலிருந்து எவ்வாறு வேறுபடுகிறது?",
            "te": "అమెజాన్ నుండి ఎలా భిన్నమైనది?",
            "kn": "ಅಮೆಜಾನ್‌ಗಿಂತ ಹೇಗೆ ಭಿನ್ನ?",
            "ml": "ആമസോണിൽ നിന്ന് എങ്ങനെ വ്യത്യസ്തമാണ്?",
        }
        for lang, query in queries.items():
            res = await client.post(
                "/assistant/chat",
                json={"message": query, "current_screen": "home", "language": lang}
            )
            assert res.status_code == 200
            data = res.json()
            expected = FAQ_ECOMMERCE_DIFF[lang]
            assert data["reply"] == expected, f"Failed for {lang}: expected '{expected}', got '{data['reply']}'"
            assert len(data["reply"]) > 20

@pytest.mark.asyncio
async def test_general_questions_not_intercepted_by_faq():
    """Verify normal craft and technical questions do NOT get intercepted by fixed FAQ."""
    general_queries = [
        "What is Python?",
        "What is GST?",
        "How should I package a handmade terracotta bowl?",
        "What does SEO mean for artisans?",
        "What is cotton fabric?",
        "How can I calculate profit margins?",
    ]
    for q in general_queries:
        match = _check_faq(q, "en")
        assert match is None, f"Query '{q}' was incorrectly intercepted by FAQ!"
