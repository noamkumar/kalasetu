import os
import base64
from typing import Any, Dict, List, Optional
from fastapi import APIRouter, File, Form, UploadFile, HTTPException, Request, status
from pydantic import BaseModel, Field

from app.config import get_settings
from app.providers.interfaces import ImageEditor, ImageEnhancer
from app.providers.rembg_provider import RealImageEnhancer
from app.providers.mock_providers import MockImageEditor, MockImageEnhancer
from app.providers.image_editor_provider import RealImageEditor
from app.providers.gemini_client import GeminiClientError, log_ai_failure

router = APIRouter(prefix="/images", tags=["Images"])

def get_image_enhancer_provider() -> ImageEnhancer:
    settings = get_settings()
    if settings.AI_MODE == "real":
        return RealImageEnhancer()
    return MockImageEnhancer()

def get_image_editor_provider() -> ImageEditor:
    settings = get_settings()
    if settings.AI_MODE == "real":
        return RealImageEditor()
    return MockImageEditor()

# --- Enhance Models ---
class QualityMetrics(BaseModel):
    sharpness: float
    exposure: float
    subject_size: float

class ImageVariants(BaseModel):
    square: str
    portrait: str
    thumb: str

class EnhanceImageResponse(BaseModel):
    status: str
    image_id: Optional[str] = None
    quality_score: float
    quality_metrics: Optional[QualityMetrics] = None
    original_url: str
    enhanced_url: str
    variants: ImageVariants
    tips: List[str] = []
    tags: Optional[Dict[str, Any]] = None

# --- Edit Models ---
class EditOperation(BaseModel):
    type: str
    value: Optional[Any] = None
    width: Optional[int] = None
    color: Optional[str] = None
    params: Optional[Dict[str, Any]] = None

class EditImageRequest(BaseModel):
    image_id: str
    prompt: Optional[str] = None
    text: Optional[str] = None
    operations: Optional[List[Dict[str, Any]]] = None
    action: Optional[str] = "apply" # "apply", "undo", "redo", "reset"
    lang: Optional[str] = "en"

class EditImageResponse(BaseModel):
    status: str
    image_id: str
    image_url: str
    original_url: str
    operations: List[Dict[str, Any]] = []
    can_undo: bool = False
    can_redo: bool = False
    message: Optional[str] = None
    render_meta: Optional[Dict[str, Any]] = None
    product_changed: bool = False
    warn_product_change: bool = False
    product_warning: Optional[str] = None

# --- Voice Command Models ---
class VoiceCommandRequest(BaseModel):
    image_id: str
    text: Optional[str] = None
    audio_base64: Optional[str] = None
    lang: str = "en"

class VoiceCommandResponse(BaseModel):
    status: str
    transcript: str = ""
    operations: List[Dict[str, Any]] = []
    new_operations: List[Dict[str, Any]] = []
    action: Optional[str] = "apply"
    confirmation: str
    clarification_needed: bool = False
    clarifying_question: Optional[str] = None
    ai_edit_available: bool = False
    image_id: Optional[str] = None
    image_url: Optional[str] = None
    original_url: Optional[str] = None
    can_undo: bool = False
    can_redo: bool = False
    product_changed: bool = False
    warn_product_change: bool = False
    product_warning: Optional[str] = None

# --- Fidelity Check Models ---
class FidelityCheckRequest(BaseModel):
    image_id: str

class FidelityCheckResponse(BaseModel):
    status: str
    product_changed: bool
    confidence: float
    warning: Optional[str] = None


