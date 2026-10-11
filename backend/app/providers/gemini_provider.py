import json
from typing import Any, Dict, List, Optional
from app.providers.gemini_client import GeminiClient
from app.providers.interfaces import (
    SpeechToText,
    Translator,
    DescriptionGenerator,
)

class GeminiSpeechToText(SpeechToText):
    def __init__(self, client: Optional[GeminiClient] = None):
        self.client = client or GeminiClient()

    async def transcribe(
        self,
        audio_bytes: bytes,
        mime_type: str = "audio/wav",
        language_hint: Optional[str] = None
    ) -> Dict[str, Any]:
        prompt = (
            "Transcribe this speech exactly as spoken, in its original language and native script. "
            "The speaker may use English, Telugu (తెలుగు), Tamil (தமிழ்), Kannada (ಕನ್ನಡ), Malayalam (മലയാളം), or Hindi (हिन्दी), "
            "or mix regional languages with English (code-switching). "
            "Preserve regional terms, craft names, materials, and product details accurately. "
            "Do NOT translate into English. Keep the original script (Telugu script for Telugu, Tamil for Tamil, Devanagari for Hindi, etc.). "
            "If the audio contains silence, static, or no intelligible speech, return text as empty string \"\". "
            "Return JSON: {\"text\": \"<exact transcription or empty string>\", \"detected_lang\": \"en\"|\"hi\"|\"ta\"|\"te\"|\"kn\"|\"ml\", \"clarity\": \"high\"|\"medium\"|\"low\"}."
        )
        if language_hint:
            prompt += f"\nLanguage hint (app interface language, use as hint only, not a restriction): {language_hint}."

        result = await self.client.generate_json(
            prompt=prompt,
            audio_bytes=audio_bytes,
            audio_mime_type=mime_type,
            temperature=0.1,
        )
        if not isinstance(result, dict):
            result = {}

        detected_lang = str(result.get("detected_lang", language_hint or "en")).lower().strip()
        if detected_lang not in ["en", "hi", "ta", "te", "kn", "ml"]:
            detected_lang = language_hint or "en"
            if detected_lang not in ["en", "hi", "ta", "te", "kn", "ml"]:
                detected_lang = "en"

        clarity = str(result.get("clarity", "high")).lower().strip()
        if clarity not in ["high", "medium", "low"]:
            clarity = "medium"

        return {
            "text": str(result.get("text", "")).strip(),
            "detected_lang": detected_lang,
            "clarity": clarity,
        }

class GeminiTranslator(Translator):
    def __init__(self, client: Optional[GeminiClient] = None):
        self.client = client or GeminiClient()

    async def translate(
        self,
        text: str,
        source_lang: str,
        target_langs: List[str]
    ) -> Dict[str, str]:
        prompt = (
            f"You are a professional translator for Indian craft products. "
            f"Translate the following text from {source_lang} into target languages: {target_langs}. "
            f"Write each in its natural, native script (not romanized). "
            f"Return JSON mapping target_lang code to translated string, e.g. {{'hi': '...', 'ta': '...'}}.\n\n"
            f"Original text: \"{text}\""
        )
        result = await self.client.generate_json(prompt=prompt, temperature=0.3)
        return {lang: str(result.get(lang, "")) for lang in target_langs}

