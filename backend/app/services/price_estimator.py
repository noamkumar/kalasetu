"""
KalaSetu - Dynamic Pricing Assistant Engine
Section 9 of Project Specification
"""
import os
import json
import math
import logging
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import numpy as np

from app.config import get_settings
from app.services.market_data import MarketDataService

logger = logging.getLogger("kalasetu.price_estimator")

ATTRACTIVE_POINTS = [
    99, 149, 199, 249, 299, 349, 399, 449, 499, 549, 599, 649, 699, 749, 799, 849, 899, 949, 999,
    1099, 1199, 1299, 1399, 1499, 1599, 1699, 1799, 1899, 1999, 2199, 2299, 2499, 2799, 2999,
    3299, 3499, 3999, 4499, 4999, 5499, 5999, 6499, 6999, 7499, 7999, 8499, 8999, 9999, 11999, 14999
]

def round_to_attractive(val: float, min_floor: Optional[int] = None) -> int:
    """
    Rounds a numerical value to an attractive e-commerce psychological price point
    (e.g., 449, 799, 1199) and guarantees it never drops below min_floor if specified.
    """
    val_float = float(val)
    if val_float <= ATTRACTIVE_POINTS[-1]:
        # Find closest point
        closest = min(ATTRACTIVE_POINTS, key=lambda x: abs(x - val_float))
    else:
        # High value rounding: nearest 100 minus 1
        closest = int(round(val_float / 100.0) * 100 - 1)

    if min_floor is not None and closest < min_floor:
        # Step up to first attractive point >= min_floor
        for pt in ATTRACTIVE_POINTS:
            if pt >= min_floor:
                return pt
        return int(math.ceil(min_floor / 100.0) * 100 - 1)

    return closest

def calculate_cost_floor(
    material_cost: float,
    labour_hours: float,
    fair_wage_rate: float = 95.0,
    overhead_pct: float = 0.10,
    other_cost: float = 0.0,
) -> Tuple[int, Dict[str, float]]:
    """
    Computes statutory/fair cost floor:
    floor = material_cost + (labour_hours * fair_wage_rate) + other_cost + (10% overhead)
    """
    mat_cost = max(0.0, float(material_cost))
    hours = max(0.0, float(labour_hours))
    other = max(0.0, float(other_cost))
    labour_cost = hours * fair_wage_rate
    base_sum = mat_cost + labour_cost + other
    overhead = base_sum * overhead_pct
    floor = int(math.ceil(base_sum + overhead))

    breakdown = {
        "material_cost": round(mat_cost, 2),
        "labour_hours": round(hours, 2),
        "fair_wage_rate": round(fair_wage_rate, 2),
        "labour_cost": round(labour_cost, 2),
        "other_cost": round(other, 2),
        "overhead": round(overhead, 2),
        "floor": floor
    }
    return floor, breakdown