@router.post("/enhance", response_model=EnhanceImageResponse)
async def enhance_image(
    file: Optional[UploadFile] = File(None),
    image: Optional[UploadFile] = File(None),
    style: str = Form("white"),
):
    """Enhances craft product photography with local free AI processing."""
    upload = file or image
    if upload is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No image file provided. Pass 'image' or 'file' form-data.",
        )

    ext = os.path.splitext(upload.filename or "")[1].lower()
    if ext not in [".jpg", ".jpeg", ".png", ".webp", ""]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported image format: {ext}. Use JPG, PNG or WebP.",
        )

    image_bytes = await upload.read()
    if not image_bytes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded image file is empty",
        )

    mime_type = upload.content_type or "image/jpeg"

    try:
        provider = get_image_enhancer_provider()
        result = await provider.enhance_image(
            image_bytes=image_bytes,
            style=style,
            mime_type=mime_type,
        )

        return EnhanceImageResponse(
            status=result.get("status", "done"),
            image_id=result.get("image_id"),
            quality_score=float(result.get("quality_score", 85.0)),
            quality_metrics=result.get("quality_metrics"),
            original_url=result.get("original_url", ""),
            enhanced_url=result.get("enhanced_url", ""),
            variants=ImageVariants(
                square=result.get("variants", {}).get("square", ""),
                portrait=result.get("variants", {}).get("portrait", ""),
                thumb=result.get("variants", {}).get("thumb", ""),
            ),
            tips=result.get("tips", []),
            tags=result.get("tags"),
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Image enhancement failed: {str(e)}"
        )


@router.post("/edit", response_model=EditImageResponse)
async def edit_image(request_body: EditImageRequest):
    """POST /images/edit applying operations non-destructively to the ORIGINAL cut-out.
    
    Supported operations:
    - remove_background
    - keep_background
    - replace_background (white, linen, any named colour, soft gradient, blur, textured)
    - brightness
    - contrast
    - warmth
    - saturation
    - sharpness
    - shadow (on/off/strength)
    - zoom / crop to subject
    - rotate
    - flip
    - add_border
    - product_size on canvas
    - auto_enhance
    
    Supports non-destructive history:
    - action: "apply", "undo", "redo", "reset"
    """
    image_id = request_body.image_id.strip()
    if not image_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Field 'image_id' is required"
        )

    try:
        editor = get_image_editor_provider()
        res = await editor.edit_image(
            image_id=image_id,
            operations=request_body.operations,
            prompt=request_body.prompt or request_body.text,
            action=request_body.action or "apply",
            lang=request_body.lang or "en",
        )

        if res.get("status") == "error":
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=res.get("message") or "Image edit failed: no image returned."
            )

        return EditImageResponse(
            status=res.get("status", "success"),
            image_id=image_id,
            image_url=res.get("image_url", ""),
            original_url=res.get("original_url", ""),
            operations=res.get("operations", []),
            can_undo=res.get("can_undo", False),
            can_redo=res.get("can_redo", False),
            render_meta=res.get("render_meta"),
            message=res.get("message", "Operation completed successfully"),
            product_changed=res.get("product_changed", False),
            warn_product_change=res.get("warn_product_change", False),
            product_warning=res.get("product_warning"),
        )
    except FileNotFoundError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e)
        )
    except HTTPException:
        raise
    except Exception as e:
        settings = get_settings()
        info = log_ai_failure(e, settings.GEMINI_IMAGE_MODEL or "unknown")
        raise HTTPException(
            status_code=info["http_status"] if info["http_status"] in (400, 401, 403, 404, 429, 502) else status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "message": f"Image edit failed: {info['hint']}",
                "http_status": info["http_status"],
                "gemini_status": info["gemini_status"],
                "model": info["model"],
                "hint": info["hint"],
            }
        )


