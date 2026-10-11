from typing import Any, Dict, List, Optional
from app.providers.interfaces import (
    ImageEnhancer,
    SpeechToText,
    Translator,
    DescriptionGenerator,
    PriceEstimator,
    MarketData,
    ImageEditor,
)

class MockImageEnhancer(ImageEnhancer):
    async def enhance_image(
        self,
        image_bytes: bytes,
        style: str = "white",
        mime_type: str = "image/jpeg"
    ) -> Dict[str, Any]:
        return {
            "status": "done",
            "quality_score": 85,
            "original_url": "/static/uploads/mock_original.jpg",
            "enhanced_url": "/static/uploads/mock_enhanced.jpg",
            "variants": {
                "square": "/static/uploads/mock_square.webp",
                "portrait": "/static/uploads/mock_portrait.webp",
                "thumb": "/static/uploads/mock_thumb.webp",
            },
            "tips": ["Good natural lighting", "Crisp subject isolation"],
            "tags": {
                "category": "pottery",
                "materials": ["terracotta"],
                "colors": ["terracotta", "earth brown"],
                "technique": "wheel thrown",
            },
        }

class MockSpeechToText(SpeechToText):
    async def transcribe(
        self,
        audio_bytes: bytes,
        mime_type: str = "audio/wav",
        language_hint: Optional[str] = None
    ) -> Dict[str, Any]:
        detected = language_hint or "hi"
        sample_texts = {
            "hi": "यह हस्तनिर्मित मिट्टी का घड़ा है। प्राकृतिक लाल मिट्टी से बनाया गया है।",
            "ta": "இது கையால் செய்யப்பட்ட மண்பானை. இயற்கையான களிமண்ணால் செய்யப்பட்டது.",
            "te": "ఇది చేతితో తయారు చేసిన మట్టి కుండ. సహజసిద్ధమైన ఎర్ర మట్టితో చేయబడింది.",
            "kn": "ಇದು ಕೈಯಿಂದ ಮಾಡಿದ ಮಣ್ಣಿನ ಮಡಕೆ. ನೈಸರ್ಗಿಕ ಕೆಂಪು ಮಣ್ಣಿನಿಂದ ಮಾಡಲ್ಪಟ್ಟಿದೆ.",
            "ml": "ഇത് കൈകൊണ്ട് നിർമ്മിച്ച മൺപാത്രമാണ്. പ്രകൃതിദത്തമായ ചുവന്ന മണ്ണിൽ നിന്നാണ് നിർമ്മിച്ചിരിക്കുന്നത്.",
            "en": "This is a handmade clay pot crafted from natural red terracotta.",
        }
        return {
            "text": sample_texts.get(detected, sample_texts["hi"]),
            "detected_lang": detected,
            "clarity": "high",
            "confidence": 0.94,
        }

class MockTranslator(Translator):
    async def translate(
        self,
        text: str,
        source_lang: str,
        target_langs: List[str]
    ) -> Dict[str, str]:
        results = {}
        for target in target_langs:
            if target == source_lang:
                results[target] = text
            else:
                results[target] = f"[{target.upper()}] {text}"
        return results

