import logging
from typing import Any, Dict, Optional

from app.config import get_settings
from app.providers.interfaces import ImageEnhancer
from app.providers.gemini_provider import GeminiVisionTagger
from app.services.image_enhancer import enhance_image_async

logger = logging.getLogger("kalasetu.rembg_provider")

class RealImageEnhancer(ImageEnhancer):
    """Production ImageEnhancer using local OpenCV + rembg (U2-Net) off-thread,
    plus optional Gemini Vision tagging and optional AI polish model.
    """

    def __init__(self, vision_tagger: Optional[GeminiVisionTagger] = None):
        self.vision_tagger = vision_tagger or GeminiVisionTagger()

    async def enhance_image(
        self,
        image_bytes: bytes,
        style: str = "white",
        mime_type: str = "image/jpeg"
    ) -> Dict[str, Any]:
        settings = get_settings()
        # 1. Local CPU-bound processing off main thread
        result = await enhance_image_async(
            image_bytes=image_bytes,
            style=style
        )

        # 2. Optional Gemini Vision Visual Tagging
        tags: Dict[str, Any] = {
            "category": "handmade_craft",
            "materials": [],
            "colors": [],
            "technique": None,
        }

        if settings.AI_MODE == "real" and settings.GEMINI_API_KEY:
            try:
                vision_tags = await self.vision_tagger.tag_image(
                    image_bytes=image_bytes,
                    mime_type=mime_type,
                )
                if isinstance(vision_tags, dict):
                    tags.update(vision_tags)
            except Exception as e:
                logger.warning(f"Optional vision tagging skipped: {e}")

        result["tags"] = tags
        return result