@router.post("/voice-command", response_model=VoiceCommandResponse)
async def process_voice_command(request: Request):
    """POST /images/voice-command {image_id, audio or text, lang}:
    
    Transcribe (en, hi, ta, te, kn, ml, mixed), then convert request into JSON operations
    from the supported operations list via Gemini.
    Return operations, short confirmation in user's language, and apply them.
    If request is unclear, return clarifying question in user's language.
    If free-form request cannot be expressed as operations and GEMINI_IMAGE_MODEL is not set,
    reply politely that it is not available.
    """
    content_type = request.headers.get("content-type", "").lower()
    audio_bytes: Optional[bytes] = None
    audio_mime_type = "audio/wav"
    command_text: Optional[str] = None
    lang = "en"
    image_id: Optional[str] = None

    if "application/json" in content_type:
        body = await request.json()
        image_id = body.get("image_id")
        command_text = body.get("text")
        lang = body.get("lang", "en")
        if body.get("audio_base64"):
            try:
                audio_bytes = base64.b64decode(body["audio_base64"])
            except Exception:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Invalid base64 encoding in 'audio_base64'"
                )
    else:
        # Multipart / Form data
        form = await request.form()
        image_id = str(form.get("image_id") or "")
        command_text = str(form.get("text") or "") if form.get("text") else None
        lang = str(form.get("lang") or "en")
        upload_audio = form.get("audio") or form.get("file")
        if upload_audio and hasattr(upload_audio, "read"):
            audio_bytes = await upload_audio.read()
            audio_mime_type = getattr(upload_audio, "content_type", "audio/wav") or "audio/wav"

    if not image_id or not image_id.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Field 'image_id' is required"
        )

    try:
        editor = get_image_editor_provider()
        res = await editor.process_voice_command(
            image_id=image_id.strip(),
            text=command_text,
            audio_bytes=audio_bytes,
            audio_mime_type=audio_mime_type,
            lang=lang,
        )

        return VoiceCommandResponse(
            status=res.get("status", "success"),
            transcript=res.get("transcript", ""),
            operations=res.get("operations", []),
            new_operations=res.get("new_operations", []),
            action=res.get("action", "apply"),
            confirmation=res.get("confirmation", ""),
            clarification_needed=res.get("clarification_needed", False),
            clarifying_question=res.get("clarifying_question"),
            ai_edit_available=res.get("ai_edit_available", False),
            image_id=res.get("image_id", image_id),
            image_url=res.get("image_url"),
            original_url=res.get("original_url"),
            can_undo=res.get("can_undo", False),
            can_redo=res.get("can_redo", False),
            product_changed=res.get("product_changed", False),
            warn_product_change=res.get("warn_product_change", False),
            product_warning=res.get("product_warning"),
        )
    except FileNotFoundError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e)
        )
    except HTTPException:
        raise
    except Exception as e:
        settings = get_settings()
        info = log_ai_failure(e, settings.GEMINI_IMAGE_MODEL or "unknown")
        raise HTTPException(
            status_code=info["http_status"] if info["http_status"] in (400, 401, 403, 404, 429) else status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "message": f"Voice command processing failed: {info['hint']}",
                "http_status": info["http_status"],
                "gemini_status": info["gemini_status"],
                "model": info["model"],
                "hint": info["hint"],
            }
        )


@router.post("/fidelity-check", response_model=FidelityCheckResponse)
async def check_image_fidelity_endpoint(req: FidelityCheckRequest):
    """POST /images/fidelity-check:
    Runs a Gemini vision fidelity check verifying that the handcrafted product itself
    remains strictly unchanged (geometry, intrinsic color, texture) between original and edited photo.
    """
    image_id = req.image_id.strip()
    if not image_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Field 'image_id' is required"
        )

    try:
        from app.providers.image_editor_provider import check_image_fidelity
        res = await check_image_fidelity(image_id=image_id)
        return FidelityCheckResponse(
            status=res.get("status", "ok"),
            product_changed=res.get("product_changed", False),
            confidence=res.get("confidence", 0.95),
            warning=res.get("warning"),
        )
    except HTTPException:
        raise
    except Exception as e:
        settings = get_settings()
        info = log_ai_failure(e, settings.GEMINI_TEXT_MODEL or "unknown")
        raise HTTPException(
            status_code=info["http_status"] if info["http_status"] in (400, 401, 403, 404, 429) else status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "message": f"Fidelity check failed: {info['hint']}",
                "http_status": info["http_status"],
                "gemini_status": info["gemini_status"],
                "model": info["model"],
                "hint": info["hint"],
            }
        )
