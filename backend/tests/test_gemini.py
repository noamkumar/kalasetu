import json
import logging
import pytest
from unittest.mock import MagicMock, AsyncMock, patch

from app.providers.gemini_client import GeminiClient, GeminiClientError
from app.providers.mock_providers import (
    MockSpeechToText,
    MockTranslator,
    MockDescriptionGenerator,
    MockPriceEstimator,
    MockImageEnhancer,
)
from app.providers.interfaces import (
    SpeechToText,
    Translator,
    DescriptionGenerator,
    PriceEstimator,
    ImageEnhancer,
)

def test_gemini_client_unconfigured():
    client = GeminiClient(api_key="")
    assert not client.is_configured
    with pytest.raises(GeminiClientError) as exc_info:
        client.generate_text_sync("Hello")
    assert "Gemini API key is not configured" in str(exc_info.value)

def test_gemini_client_never_logs_api_key(caplog):
    secret_key = "mock-secret-key-1234567890"
    client = GeminiClient(api_key=secret_key, default_model="gemini-3.1-flash-lite")
    
    with caplog.at_level(logging.INFO):
        client._log_latency(
            model="gemini-3.1-flash-lite",
            latency_ms=123.45,
            status="success",
            json_mode=False
        )
    
    logged_output = caplog.text
    assert secret_key not in logged_output
    assert "gemini_call" in logged_output
    assert "gemini-3.1-flash-lite" in logged_output

@pytest.mark.asyncio
async def test_gemini_client_fallback_on_model_not_found():
    client = GeminiClient(
        api_key="mock-key-for-test",
        default_model="deprecated-model-1.0",
        fallback_model="gemini-fallback-model",
    )
    
    # Mock the internal client.aio.models.generate_content
    mock_response = MagicMock()
    mock_response.text = "Fallback response text"
    
    call_count = 0
    async def mock_generate_content(model, contents, config):
        nonlocal call_count
        call_count += 1
        if model == "deprecated-model-1.0":
            raise Exception("Model deprecated-model-1.0 not found or deprecated")
        return mock_response
    
    client._client = MagicMock()
    client._client.aio = MagicMock()
    client._client.aio.models = MagicMock()
    client._client.aio.models.generate_content = AsyncMock(side_effect=mock_generate_content)
    
    result = await client.generate_text("Test prompt")
    assert result == "Fallback response text"
    assert call_count == 2

@pytest.mark.asyncio
async def test_mock_providers_conform_to_interfaces():
    stt = MockSpeechToText()
    assert isinstance(stt, SpeechToText)
    transcription = await stt.transcribe(b"dummy_audio", language_hint="hi")
    assert "text" in transcription
    assert transcription["detected_lang"] == "hi"

    translator = MockTranslator()
    assert isinstance(translator, Translator)
    translations = await translator.translate("नमस्ते", source_lang="hi", target_langs=["en", "ta"])
    assert "en" in translations
    assert "ta" in translations

    desc_gen = MockDescriptionGenerator()
    assert isinstance(desc_gen, DescriptionGenerator)
    catalog = await desc_gen.generate_catalog("Handmade pot", source_lang="en")
    assert "source" in catalog or "master" in catalog or "title" in str(catalog)

    price_est = MockPriceEstimator()
    assert isinstance(price_est, PriceEstimator)
    price_info = await price_est.suggest_price(
        material_cost=100.0,
        labour_hours=2.0,
        category="pottery",
        materials=["clay"]
    )
    assert "recommended" in price_info
    assert "floor" in price_info

    enhancer = MockImageEnhancer()
    assert isinstance(enhancer, ImageEnhancer)
    enhanced = await enhancer.enhance_image(b"dummy_image")
    assert "status" in enhanced
    assert enhanced["status"] == "done"