class DynamicPriceEstimator:
    def __init__(
        self,
        model_path: Optional[str] = None,
        meta_path: Optional[str] = None,
        market_service: Optional[MarketDataService] = None
    ):
        base_dir = Path(__file__).resolve().parent.parent.parent
        self.model_path = Path(model_path) if model_path else base_dir / "ml" / "artifacts" / "pricing_model.txt"
        self.meta_path = Path(meta_path) if meta_path else base_dir / "ml" / "artifacts" / "model_meta.json"
        self.market_service = market_service or MarketDataService()

        self._booster = None
        self._meta = {}
        self._load_model()

    def _load_model(self):
        """Loads trained LightGBM Booster and metadata if available."""
        try:
            if self.model_path.exists():
                import lightgbm as lgb
                self._booster = lgb.Booster(model_file=str(self.model_path))
                logger.info(f"Loaded pricing model booster from {self.model_path.name}")
            else:
                logger.warning(f"Pricing model file not found at {self.model_path}")

            if self.meta_path.exists():
                with open(self.meta_path, "r", encoding="utf-8") as f:
                    self._meta = json.load(f)
        except Exception as e:
            logger.error(f"Failed to load pricing ML model: {e}")
            self._booster = None

    async def suggest_price(
        self,
        material_cost: float,
        labour_hours: float,
        category: str,
        materials: List[str],
        size_cm: Optional[float] = None,
        technique: Optional[str] = None,
        region: Optional[str] = None,
        quality_score: Optional[float] = None,
        user_expected_price: Optional[float] = None,
        app_lang: str = "en",
        fair_wage_rate: float = 95.0,
        approved_image: Optional[str] = None,
        listing_text: Optional[str] = None,
        date: Optional[str] = None,
        other_cost: float = 0.0,
    ) -> Dict[str, Any]:
        """
        Executes dynamic fair pricing algorithm:
        1. Compute statutory cost floor
        2. Gemini vision/text extracts structured attributes (category, material, size, complexity, finish, uniqueness)
        3. Market trends via Google Search grounding (24h cache per category/material, 'Estimate' if thin)
        4. Seasonality adjustment from date (festivals, wedding season)
        5. LightGBM ML regression prediction on seed + app sold dataset
        6. Constraint: Final price = ML output constrained by cost floor (never below floor)
        7. Attractive psychological rounding
        8. Gemini localized spoken explanation & simple 'fair price for your work' impact message
        """
        from datetime import datetime, timezone

        # 1. Statutory Cost Floor
        floor, cost_breakdown = calculate_cost_floor(
            material_cost=material_cost,
            labour_hours=labour_hours,
            fair_wage_rate=fair_wage_rate,
            overhead_pct=0.10,
            other_cost=other_cost,
        )

        # 2. Extract Structured Attributes via Gemini Vision/Text
        settings = get_settings()
        attributes: Dict[str, Any] = {
            "category": category.lower().strip(),
            "material": materials[0].lower().strip() if materials else "natural material",
            "size": f"{size_cm or 25}cm",
            "craft_complexity": "moderate",
            "finish_quality": "smooth",
            "uniqueness": "regional",
        }

        if settings.AI_MODE == "real" and settings.GEMINI_API_KEY:
            try:
                from app.providers.gemini_provider import GeminiAttributeExtractor
                extractor = GeminiAttributeExtractor()
                extracted = await extractor.extract_attributes(
                    listing_text=listing_text,
                    category_hint=category,
                )
                if extracted:
                    attributes.update(extracted)
            except Exception as e:
                logger.info(f"Gemini attribute extraction notice: {e}")

        # 3. Market Trends with Google Search Grounding & 24h Cache
        comp_result = self.market_service.get_comparables(
            category=category,
            materials=materials,
            region=region,
            limit=4
        )
        comparables = comp_result.get("comparables", [])
        stats = comp_result.get("stats")

        market_trends = await self.market_service.get_market_trends_grounded(
            category=category,
            materials=materials,
            region=region,
        )

        has_comparables = bool(comparables and stats and stats.get("count", 0) > 0)
        has_market_sources = bool(market_trends.get("source_links"))

        if not has_comparables and not has_market_sources:
            confidence = 0.50
            status_label = "Estimate based on your costs only"
            evidence_level = "thin"
        elif not has_comparables:
            confidence = 0.58
            status_label = "Estimate"
            evidence_level = "thin"
        else:
            confidence = 0.86
            status_label = "Market benchmarked"
            evidence_level = market_trends.get("evidence_level", "grounded")

        # 4. Seasonality Factor from Date Input (festivals, wedding season)
        try:
            if date:
                # Accept ISO e.g. 2026-10-10 or YYYY-MM-DD
                dt = datetime.fromisoformat(date.replace("Z", "+00:00"))
                month = dt.month
            else:
                month = datetime.now(timezone.utc).month
        except Exception:
            month = 10

        # Season multiplier: Oct-Nov (Diwali/Dussehra: +12%), Dec-Feb (Weddings/Pongal: +10%), Aug-Sep (+8%)
        if month in (10, 11):
            season_factor = 1.12
        elif month in (12, 1, 2):
            season_factor = 1.10
        elif month in (8, 9):
            season_factor = 1.08
        else:
            season_factor = 1.00

        # 5. ML Model Prediction (LightGBM)
        ml_prediction = None
        if self._booster is not None and self._meta:
            try:
                cat_mappings = self._meta.get("category_mappings", {})
                cat_val = attributes["category"].lower()
                mat_val = attributes["material"].lower()
                tech_val = (technique or "handcrafted").lower()
                reg_val = (region or "IN").upper()
                comp_med = float(stats["median"]) if stats and stats.get("median") else float(floor * 1.4)

                row_dict = {
                    "category": cat_val if cat_val in cat_mappings.get("category", []) else cat_mappings.get("category", [cat_val])[0],
                    "material": mat_val if mat_val in cat_mappings.get("material", []) else cat_mappings.get("material", [mat_val])[0],
                    "technique": tech_val if tech_val in cat_mappings.get("technique", []) else cat_mappings.get("technique", [tech_val])[0],
                    "region": reg_val if reg_val in cat_mappings.get("region", []) else cat_mappings.get("region", [reg_val])[0],
                    "size_cm": float(size_cm or 25.0),
                    "material_cost": float(material_cost),
                    "labour_hours": float(labour_hours),
                    "quality_score": float(quality_score or 85.0),
                    "cost_floor": float(floor),
                    "comparable_median": comp_med,
                    "craft_complexity": attributes.get("craft_complexity", "moderate"),
                    "finish_quality": attributes.get("finish_quality", "smooth"),
                    "uniqueness": attributes.get("uniqueness", "regional"),
                    "season_factor": float(season_factor),
                }

                df_row = pd.DataFrame([row_dict])
                for col in self._meta.get("categorical_columns", []):
                    valid_cats = cat_mappings.get(col, [])
                    val = df_row[col].iloc[0]
                    if valid_cats and val not in valid_cats:
                        val = valid_cats[0]
                    df_row[col] = pd.Categorical([val], categories=valid_cats)

                feature_cols = self._meta.get("feature_columns", df_row.columns.tolist())
                # Ensure all required feature columns exist
                for fc in feature_cols:
                    if fc not in df_row.columns:
                        df_row[fc] = 0.0

                pred_arr = self._booster.predict(df_row[feature_cols])
                if len(pred_arr) > 0 and pred_arr[0] > 0:
                    ml_prediction = float(pred_arr[0])
            except Exception as e:
                logger.warning(f"Booster prediction notice: {e}")
                ml_prediction = None

        # 6. Constrain ML Output by Cost Floor:
        # "Final price = ML output constrained by the cost floor (material + labour at a fair wage + overhead); never recommend below the floor."
        if ml_prediction is not None:
            raw_target = max(float(floor), ml_prediction)
        elif has_comparables:
            raw_target = max(float(floor), (0.6 * stats["median"]) + (0.4 * floor * 1.35))
        else:
            raw_target = float(floor) * 1.35

        # Apply seasonality factor
        target_price = raw_target * season_factor

        # Strict floor constraint: target never below floor
        target_price = max(float(floor), target_price)

        # 7. Round to Attractive Retail Price Points (never drop below floor)
        recommended = round_to_attractive(target_price, min_floor=floor)
        budget = round_to_attractive(max(floor, target_price * 0.88), min_floor=floor)
        premium = round_to_attractive(max(recommended * 1.18, target_price * 1.25), min_floor=recommended)

        # Absolute safety clamps
        if recommended < floor:
            recommended = round_to_attractive(floor, min_floor=floor)
        if budget < floor:
            budget = floor
        if premium < recommended:
            premium = round_to_attractive(recommended * 1.2, min_floor=recommended)

        # 8. Gentle Warning when below cost
        below_floor_warning = None
        if user_expected_price is not None and user_expected_price < floor:
            below_floor_warning = (
                f"Warning: Your price of ₹{int(user_expected_price)} is below your cost floor of ₹{floor}. "
                "Selling below your cost floor will result in a loss on raw materials and fair labour wages!"
            )

        # 9. Simple 'Fair Price for Your Work' Impact Message
        impact_message = (
            f"Fair price for your work: Guarantees ₹{int(fair_wage_rate)}/hr for your {cost_breakdown['labour_hours']}h "
            f"of skilled handcrafting, recovers all raw materials (₹{int(cost_breakdown['material_cost'])}), "
            f"and provides 10% workshop savings."
        )

        # 10. Factors Breakdown
        factors = [
            {"name": "Raw materials", "value": f"₹{int(cost_breakdown['material_cost'])}"},
            {"name": f"Fair labour ({cost_breakdown['labour_hours']}h @ ₹{int(fair_wage_rate)}/h)", "value": f"₹{int(cost_breakdown['labour_cost'])}"},
        ]
        if cost_breakdown.get("other_cost", 0) > 0:
            factors.append({"name": "Other product costs", "value": f"₹{int(cost_breakdown['other_cost'])}"})
        factors.extend([
            {"name": "Workshop overhead (10%)", "value": f"₹{int(cost_breakdown['overhead'])}"},
            {"name": "Cost floor (minimum safe price)", "value": f"₹{floor}"},
            {"name": "Artisan profit margin", "value": f"₹{recommended - floor}"},
            {"name": f"Seasonality demand ({month:02d})", "value": f"{int((season_factor - 1.0) * 100):+d}%"},
        ])
        if has_comparables:
            factors.append({"name": "Market comparable median", "value": f"₹{stats['median']}"})

        # 11. Multilingual Explanations
        explanation = await self._generate_explanation(
            recommended=recommended,
            floor=floor,
            material_cost=material_cost,
            labour_hours=labour_hours,
            fair_wage_rate=fair_wage_rate,
            has_comparables=has_comparables,
            app_lang=app_lang
        )

        return {
            "floor": floor,
            "budget": budget,
            "recommended": recommended,
            "premium": premium,
            "confidence": round(confidence, 2),
            "label": status_label,
            "evidence_level": evidence_level,
            "has_comparables": has_comparables,
            "breakdown": cost_breakdown,
            "factors": factors,
            "comparables": comparables,
            "comparable_stats": stats,
            "market_trends": market_trends,
            "attributes": attributes,
            "explanation": explanation,
            "warning": below_floor_warning,
            "impact_message": impact_message,
        }


    async def _generate_explanation(
        self,
        recommended: int,
        floor: int,
        material_cost: float,
        labour_hours: float,
        fair_wage_rate: float,
        has_comparables: bool,
        app_lang: str
    ) -> Dict[str, str]:
        """
        Generates localized explanation. Gemini is optionally queried if available,
        with strict instruction to never alter numerical figures.
        """
        # Deterministic multilingual baseline (guarantees accurate numbers always)
        profit = recommended - floor
        hours = round(labour_hours, 1)
        mat = int(material_cost)

        base_dict = {
            "en": (
                f"Recommended fair price of ₹{recommended} covers raw materials (₹{mat}), "
                f"{hours}h of fair labour wages (₹{int(hours * fair_wage_rate)}), overheads, "
                f"and guarantees a ₹{profit} artisan profit margin."
                if has_comparables else
                f"Estimate based on your costs only: ₹{recommended} protects your ₹{floor} minimum production floor "
                f"and provides a fair ₹{profit} artisan margin."
            ),
            "hi": (
                f"सुझाया गया मूल्य ₹{recommended} सामग्री (₹{mat}), {hours} घंटे का श्रम (₹{int(hours * fair_wage_rate)}), "
                f"और ₹{profit} का शिल्पकार लाभ सुरक्षित करता है।"
                if has_comparables else
                f"केवल आपकी लागत पर आधारित अनुमान: ₹{recommended} आपके ₹{floor} न्यूनतम लागत आधार की रक्षा करता है।"
            ),
            "ta": (
                f"பரிந்துரைக்கப்பட்ட நியாயமான விலை ₹{recommended}. இது மூலப்பொருட்கள் (₹{mat}), "
                f"{hours} மணிநேர உழைப்பு, மற்றும் ₹{profit} கைவினைஞர் லாபத்தை உறுதி செய்கிறது."
                if has_comparables else
                f"உங்கள் செலவுகளின் அடிப்படையிலான மதிப்பீடு: ₹{recommended} உங்கள் ₹{floor} அடிப்படை செலவை பாதுகாக்கிறது."
            ),
            "te": (
                f"సిఫార్సు చేయబడిన సరసమైన ధర ₹{recommended}. ఇది ముడి సరుకులు (₹{mat}), "
                f"{hours} గంటల శ్రమ మరియు ₹{profit} కళాకారుడి లాభాన్ని కాపాడుతుంది."
                if has_comparables else
                f"మీ ఖర్చుల ఆధారిత అంచనా: ₹{recommended} మీ ₹{floor} కనీస ఖర్చును రక్షిస్తుంది."
            ),
            "kn": (
                f"ಶಿಫಾರಸು ಮಾಡಿದ ನ್ಯಾಯಯುತ ಬೆಲೆ ₹{recommended}. ಇದು ಕಚ್ಚಾ ವಸ್ತುಗಳು (₹{mat}), "
                f"{hours} ಗಂಟೆಗಳ ಶ್ರಮ ಮತ್ತು ₹{profit} ಕುಶಲಕರ್ಮಿ ಲಾಭವನ್ನು ಖಾತರಿಪಡಿಸುತ್ತದೆ."
                if has_comparables else
                f"ನಿಮ್ಮ ವೆಚ್ಚದ ಆಧಾರಿತ ಅಂದಾಜು: ₹{recommended} ನಿಮ್ಮ ₹{floor} ಮೂಲ ವೆಚ್ಚವನ್ನು ರಕ್ಷಿಸುತ್ತದೆ."
            ),
            "ml": (
                f"ശുപാർശ ചെയ്ത ന്യായമായ വില ₹{recommended}. ഇത് അസംസ്കൃത വസ്തുക്കൾ (₹{mat}), "
                f"{hours} മണിക്കൂർ അധ്വാനം, കൂടാതെ ₹{profit} ലാഭവും ഉറപ്പാക്കുന്നു."
                if has_comparables else
                f"നിങ്ങളുടെ ചെലവുകളെ അടിസ്ഥാനമാക്കിയുള്ള കണക്കുകൂട്ടൽ: ₹{recommended} നിങ്ങളുടെ ₹{floor} ചെലവിനെ സംരക്ഷിക്കുന്നു."
            ),
        }

        # Optionally call Gemini Vision/Language client to polish phrasing in requested language
        # (while verifying numbers are preserved)
        settings = get_settings()
        if settings.AI_MODE == "real" and settings.GEMINI_API_KEY:
            try:
                from app.providers.gemini_provider import get_gemini_client
                client = get_gemini_client()
                if client.is_configured:
                    prompt = (
                        f"Write a friendly 1-2 sentence spoken audio explanation for an Indian artisan about their craft price.\n"
                        f"Language code: {app_lang}.\n"
                        f"Parameters: Recommended Price = ₹{recommended}, Cost Floor = ₹{floor}, "
                        f"Material Cost = ₹{mat}, Labour = {hours} hours, Profit = ₹{profit}.\n"
                        f"Has market comparables: {has_comparables}.\n"
                        f"CRITICAL RULE: DO NOT CHANGE ANY NUMBERS. Use the exact values ₹{recommended} and ₹{floor}."
                    )
                    polished = await client.generate_text(prompt=prompt)
                    if polished and str(recommended) in polished:
                        base_dict[app_lang] = polished.strip()
            except Exception as e:
                logger.warning(f"Gemini pricing explanation failed: {e}")

        return base_dict
