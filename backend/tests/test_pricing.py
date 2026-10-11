"""
Unit and integration tests for KalaSetu Dynamic Pricing Engine
Section 9 of Project Specification
"""
import pytest
from httpx import AsyncClient, ASGITransport

from app.main import app
from app.services.price_estimator import (
    calculate_cost_floor,
    round_to_attractive,
    DynamicPriceEstimator,
)

def test_calculate_cost_floor():
    """Verify statutory cost floor calculation with fair wages and 10% overhead."""
    # material_cost = 100, labour_hours = 3, wage_rate = 95
    # labour_cost = 285
    # base = 385
    # overhead = 38.5
    # floor = ceil(423.5) = 424
    floor, breakdown = calculate_cost_floor(
        material_cost=100.0,
        labour_hours=3.0,
        fair_wage_rate=95.0,
        overhead_pct=0.10
    )
    assert floor == 424
    assert breakdown["material_cost"] == 100.0
    assert breakdown["labour_hours"] == 3.0
    assert breakdown["labour_cost"] == 285.0
    assert breakdown["overhead"] == 38.5
    assert breakdown["floor"] == 424

def test_round_to_attractive():
    """Verify attractive price points and min_floor protection."""
    # 440 should round to 449
    assert round_to_attractive(440) == 449
    # 780 should round to 799
    assert round_to_attractive(780) == 799
    # 1180 should round to 1199
    assert round_to_attractive(1180) == 1199

    # min_floor protection: if raw value is 300 and rounds to 299, but min_floor is 320,
    # it must round to >= 320 (e.g. 349)
    res = round_to_attractive(300, min_floor=320)
    assert res >= 320
    assert res in [349, 399]

@pytest.mark.asyncio
async def test_pricing_suggest_standard():
    """Test POST /pricing/suggest with standard craft product."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        payload = {
            "category": "pottery",
            "materials": ["terracotta"],
            "material_cost": 80.0,
            "labour_hours": 3.0,
            "size_cm": 25.0,
            "region": "TN",
            "technique": "wheel-thrown",
            "quality_score": 88.0,
            "lang": "en"
        }
        response = await client.post("/pricing/suggest", json=payload)
        assert response.status_code == 200
        data = response.json()

        # Floor validation
        assert "floor" in data
        assert "recommended" in data
        assert "budget" in data
        assert "premium" in data

        floor = data["floor"]
        recommended = data["recommended"]
        budget = data["budget"]
        premium = data["premium"]

        # Rule: Recommended price NEVER below floor
        assert recommended >= floor
        assert budget >= floor
        assert premium >= recommended

        # Comparables present
        assert data["has_comparables"] is True
        assert len(data["comparables"]) > 0
        assert data["confidence"] >= 0.70
        assert data["label"] == "Market benchmarked"

        # Explanation has numbers
        assert "explanation" in data
        assert "en" in data["explanation"]
        assert str(recommended) in data["explanation"]["en"]

@pytest.mark.asyncio
async def test_pricing_suggest_no_comparables():
    """Test POST /pricing/suggest when no market comparables exist."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Unknown alien category
        payload = {
            "category": "extraterrestrial-crystal-art",
            "materials": ["stardust-meteorite"],
            "material_cost": 250.0,
            "labour_hours": 4.0,
            "lang": "en"
        }
        response = await client.post("/pricing/suggest", json=payload)
        assert response.status_code == 200
        data = response.json()

        assert data["has_comparables"] is False
        assert len(data["comparables"]) == 0
        # Requirement: Label "Estimate based on your costs only"
        assert data["label"] == "Estimate based on your costs only"
        # Requirement: Lowered confidence
        assert data["confidence"] < 0.60
        # Requirement: Never below floor
        assert data["recommended"] >= data["floor"]
        assert "Estimate based on your costs only" in data["explanation"]["en"]

@pytest.mark.asyncio
async def test_pricing_suggest_below_floor_warning():
    """Test warning when user expected price is below cost floor."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        payload = {
            "category": "pottery",
            "materials": ["terracotta"],
            "material_cost": 150.0,
            "labour_hours": 5.0,
            "user_expected_price": 200.0, # Way below floor (~680)
            "lang": "en"
        }
        response = await client.post("/pricing/suggest", json=payload)
        assert response.status_code == 200
        data = response.json()

        assert data["warning"] is not None
        assert "below your cost floor" in data["warning"]
        assert "loss" in data["warning"].lower()

@pytest.mark.asyncio
async def test_pricing_feedback():
    """Test POST /pricing/feedback logging endpoint."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        payload = {
            "recommended_price": 449,
            "chosen_price": 499,
            "action": "edited"
        }
        response = await client.post("/pricing/feedback", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "recorded"
        assert data["delta"] == 50

@pytest.mark.asyncio
async def test_pricing_thin_evidence_and_attributes():
    """Verify thin-evidence labeling as 'Estimate', structured attributes, and impact message."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        payload = {
            "category": "rare-unrecorded-tribal-craft",
            "materials": ["uncommon-grass"],
            "raw_material_cost": 120.0,
            "hours_of_work": 3.0,
            "region": "NE",
            "date": "2026-10-15",
            "listing_text": "Handcrafted woven basket with geometric motif",
            "lang": "en",
        }
        response = await client.post("/pricing/suggest", json=payload)
        assert response.status_code == 200
        data = response.json()

        # Thin evidence verification
        assert "Estimate" in data["label"]
        assert data["confidence"] <= 0.60
        assert data["recommended"] >= data["floor"]

        # Structured attributes verification
        assert "attributes" in data
        attrs = data["attributes"]
        assert "category" in attrs
        assert "craft_complexity" in attrs
        assert "finish_quality" in attrs
        assert "uniqueness" in attrs

        # Impact message
        assert "impact_message" in data
        assert "fair price" in data["impact_message"].lower() or "guarantee" in data["impact_message"].lower()

        # Market trends structure
        assert "market_trends" in data
        assert "date_fetched" in data["market_trends"]
        assert "price_range" in data["market_trends"]

def test_rounding_edge_cases_and_floors():
    """Verify attractive price points never recommend below cost floor."""
    # Test multiple values against their cost floors
    for raw_price in [50, 100, 230, 480, 720, 1050, 2500]:
        floor = raw_price + 30
        rounded = round_to_attractive(raw_price, min_floor=floor)
        assert rounded >= floor
        assert rounded % 10 in [9, 0] or rounded in [49, 99, 149, 199, 249, 299, 349, 399, 449, 499, 549, 599, 649, 699, 749, 799, 849, 899, 949, 999, 1199, 1499]

