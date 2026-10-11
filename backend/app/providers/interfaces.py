from abc import ABC, abstractmethod
from typing import Any, Dict, List, Optional

class ImageEnhancer(ABC):
    @abstractmethod
    async def enhance_image(
        self,
        image_bytes: bytes,
        style: str = "white",
        mime_type: str = "image/jpeg"
    ) -> Dict[str, Any]:
        """Enhances image and returns variants, quality_score, and visual tags."""
        pass

class SpeechToText(ABC):
    @abstractmethod
    async def transcribe(
        self,
        audio_bytes: bytes,
        mime_type: str = "audio/wav",
        language_hint: Optional[str] = None
    ) -> Dict[str, Any]:
        """Transcribes spoken audio into text with detected language and confidence."""
        pass

class Translator(ABC):
    @abstractmethod
    async def translate(
        self,
        text: str,
        source_lang: str,
        target_langs: List[str]
    ) -> Dict[str, str]:
        """Translates text from source language into target languages."""
        pass

class DescriptionGenerator(ABC):
    @abstractmethod
    async def generate_catalog(
        self,
        transcript: str,
        source_lang: str,
        image_tags: Optional[Dict[str, Any]] = None,
        category: Optional[str] = None,
        price: Optional[int] = None
    ) -> Dict[str, Any]:
        """Generates multilingual listing in 6 languages following strict listing schema."""
        pass

    @abstractmethod
    async def refine_catalog(
        self,
        current_listing: Dict[str, Any],
        instruction: str,
        source_lang: str = "en",
        category: Optional[str] = None,
        image_tags: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """Refines existing listing according to artisan voice/text instruction."""
        pass


class PriceEstimator(ABC):
    @abstractmethod
    async def suggest_price(
        self,
        material_cost: float,
        labour_hours: float,
        category: str,
        materials: List[str],
        region: Optional[str] = None,
        user_expected_price: Optional[float] = None
    ) -> Dict[str, Any]:
        """Calculates fair price, cost floor, ranges, and explanations."""
        pass

class MarketData(ABC):
    @abstractmethod
    async def get_comparables(
        self,
        category: str,
        materials: List[str],
        region: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """Retrieves comparable craft products for market pricing baseline."""
        pass

class ImageEditor(ABC):
    @abstractmethod
    async def edit_image(
        self,
        image_id: str,
        operations: Optional[List[Dict[str, Any]]] = None,
        prompt: Optional[str] = None,
        action: Optional[str] = None,
        lang: str = "en",
        storage_dir: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Applies non-destructive operations to original cutout/image and maintains undo/redo history."""
        pass

    @abstractmethod
    async def process_voice_command(
        self,
        image_id: str,
        text: Optional[str] = None,
        audio_bytes: Optional[bytes] = None,
        audio_mime_type: str = "audio/wav",
        lang: str = "en",
        storage_dir: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Transcribes command, extracts operations via Gemini, and applies them."""
        pass

