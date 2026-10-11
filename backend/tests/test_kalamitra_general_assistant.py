import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app
from app.config import get_settings
from app.services.kalamitra_knowledge import (
    classify_query,
    get_relevant_context,
    CATEGORY_A,
    CATEGORY_B,
    CATEGORY_C,
    INTENT_CREATOR,
)

settings = get_settings()

@pytest.fixture
def mock_ai_mode(monkeypatch):
    """Fixture to ensure tests run in mock AI mode deterministically."""
    monkeypatch.setattr(settings, "AI_MODE", "mock")

def test_query_classification_categories():
    """Verify classification engine correctly partitions queries into categories."""
    # Category A: KalaSetu / Project
    assert classify_query("Why should I use KalaSetu instead of Amazon?") == CATEGORY_A
    assert classify_query("What is special about KalaSetu?") == CATEGORY_A
    assert classify_query("How does KalaSetu help an artisan?") == CATEGORY_A
    assert classify_query("What problem does KalaSetu solve?") == CATEGORY_A
    assert classify_query("Why do artisans need KalaSetu if they already have e-commerce apps?") == CATEGORY_A
    assert classify_query("How does KalaSetu calculate price?") == CATEGORY_A

    # Category B: General
    assert classify_query("What is Python?") == CATEGORY_B
    assert classify_query("Tell me a joke.") == CATEGORY_B
    assert classify_query("How do I learn machine learning?") == CATEGORY_B
    assert classify_query("Who is the president of India?") == CATEGORY_B

    # Category C: Live / Current Information
    assert classify_query("What is today's weather?") == CATEGORY_C
    assert classify_query("What is the temperature now?") == CATEGORY_C
    assert classify_query("What are today's news?") == CATEGORY_C

    # Creator
    assert classify_query("Who created you?") == INTENT_CREATOR
    assert classify_query("Who made this app?") == INTENT_CREATOR

def test_context_continuity_with_history():
    """Verify follow-up query 'How does it help artisans?' recognizes 'it' refers to KalaSetu."""
    history = [
        {"role": "user", "content": "What is KalaSetu?"},
        {"role": "assistant", "content": "KalaSetu is an AI virtual business manager for artisans."}
    ]
    # Follow-up uses pronoun 'it'
    classified = classify_query("How does it help artisans?", history=history)
    assert classified == CATEGORY_A

    context = get_relevant_context(classified, "How does it help artisans?")
    assert context is not None
    assert "KEY FEATURE 1" in context or "BACKGROUND" in context

@pytest.mark.asyncio
async def test_kalamitra_ten_spec_requirements(mock_ai_mode):
    """Test all 10 specific categories and test cases requested in the specification."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # TEST 1: "Why should I use KalaSetu instead of Amazon?"
        resp1 = await client.post("/api/v1/assistant/chat", json={
            "message": "Why should I use KalaSetu instead of Amazon?",
            "language": "en"
        })
        assert resp1.status_code == 200
        data1 = resp1.json()
        r1 = data1["reply"].lower()
        assert "amazon" in r1 or "e-commerce" in r1 or "marketplace" in r1
        assert "virtual business manager" in r1 or "artisan" in r1 or "photo" in r1

        # TEST 2: "What is special about KalaSetu?"
        resp2 = await client.post("/api/v1/assistant/chat", json={
            "message": "What is special about KalaSetu?",
            "language": "en"
        })
        assert resp2.status_code == 200
        data2 = resp2.json()
        r2 = data2["reply"].lower()
        assert "artisan" in r2 or "studio" in r2 or "voice" in r2 or "fair" in r2

        # TEST 3: "How does KalaSetu help an artisan?"
        resp3 = await client.post("/api/v1/assistant/chat", json={
            "message": "How does KalaSetu help an artisan?",
            "language": "en"
        })
        assert resp3.status_code == 200
        data3 = resp3.json()
        r3 = data3["reply"].lower()
        assert "image" in r3 or "studio" in r3 or "voice" in r3 or "pricing" in r3

        # TEST 4: "What is Python?"
        resp4 = await client.post("/api/v1/assistant/chat", json={
            "message": "What is Python?",
            "language": "en"
        })
        assert resp4.status_code == 200
        data4 = resp4.json()
        r4 = data4["reply"].lower()
        assert "programming language" in r4 or "python" in r4

        # TEST 5: "Tell me a joke."
        resp5 = await client.post("/api/v1/assistant/chat", json={
            "message": "Tell me a joke.",
            "language": "en"
        })
        assert resp5.status_code == 200
        data5 = resp5.json()
        assert len(data5["reply"]) > 10

        # TEST 6: "How do I learn machine learning?"
        resp6 = await client.post("/api/v1/assistant/chat", json={
            "message": "How do I learn machine learning?",
            "language": "en"
        })
        assert resp6.status_code == 200
        data6 = resp6.json()
        r6 = data6["reply"].lower()
        assert "machine learning" in r6 or "algorithms" in r6 or "data" in r6

        # TEST 7: "What is today's weather?"
        resp7 = await client.post("/api/v1/assistant/chat", json={
            "message": "What is today's weather?",
            "language": "en"
        })
        assert resp7.status_code == 200
        data7 = resp7.json()
        r7 = data7["reply"].lower()
        assert "unavailable" in r7 or "do not have access" in r7
        # Verify weather is not fabricated
        assert "sunny 28" not in r7 and "rainy 25" not in r7

        # TEST 8: "Who created you?"
        resp8 = await client.post("/api/v1/assistant/chat", json={
            "message": "Who created you?",
            "language": "en"
        })
        assert resp8.status_code == 200
        data8 = resp8.json()
        assert data8["reply"] == "I was created by Noam."

        # TEST 9: "What problem does KalaSetu solve?"
        resp9 = await client.post("/api/v1/assistant/chat", json={
            "message": "What problem does KalaSetu solve?",
            "language": "en"
        })
        assert resp9.status_code == 200
        data9 = resp9.json()
        r9 = data9["reply"].lower()
        assert "gap" in r9 or "digital literacy" in r9 or "traditional" in r9 or "fair" in r9

        # TEST 10: "Why do artisans need KalaSetu if they already have e-commerce apps?"
        resp10 = await client.post("/api/v1/assistant/chat", json={
            "message": "Why do artisans need KalaSetu if they already have e-commerce apps?",
            "language": "en"
        })
        assert resp10.status_code == 200
        data10 = resp10.json()
        r10 = data10["reply"].lower()
        assert "barrier" in r10 or "typing" in r10 or "photo" in r10 or "language" in r10

@pytest.mark.asyncio
async def test_kalamitra_followup_conversation_context(mock_ai_mode):
    """Verify multi-turn session preservation with follow-up queries."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Turn 1
        resp1 = await client.post("/api/v1/assistant/chat", json={
            "message": "What is KalaSetu?",
            "language": "en"
        })
        assert resp1.status_code == 200
        data1 = resp1.json()

        history = [
            {"role": "user", "content": "What is KalaSetu?"},
            {"role": "assistant", "content": data1["reply"]}
        ]

        # Turn 2: Follow-up using 'it'
        resp2 = await client.post("/api/v1/assistant/chat", json={
            "message": "How does it help artisans?",
            "language": "en",
            "history": history
        })
        assert resp2.status_code == 200
        data2 = resp2.json()
        r2 = data2["reply"].lower()
        assert "artisan" in r2 or "image" in r2 or "voice" in r2 or "pricing" in r2