class GeminiDescriptionGenerator(DescriptionGenerator):
    def __init__(self, client: Optional[GeminiClient] = None):
        self.client = client or GeminiClient()

    async def generate_catalog(
        self,
        transcript: str,
        source_lang: str,
        image_tags: Optional[Dict[str, Any]] = None,
        category: Optional[str] = None,
        price: Optional[int] = None
    ) -> Dict[str, Any]:
        prompt = (
            "You are an expert product copywriter for Indian handmade crafts.\n"
            f"INPUT:\n"
            f"- Artisan's spoken transcript: \"{transcript}\" (Spoken language: {source_lang})\n"
            f"- Craft Category: {category or 'Handmade Craft'}\n"
            f"- Image Tags: {json.dumps(image_tags or {})}\n"
            f"- Target Price: {price or 'N/A'}\n\n"
            "TASK:\n"
            "1. Write an English master listing as JSON.\n"
            "2. Translate this complete listing into the 5 other Indian languages in their authentic native scripts: "
            "Hindi (hi), Tamil (ta), Telugu (te), Kannada (kn), and Malayalam (ml).\n\n"
            "Schema for each listing:\n"
            "{\n"
            "  \"title\": \"concise product title\",\n"
            "  \"short_description\": \"1-2 sentences summary\",\n"
            "  \"long_description\": \"Detailed paragraph describing the craftsmanship and heritage\",\n"
            "  \"bullet_points\": [\"key feature 1\", \"key feature 2\", \"key feature 3\"],\n"
            "  \"materials\": [\"list of materials\"],\n"
            "  \"care_instructions\": \"practical care advice\",\n"
            "  \"seo_title\": \"SEO title under 60 characters\",\n"
            "  \"meta_description\": \"Meta description under 155 characters\",\n"
            "  \"keywords\": [\"keyword1\", \"keyword2\", \"keyword3\"],\n"
            "  \"hashtags\": [\"#Hashtag1\", \"#Hashtag2\"]\n"
            "}\n\n"
            "Strict Rules:\n"
            "- Never invent facts not mentioned in transcript or visual tags. If uncertain, omit.\n"
            "- Preserve traditional craft names (e.g., Kalamkari, Pochampally, Channapatna, Bidri) and geographical place names exactly as is.\n"
            "- Never claim certifications, awards, or GI status unless specifically stated in transcript.\n"
            "- 'seo_title' MUST NOT exceed 60 characters.\n"
            "- Return JSON with top-level keys:\n"
            "  {\n"
            "    \"master\": <English listing object>,\n"
            "    \"translations\": {\n"
            "       \"en\": <English listing object>,\n"
            "       \"hi\": <Hindi listing object in Devanagari script>,\n"
            "       \"ta\": <Tamil listing object in Tamil script>,\n"
            "       \"te\": <Telugu listing object in Telugu script>,\n"
            "       \"kn\": <Kannada listing object in Kannada script>,\n"
            "       \"ml\": <Malayalam listing object in Malayalam script>\n"
            "    }\n"
            "  }"
        )

        def _clean_listing(item: Dict[str, Any]) -> Dict[str, Any]:
            if not isinstance(item, dict):
                item = {}
            seo = str(item.get("seo_title", "")).strip()
            if len(seo) > 60:
                seo = seo[:60].strip()
            meta = str(item.get("meta_description", "")).strip()
            if len(meta) > 155:
                meta = meta[:155].strip()
            return {
                "title": str(item.get("title", "")).strip(),
                "short_description": str(item.get("short_description", "")).strip(),
                "long_description": str(item.get("long_description", "")).strip(),
                "bullet_points": [str(x) for x in item.get("bullet_points", []) if x],
                "materials": [str(x) for x in item.get("materials", []) if x],
                "care_instructions": str(item.get("care_instructions", "")).strip(),
                "seo_title": seo,
                "meta_description": meta,
                "keywords": [str(x) for x in item.get("keywords", []) if x],
                "hashtags": [str(x) for x in item.get("hashtags", []) if x],
            }

        # Attempt call with retry once on invalid JSON
        result = None
        for attempt in range(2):
            try:
                result = await self.client.generate_json(prompt=prompt, temperature=0.3)
                if isinstance(result, dict) and "master" in result:
                    break
            except Exception as e:
                if attempt == 1:
                    raise e
                # Retry with simpler prompt hint
                prompt += "\n\nNote: Ensure strict valid JSON output."

        if not isinstance(result, dict):
            result = {}

        master = _clean_listing(result.get("master", {}))
        translations_raw = result.get("translations", {})
        if not isinstance(translations_raw, dict):
            translations_raw = {}

        all_langs = ["en", "hi", "ta", "te", "kn", "ml"]
        translations = {}
        translations["en"] = master

        for lang in all_langs:
            if lang in translations_raw and isinstance(translations_raw[lang], dict):
                translations[lang] = _clean_listing(translations_raw[lang])
            elif lang not in translations:
                translations[lang] = master

        original_version = translations.get(source_lang, master)

        return {
            "source_lang": source_lang,
            "master": master,
            "original_transcript": transcript,
            "original": original_version,
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
        """
        Re-runs Gemini to update listing based on artisan's spoken or typed changes
        (e.g., 'make it shorter', 'add that my family made it by hand', 'mention terracotta clay').
        Preserves original facts and keeps all 6 languages synchronized.
        """
        master_prev = current_listing.get("master", current_listing)
        prompt = (
            "You are an expert product copywriter for Indian handmade crafts.\n"
            "An artisan wants to revise their craft catalog listing with this feedback:\n"
            f"REVISION FEEDBACK: \"{instruction}\" (Language: {source_lang})\n"
            f"Category: {category or 'Handmade Craft'}\n"
            f"CURRENT MASTER LISTING: {json.dumps(master_prev)}\n\n"
            "TASK:\n"
            "1. Revise the English master listing following the artisan's feedback.\n"
            "2. Translate into Hindi (hi), Tamil (ta), Telugu (te), Kannada (kn), and Malayalam (ml).\n\n"
            "Strict Rules:\n"
            "- Never invent facts (materials, age, awards, GI/authenticity claims) not in the current listing or instruction.\n"
            "- Keep traditional craft names and place names exact.\n"
            "- 'seo_title' MUST NOT exceed 60 characters. 'meta_description' under 155 characters.\n"
            "Return JSON:\n"
            "{\n"
            "  \"master\": {\"title\": \"...\", \"short_description\": \"...\", \"long_description\": \"...\", \"bullet_points\": [...], \"materials\": [...], \"care_instructions\": \"...\", \"seo_title\": \"...\", \"meta_description\": \"...\", \"keywords\": [...], \"hashtags\": [...]},\n"
            "  \"translations\": {\"en\": ..., \"hi\": ..., \"ta\": ..., \"te\": ..., \"kn\": ..., \"ml\": ...}\n"
            "}"
        )

        def _clean_item(item: Dict[str, Any]) -> Dict[str, Any]:
            if not isinstance(item, dict):
                item = {}
            seo = str(item.get("seo_title", "")).strip()
            if len(seo) > 60:
                seo = seo[:60].strip()
            meta = str(item.get("meta_description", "")).strip()
            if len(meta) > 155:
                meta = meta[:155].strip()
            return {
                "title": str(item.get("title", "")).strip(),
                "short_description": str(item.get("short_description", "")).strip(),
                "long_description": str(item.get("long_description", "")).strip(),
                "bullet_points": [str(x) for x in item.get("bullet_points", []) if x],
                "materials": [str(x) for x in item.get("materials", []) if x],
                "care_instructions": str(item.get("care_instructions", "")).strip(),
                "seo_title": seo,
                "meta_description": meta,
                "keywords": [str(x) for x in item.get("keywords", []) if x],
                "hashtags": [str(x) for x in item.get("hashtags", []) if x],
            }

        try:
            result = await self.client.generate_json(prompt=prompt, temperature=0.3)
        except Exception:
            result = {}

        if not isinstance(result, dict) or "master" not in result:
            # Fallback minor adjustment
            updated_master = dict(master_prev)
            if "short" in instruction.lower():
                updated_master["short_description"] = master_prev.get("short_description", "")[:120]
            result = {"master": updated_master, "translations": {}}

        master = _clean_item(result.get("master", {}))
        translations_raw = result.get("translations", {})
        if not isinstance(translations_raw, dict):
            translations_raw = {}

        all_langs = ["en", "hi", "ta", "te", "kn", "ml"]
        translations = {}
        translations["en"] = master

        for lang in all_langs:
            if lang in translations_raw and isinstance(translations_raw[lang], dict):
                translations[lang] = _clean_item(translations_raw[lang])
            elif lang not in translations:
                translations[lang] = master

        original_version = translations.get(source_lang, master)

        return {
            "source_lang": source_lang,
            "master": master,
            "original": original_version,
            "translations": translations,
            "instruction_applied": instruction,
        }

class GeminiVisionTagger:
    def __init__(self, client: Optional[GeminiClient] = None):
        self.client = client or GeminiClient()

    async def tag_image(
        self,
        image_bytes: bytes,
        mime_type: str = "image/jpeg"
    ) -> Dict[str, Any]:
        prompt = (
            "Look at this product photo. Return JSON only:\n"
            "{\"category\": one of [pottery, handloom, jewelry, wood_craft, bamboo, other],\n"
            " \"materials\": [..], \"colors\": [..], \"technique\": \"...\" or null, \"confidence\": 0-1}\n"
            "Only state what is visible. Use null when unsure."
        )
        return await self.client.generate_json(
            prompt=prompt,
            image_bytes=image_bytes,
            image_mime_type=mime_type,
            temperature=0.2,
        )

class GeminiAttributeExtractor:
    """Extracts structured craft attributes: category, material, size, craft complexity, finish quality, uniqueness."""
    def __init__(self, client: Optional[GeminiClient] = None):
        self.client = client or GeminiClient()

    async def extract_attributes(
        self,
        image_bytes: Optional[bytes] = None,
        image_mime_type: Optional[str] = None,
        listing_text: Optional[str] = None,
        category_hint: Optional[str] = None,
    ) -> Dict[str, Any]:
        prompt = (
            "You are an expert appraiser of handcrafted Indian artisanal goods.\n"
            f"Listing text: \"{listing_text or ''}\"\n"
            f"Category hint: \"{category_hint or ''}\"\n"
            "Analyze the item and extract structured attributes as JSON:\n"
            "{\n"
            "  \"category\": \"one of [pottery, handloom, jewelry, wood craft, bamboo, other]\",\n"
            "  \"material\": \"primary authentic material (e.g. terracotta, silk, cotton, brass, rosewood, cane)\",\n"
            "  \"size\": \"approximate dimension (e.g. '25cm' or '30x20cm' or 'medium')\",\n"
            "  \"craft_complexity\": \"simple | moderate | intricate | masterpiece\",\n"
            "  \"finish_quality\": \"raw | smooth | glazed | polished | refined\",\n"
            "  \"uniqueness\": \"standard | regional | heirloom | one-of-a-kind\"\n"
            "}\n"
            "Strict Rules: Never invent fake authenticity claims. Base only on observable details."
        )
        try:
            result = await self.client.generate_json(
                prompt=prompt,
                image_bytes=image_bytes,
                image_mime_type=image_mime_type or "image/jpeg",
                temperature=0.1,
            )
            if isinstance(result, dict) and "category" in result:
                return {
                    "category": str(result.get("category", category_hint or "pottery")).lower().strip(),
                    "material": str(result.get("material", "natural material")).lower().strip(),
                    "size": str(result.get("size", "25cm")).strip(),
                    "craft_complexity": str(result.get("craft_complexity", "moderate")).lower().strip(),
                    "finish_quality": str(result.get("finish_quality", "smooth")).lower().strip(),
                    "uniqueness": str(result.get("uniqueness", "regional")).lower().strip(),
                }
        except Exception:
            pass

        return {
            "category": (category_hint or "pottery").lower().strip(),
            "material": "terracotta",
            "size": "25cm",
            "craft_complexity": "moderate",
            "finish_quality": "smooth",
            "uniqueness": "regional",
        }

_GLOBAL_GEMINI_CLIENT: Optional[GeminiClient] = None

def get_gemini_client() -> GeminiClient:
    global _GLOBAL_GEMINI_CLIENT
    if _GLOBAL_GEMINI_CLIENT is None:
        _GLOBAL_GEMINI_CLIENT = GeminiClient()
    return _GLOBAL_GEMINI_CLIENT

def get_gemini_gateway() -> GeminiClient:
    return get_gemini_client()

