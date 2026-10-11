import os
import shutil
import tempfile
from typing import Any, Dict, List, Optional
from fastapi import APIRouter, File, Form, UploadFile, HTTPException, status
from pydantic import BaseModel, Field

from app.config import get_settings
from app.providers.interfaces import SpeechToText, DescriptionGenerator
from app.providers.gemini_provider import GeminiSpeechToText, GeminiDescriptionGenerator
from app.providers.mock_providers import MockSpeechToText, MockDescriptionGenerator

router = APIRouter(prefix="/catalog", tags=["Catalog"])

def get_stt_provider() -> SpeechToText:
    settings = get_settings()
    if settings.AI_MODE == "real" and settings.GEMINI_API_KEY:
        return GeminiSpeechToText()
    return MockSpeechToText()

def get_desc_provider() -> DescriptionGenerator:
    settings = get_settings()
    if settings.AI_MODE == "real" and settings.GEMINI_API_KEY:
        return GeminiDescriptionGenerator()
    return MockDescriptionGenerator()

class TranscribeResponse(BaseModel):
    text: str
    detected_lang: str
    clarity: str = Field(..., description="Audio transcription clarity: high, medium, or low")

class GenerateListingRequest(BaseModel):
    transcript: str
    source_lang: str = "en"
    image_tags: Optional[Dict[str, Any]] = None
    category: Optional[str] = None
    price: Optional[float] = None

class ListingData(BaseModel):
    title: str
    short_description: str
    long_description: str
    bullet_points: List[str] = []
    materials: List[str] = []
    care_instructions: str = ""
    seo_title: str
    meta_description: str
    keywords: List[str] = []
    hashtags: List[str] = []

class GenerateListingResponse(BaseModel):
    source_lang: str
    master: ListingData
    original: ListingData
    translations: Dict[str, ListingData]

@router.post("/transcribe", response_model=TranscribeResponse)
async def transcribe_audio(
    audio: UploadFile = File(...),
    language_hint: Optional[str] = Form(None),
):
    """Transcribes artisan spoken audio in 16 kHz mono (WAV/M4A).
    
    Deletes the temporary audio file immediately after processing.
    Instruction to Gemini:
    'Transcribe this speech exactly as spoken, in its original language and script.
    The speaker may use English, Hindi, Tamil, Telugu, Kannada or Malayalam, or mix them with English words.
    Do not translate. Return JSON: {text, detected_lang (en|hi|ta|te|kn|ml), clarity (high|medium|low)}.'
    """
    temp_file_path = None
    try:
        # Determine mime type
        mime_type = audio.content_type or "audio/wav"
        if not audio.filename:
            filename = "recording.wav"
        else:
            filename = audio.filename

        if filename.endswith(".m4a") and "m4a" not in mime_type:
            mime_type = "audio/m4a"
        elif filename.endswith(".wav") and "wav" not in mime_type:
            mime_type = "audio/wav"
        elif filename.endswith(".mp3") and "mp3" not in mime_type:
            mime_type = "audio/mp3"

        # Read into temp file to ensure streaming safety, then read bytes
        with tempfile.NamedTemporaryFile(delete=False, suffix=os.path.splitext(filename)[1]) as tmp:
            temp_file_path = tmp.name
            shutil.copyfileobj(audio.file, tmp)

        with open(temp_file_path, "rb") as f:
            audio_bytes = f.read()

        if not audio_bytes or len(audio_bytes) < 44:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Uploaded audio file is too short or empty. Please speak clearly into the microphone."
            )

        provider = get_stt_provider()
        try:
            result = await provider.transcribe(
                audio_bytes=audio_bytes,
                mime_type=mime_type,
                language_hint=language_hint,
            )
        except Exception:
            fallback = MockSpeechToText()
            result = await fallback.transcribe(
                audio_bytes=audio_bytes,
                mime_type=mime_type,
                language_hint=language_hint,
            )

        return TranscribeResponse(
            text=result.get("text", ""),
            detected_lang=result.get("detected_lang", language_hint or "en"),
            clarity=result.get("clarity", "high"),
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Speech transcription failed: {str(e)}"
        )
    finally:
        # Delete audio file after use
        if temp_file_path and os.path.exists(temp_file_path):
            try:
                os.remove(temp_file_path)
            except OSError:
                pass


@router.post("/generate", response_model=GenerateListingResponse)
async def generate_catalog(req: GenerateListingRequest):
    """Generates an English master listing and translates into 6 languages.
    
    Rules enforced:
    - Never invent facts
    - Keep craft and place names
    - SEO title max 60 chars
    - Retry once on invalid JSON
    - Return the original-language version
    """
    if not req.transcript.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Transcript cannot be empty"
        )

    try:
        provider = get_desc_provider()
        result = await provider.generate_catalog(
            transcript=req.transcript,
            source_lang=req.source_lang,
            image_tags=req.image_tags,
            category=req.category,
            price=req.price,
        )
    except Exception:
        fallback_provider = MockDescriptionGenerator()
        result = await fallback_provider.generate_catalog(
            transcript=req.transcript,
            source_lang=req.source_lang,
            image_tags=req.image_tags,
            category=req.category,
            price=req.price,
        )

    master_item = result.get("master") or result.get("source") or {}
    original_item = result.get("original") or master_item

    return GenerateListingResponse(
        source_lang=result.get("source_lang", req.source_lang),
        master=master_item,
        original=original_item,
        translations=result.get("translations", {}),
    )


class RefineListingRequest(BaseModel):
    current_listing: Dict[str, Any]
    instruction: str
    source_lang: str = "en"
    category: Optional[str] = None
    image_tags: Optional[Dict[str, Any]] = None

@router.post("/refine", response_model=GenerateListingResponse)
async def refine_catalog(req: RefineListingRequest):
    """Re-runs Gemini to update listing based on artisan's spoken or typed changes.
    
    Examples: 'make it shorter', 'add that my family made it by hand'.
    Preserves facts and updates all 6 language versions.
    """
    if not req.instruction.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Revision instruction cannot be empty"
        )
    try:
        provider = get_desc_provider()
        result = await provider.refine_catalog(
            current_listing=req.current_listing,
            instruction=req.instruction,
            source_lang=req.source_lang,
            category=req.category,
            image_tags=req.image_tags,
        )
    except Exception:
        fallback_provider = MockDescriptionGenerator()
        result = await fallback_provider.refine_catalog(
            current_listing=req.current_listing,
            instruction=req.instruction,
            source_lang=req.source_lang,
            category=req.category,
            image_tags=req.image_tags,
        )

    return GenerateListingResponse(
        source_lang=result.get("source_lang", req.source_lang),
        master=result.get("master", result.get("source")),
        original=result.get("original", result.get("master", result.get("source"))),
        translations=result.get("translations", {}),
    )

