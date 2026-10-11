"""
KalaSetu - Dynamic Pricing Router
Section 9 of Project Specification
"""
import logging
from typing import Any, Dict, List, Optional
from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field

from app.config import get_settings
from app.services.price_estimator import DynamicPriceEstimator
from app.providers.mock_providers import MockPriceEstimator

logger = logging.getLogger("kalasetu.routers.pricing")
router = APIRouter(prefix="/pricing", tags=["Pricing"])

_ESTIMATOR_INSTANCE: Optional[DynamicPriceEstimator] = None

def get_estimator():
    global _ESTIMATOR_INSTANCE
    if _ESTIMATOR_INSTANCE is None:
        _ESTIMATOR_INSTANCE = DynamicPriceEstimator()
    return _ESTIMATOR_INSTANCE

class SuggestPriceRequest(BaseModel):
    product_id: Optional[str] = None
    category: str = Field(..., description="Craft category: pottery, handloom, jewelry, wood craft, bamboo")
    materials: List[str] = Field(default_factory=list, description="List of materials used")
    material_cost: float = Field(default=0.0, ge=0, description="Cost of raw materials in INR")
    raw_material_cost: Optional[float] = Field(None, ge=0, description="Alias for material_cost")
    labour_hours: float = Field(default=1.0, ge=0, description="Hours of artisan handcrafting labour")
    hours_of_work: Optional[float] = Field(None, ge=0, description="Alias for labour_hours")
    size_cm: Optional[float] = Field(25.0, description="Physical dimension in cm")
    technique: Optional[str] = Field(None, description="Crafting technique, e.g. wheel-thrown, jali-carving")
    region: Optional[str] = Field(None, description="Artisan state/region code, e.g. TN, WB, RJ")
    quality_score: Optional[float] = Field(85.0, description="Image quality score (0-100)")
    user_expected_price: Optional[float] = Field(None, description="Artisan's own expected price in INR")
    approved_image: Optional[str] = Field(None, description="URL or local path to approved craft photo")
    listing_text: Optional[str] = Field(None, description="Draft or approved listing text / title")
    date: Optional[str] = Field(None, description="Date for seasonality calculation (YYYY-MM-DD or ISO)")
    lang: Optional[str] = Field("en", description="App language code: en, hi, ta, te, kn, ml")
    other_cost: float = Field(default=0.0, ge=0, description="Packaging, transport, tools, electricity in INR")
    other_product_costs: Optional[float] = Field(None, ge=0, description="Alias for other_cost")

class PricingFeedbackRequest(BaseModel):
    product_id: Optional[str] = None
    recommended_price: int
    chosen_price: int
    action: str = Field(..., description="accepted, edited, or ignored")
    reason: Optional[str] = None

@router.post("/suggest")
async def suggest_price(req: SuggestPriceRequest):
    """
    Computes fair cost floor, market trends with Search grounding, gradient-boosted ML prediction,
    seasonal adjustments, attractive rounded price tiers, and localized explanation.
    """
    settings = get_settings()

    mat_cost = req.raw_material_cost if req.raw_material_cost is not None else req.material_cost
    lab_hours = req.hours_of_work if req.hours_of_work is not None else req.labour_hours
    other = req.other_product_costs if req.other_product_costs is not None else req.other_cost

    # In mock mode, if requested specifically or ML model missing
    if settings.AI_MODE == "mock" or not get_estimator()._booster:
        mock_estimator = MockPriceEstimator()
        return await mock_estimator.suggest_price(
            material_cost=mat_cost,
            labour_hours=lab_hours,
            category=req.category,
            materials=req.materials,
            region=req.region,
            user_expected_price=req.user_expected_price,
            other_cost=other,
        )

    try:
        estimator = get_estimator()
        result = await estimator.suggest_price(
            material_cost=mat_cost,
            labour_hours=lab_hours,
            category=req.category,
            materials=req.materials,
            size_cm=req.size_cm,
            technique=req.technique,
            region=req.region,
            quality_score=req.quality_score,
            user_expected_price=req.user_expected_price,
            app_lang=req.lang or "en",
            approved_image=req.approved_image,
            listing_text=req.listing_text,
            date=req.date,
            other_cost=other,
        )
        return result
    except Exception as e:
        logger.error(f"Error in suggest_price: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Pricing estimation failed: {str(e)}"
        )


@router.post("/feedback")
async def record_feedback(feedback: PricingFeedbackRequest):
    """
    Logs artisan feedback when accepting, editing, or ignoring suggested prices.
    Used for model retraining in Section 9.1.
    """
    logger.info(
        f"Pricing feedback logged: action={feedback.action}, "
        f"recommended=₹{feedback.recommended_price}, chosen=₹{feedback.chosen_price}"
    )
    return {
        "status": "recorded",
        "action": feedback.action,
        "delta": feedback.chosen_price - feedback.recommended_price
    }