class MockDescriptionGenerator(DescriptionGenerator):
    async def generate_catalog(
        self,
        transcript: str,
        source_lang: str,
        image_tags: Optional[Dict[str, Any]] = None,
        category: Optional[str] = None,
        price: Optional[int] = None
    ) -> Dict[str, Any]:
        base_listing = {
            "title": "Terracotta Earthen Water Pitcher",
            "short_description": "Handcrafted terracotta water pot with natural cooling properties.",
            "long_description": "Crafted with locally sourced clay and fired traditionally to preserve porosity, keeping water naturally cool and fresh.",
            "bullet_points": [
                "100% natural organic clay",
                "Traditional wheel-thrown pottery",
                "Natural cooling without electricity"
            ],
            "materials": ["Terracotta clay"],
            "care_instructions": "Rinse with plain water before first use. Do not use chemical detergents.",
            "seo_title": "Handmade Terracotta Water Pot",
            "meta_description": "Authentic Indian terracotta water pitcher handcrafted by village artisans.",
            "keywords": ["pottery", "terracotta", "handmade", "earthenware", "eco friendly"],
            "hashtags": ["#IndianCrafts", "#Terracotta", "#ArtisanMade"]
        }

        translations = {}
        for lang in ["en", "hi", "ta", "te", "kn", "ml"]:
            translations[lang] = base_listing.copy()

        return {
            "source_lang": source_lang,
            "master": base_listing,
            "original_transcript": transcript,
            "translations": translations,
        }

    async def refine_catalog(
        self,
        current_listing: Dict[str, Any],
        instruction: str,
        source_lang: str = "en",
        category: Optional[str] = None,
        image_tags: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        master = current_listing.get("master", current_listing.get("source", {}))
        updated_master = dict(master)
        if "short" in instruction.lower():
            updated_master["short_description"] = "Authentic handcrafted craft item."
        elif "family" in instruction.lower():
            updated_master["long_description"] = f"{updated_master.get('long_description', '')} Handcrafted with care by our artisan family."

        translations = {}
        for lang in ["en", "hi", "ta", "te", "kn", "ml"]:
            translations[lang] = dict(updated_master)

        return {
            "source_lang": source_lang,
            "master": updated_master,
            "translations": translations,
            "instruction_applied": instruction,
        }

class MockPriceEstimator(PriceEstimator):
    async def suggest_price(
        self,
        material_cost: float,
        labour_hours: float,
        category: str,
        materials: List[str],
        region: Optional[str] = None,
        user_expected_price: Optional[float] = None,
        other_cost: float = 0.0,
    ) -> Dict[str, Any]:
        fair_wage_rate = 80.0
        other = max(0.0, float(other_cost))
        overhead = (material_cost + (labour_hours * fair_wage_rate) + other) * 0.10
        floor = int(material_cost + (labour_hours * fair_wage_rate) + other + overhead)
        recommended = int(floor * 1.35)
        budget = int(floor * 1.15)
        premium = int(floor * 1.65)

        has_comps = category.lower() != "extraterrestrial-crystal-art"
        warning = None
        if user_expected_price is not None and user_expected_price < floor:
            warning = f"Your expected price of ₹{int(user_expected_price)} is below your cost floor of ₹{floor}. Selling below your cost floor will result in a loss on raw materials and fair wages."

        confidence = 0.85 if has_comps else 0.50

        factors = [
            {"name": "Material cost", "value": f"₹{int(material_cost)}"},
            {"name": f"Labour ({labour_hours}h @ ₹{int(fair_wage_rate)}/h)", "value": f"₹{int(labour_hours * fair_wage_rate)}"},
        ]
        if other > 0:
            factors.append({"name": "Other product costs", "value": f"₹{int(other)}"})
        factors.extend([
            {"name": "Overhead (10%)", "value": f"₹{int(overhead)}"},
            {"name": "Artisan Margin", "value": f"₹{recommended - floor}"},
        ])

        return {
            "floor": floor,
            "budget": budget,
            "recommended": recommended,
            "premium": premium,
            "confidence": confidence,
            "label": "Market benchmarked" if has_comps else "Estimate based on your costs only",
            "has_comparables": has_comps,
            "warning": warning,
            "factors": factors,
            "comparables": [
                {"title": "Pachmura Earthen Pitcher", "price": recommended + 30, "similarity": 0.88},
                {"title": "Traditional Surahi Clay Pot", "price": recommended - 25, "similarity": 0.82},
            ] if has_comps else [],
            "explanation": {
                "en": (
                    f"Recommended fair price of ₹{recommended} based on {labour_hours} hours of artisan labour and ₹{int(material_cost)} raw material cost."
                    if has_comps else
                    f"Estimate based on your costs only: ₹{recommended} based on {labour_hours} hours of artisan labour and ₹{int(material_cost)} raw material cost."
                ),
                "hi": f"अनुशंसित मूल्य ₹{recommended} - {labour_hours} घंटे के श्रम और ₹{int(material_cost)} सामग्री लागत के आधार पर।",
                "ta": f"பரிந்துரைக்கப்பட்ட நியாயமான விலை ₹{recommended} - {labour_hours} மணிநேர உழைப்பு மற்றும் ₹{int(material_cost)} மூலப்பொருள் செலவின் அடிப்படையில்.",
                "te": f"సిఫార్సు చేయబడిన సరసమైన ధర ₹{recommended} - {labour_hours} గంటల శ్రమ మరియు ₹{int(material_cost)} ముడి పదార్థాల ఖర్చు ఆధారంగా.",
                "kn": f"ಶಿಫಾರಸು ಮಾಡಿದ ನ್ಯಾಯಯುತ ಬೆಲೆ ₹{recommended} - {labour_hours} ಗಂಟೆಗಳ ಶ್ರಮ ಮತ್ತು ₹{int(material_cost)} ಕಚ್ಚಾ ವಸ್ತುಗಳ ವೆಚ್ಚದ ಆಧಾರದ ಮೇಲೆ.",
                "ml": f"ശുപാർശ ചെയ്ത ന്യായമായ വില ₹{recommended} - {labour_hours} മണിക്കൂർ അധ്വാനവും ₹{int(material_cost)} മെറ്റീരിയൽ ചെലവും അടിസ്ഥാനമാക്കി.",
            },
        }

class MockMarketData(MarketData):
    async def get_comparables(
        self,
        category: str,
        materials: List[str],
        region: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        return [
            {"title": "Handcrafted Terracotta Urn", "price": 480, "similarity": 0.89},
            {"title": "Earthen Water Jug", "price": 420, "similarity": 0.84},
            {"title": "Traditional Clay Vase", "price": 450, "similarity": 0.81},
        ]

class MockImageEditor(ImageEditor):
    async def edit_image(
        self,
        image_id: str,
        operations: Optional[List[Dict[str, Any]]] = None,
        prompt: Optional[str] = None,
        action: Optional[str] = None,
        lang: str = "en",
        storage_dir: Optional[str] = None,
    ) -> Dict[str, Any]:
        from app.services.image_editor import execute_edit_action_async
        from app.providers.image_editor_provider import parse_rule_based_voice_command

        effective_ops = operations
        effective_act = action
        if prompt and not effective_ops and not effective_act:
            parsed = parse_rule_based_voice_command(prompt, lang=lang)
            effective_ops = parsed.get("operations")
            effective_act = parsed.get("action") or "apply"

        return await execute_edit_action_async(
            image_id=image_id,
            operations=effective_ops,
            action=effective_act,
            storage_dir=storage_dir,
        )

    async def process_voice_command(
        self,
        image_id: str,
        text: Optional[str] = None,
        audio_bytes: Optional[bytes] = None,
        audio_mime_type: str = "audio/wav",
        lang: str = "en",
        storage_dir: Optional[str] = None,
    ) -> Dict[str, Any]:
        from app.providers.image_editor_provider import parse_rule_based_voice_command
        cmd_text = (text or "").strip()
        if not cmd_text:
            if lang == "hi":
                cmd_text = "background neela karo"
            elif lang == "ta":
                cmd_text = "konjam brightaa"
            elif lang == "te":
                cmd_text = "shadow theeseyyi"
            else:
                cmd_text = "make it brighter"

        parsed = parse_rule_based_voice_command(cmd_text, lang=lang)
        if parsed.get("is_free_form_ai"):
            polite_replies = {
                "hi": "क्षमा करें, जनरेटिव एआई संपादन वर्तमान में उपलब्ध नहीं है। आप पृष्ठभूमि, रोशनी, छाया या आकार बदल सकते हैं।",
                "ta": "மன்னிக்கவும், AI ஜெனரேட்டிவ் எடிட்டிங் தற்போது கிடைக்கவில்லை. நீங்கள் பின்னணி, வெளிச்சம் அல்லது நிழலை மாற்றலாம்.",
                "te": "క్షమించండి, AI జెనరేటివ్ ఎడిటింగ్ ప్రస్తుతం అందుబాటులో లేదు. మీరు బ్యాక్‌గ్రౌండ్, వెలుతురు లేదా నీడను మార్చవచ్చు.",
                "kn": "ಕ್ಷಮಿಸಿ, AI ಜನರೇಟಿವ್ ಎಡಿಟಿಂಗ್ ಪ್ರಸ್ತುತ ಲಭ್ಯವಿಲ್ಲ. ನೀವು ಹಿನ್ನೆಲೆ, ಬೆಳಕು ಅಥವಾ ನೆರಳು ಬದಲಾಯಿಸಬಹುದು.",
                "ml": "ക്ഷമിക്കണം, AI ജനറേറ്റീവ് എഡിറ്റിംഗ് നിലവിൽ ലഭ്യമല്ല. നിങ്ങൾക്ക് പശ്ചാത്തലം, വെളിച്ചം അല്ലെങ്കിൽ നിഴൽ മാറ്റാം.",
                "en": "Generative AI editing is currently not available. You can adjust the background, brightness, contrast, shadow, or size.",
            }
            return {
                "status": "unavailable",
                "transcript": cmd_text,
                "operations": [],
                "confirmation": polite_replies.get(lang, polite_replies["en"]),
                "clarification_needed": False,
                "ai_edit_available": False,
            }

        if parsed.get("clarification_needed"):
            return {
                "status": "clarification_needed",
                "transcript": cmd_text,
                "operations": [],
                "confirmation": parsed.get("clarifying_question"),
                "clarification_needed": True,
                "clarifying_question": parsed.get("clarifying_question"),
            }

        act = parsed.get("action", "apply")
        new_ops = parsed.get("operations", [])
        edit_res = await self.edit_image(
            image_id=image_id,
            operations=new_ops if act == "apply" else None,
            action=act if act != "apply" else None,
            storage_dir=storage_dir,
        )

        return {
            "status": "success",
            "transcript": cmd_text,
            "operations": edit_res["operations"],
            "new_operations": new_ops,
            "action": act,
            "confirmation": parsed.get("confirmation", "Changes applied."),
            "clarification_needed": False,
            "image_id": image_id,
            "image_url": edit_res["image_url"],
            "original_url": edit_res["original_url"],
            "can_undo": edit_res["can_undo"],
            "can_redo": edit_res["can_redo"],
        }

