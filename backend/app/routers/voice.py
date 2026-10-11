import os
import re
import hashlib
import base64
import struct
import math
import asyncio
import logging
from typing import Optional
from fastapi import APIRouter, HTTPException, status
from fastapi.responses import FileResponse
from pydantic import BaseModel

from app.config import get_settings
from app.providers.gemini_client import GeminiClient

logger = logging.getLogger("kalasetu.voice")
router = APIRouter(prefix="/voice", tags=["Voice"])
settings = get_settings()

# Concurrency locking per hash to prevent duplicate parallel synthesis requests
_synthesis_locks: dict[str, asyncio.Lock] = {}
_locks_guard = asyncio.Lock()

async def _get_hash_lock(audio_hash: str) -> asyncio.Lock:
    async with _locks_guard:
        if audio_hash not in _synthesis_locks:
            _synthesis_locks[audio_hash] = asyncio.Lock()
        return _synthesis_locks[audio_hash]

LANGUAGE_NAMES = {
    "en": "English",
    "hi": "Hindi",
    "ta": "Tamil",
    "te": "Telugu",
    "kn": "Kannada",
    "ml": "Malayalam",
}

class VoiceSpeakRequest(BaseModel):
    text: str
    lang: str = "en"
    voice: Optional[str] = None

class VoiceSpeakResponse(BaseModel):
    audio_base64: str
    mime_type: str
    hash: str
    cached: bool
    voice: str
    lang: str
    generation_ms: Optional[float] = 0.0

VOICE_PROFILES = {
    "kalamitra_warm_female_v3": {
        "voice_name": "Kore",
        "style_prompt": "Speak aloud in a calm, warm, clear, friendly female conversational voice at a relaxed, slightly slow pace (about 0.85x speed): ",
    },
    "kalamitra_warm_female": {
        "voice_name": "Kore",
        "style_prompt": "Speak aloud in a calm, warm, clear, friendly female conversational voice at a relaxed, slightly slow pace (about 0.85x speed): ",
    },
    "kore": {
        "voice_name": "Kore",
        "style_prompt": "Speak aloud in a calm, warm, clear, friendly female conversational voice at a relaxed, slightly slow pace (about 0.85x speed): ",
    },
}
DEFAULT_VOICE_PROFILE = "kalamitra_warm_female_v3"

_client_singleton: Optional[GeminiClient] = None

def get_voice_client() -> GeminiClient:
    global _client_singleton
    if _client_singleton is None:
        _client_singleton = GeminiClient()
    return _client_singleton

def compute_voice_hash(text: str, lang: str, voice: str) -> str:
    raw = f"{text.strip().lower()}|{lang.strip().lower()}|{voice.strip().lower()}"
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()

def pcm_to_wav(pcm_bytes: bytes, sample_rate: int = 24000, num_channels: int = 1, bit_depth: int = 16) -> bytes:
    """Wraps raw linear PCM audio into a standard RIFF/WAVE container."""
    data_size = len(pcm_bytes)
    byte_rate = sample_rate * num_channels * (bit_depth // 8)
    block_align = num_channels * (bit_depth // 8)
    header = struct.pack(
        '<4sI4s4sIHHIIHH4sI',
        b'RIFF',
        36 + data_size,
        b'WAVE',
        b'fmt ',
        16,  # PCM format subchunk size
        1,   # AudioFormat: 1 = PCM
        num_channels,
        sample_rate,
        byte_rate,
        block_align,
        bit_depth,
        b'data',
        data_size,
    )
    return header + pcm_bytes

def generate_mock_wav(duration_seconds: float = 1.0, sample_rate: int = 16000) -> bytes:
    """Generates a pleasant synthetic acoustic cue WAV file for offline/mock mode."""
    num_samples = int(duration_seconds * sample_rate)
    pcm_data = bytearray()
    freq = 440.0 # Concert A warm tone
    for i in range(num_samples):
        # Soft envelope fade-in and fade-out to prevent clicks
        t = i / sample_rate
        envelope = math.sin(math.pi * (i / num_samples))
        sample = int(3000 * envelope * math.sin(2.0 * math.pi * freq * t))
        pcm_data.extend(struct.pack('<h', max(-32768, min(32767, sample))))
    return pcm_to_wav(bytes(pcm_data), sample_rate=sample_rate, num_channels=1, bit_depth=16)

@router.post("/speak", response_model=VoiceSpeakResponse)
async def voice_speak(req: VoiceSpeakRequest):
    text = req.text.strip()
    if not text:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Text parameter cannot be empty."
        )

    norm_lang = req.lang.lower() if req.lang.lower() in LANGUAGE_NAMES else "en"
    raw_voice = (req.voice or settings.GEMINI_TTS_VOICE or "Kore").strip()
    voice_profile_key = raw_voice.lower()
    profile_info = VOICE_PROFILES.get(voice_profile_key, VOICE_PROFILES["kalamitra_warm_female"])
    voice_name = profile_info["voice_name"]
    style_prompt = profile_info["style_prompt"]
    return_voice = req.voice if req.voice else voice_name

    audio_hash = compute_voice_hash(text, norm_lang, return_voice)

    cache_dir = settings.VOICE_CACHE_PATH
    os.makedirs(cache_dir, exist_ok=True)
    cache_file = os.path.join(cache_dir, f"{audio_hash}.wav")

    # 1. Return cached audio immediately if already on disk
    if os.path.exists(cache_file):
        with open(cache_file, "rb") as f:
            audio_bytes = f.read()
        return VoiceSpeakResponse(
            audio_base64=base64.b64encode(audio_bytes).decode("ascii"),
            mime_type="audio/wav",
            hash=audio_hash,
            cached=True,
            voice=return_voice,
            lang=norm_lang,
            generation_ms=0.0,
        )

    # 2. Acquire concurrency lock for this hash so duplicate requests do not regenerate
    hash_lock = await _get_hash_lock(audio_hash)
    async with hash_lock:
        # Check cache again inside lock
        if os.path.exists(cache_file):
            with open(cache_file, "rb") as f:
                audio_bytes = f.read()
            return VoiceSpeakResponse(
                audio_base64=base64.b64encode(audio_bytes).decode("ascii"),
                mime_type="audio/wav",
                hash=audio_hash,
                cached=True,
                voice=return_voice,
                lang=norm_lang,
                generation_ms=0.0,
            )

        audio_bytes: Optional[bytes] = None
        error_detail: Optional[str] = None
        generation_ms = 0.0

        # 3. Call Gemini Speech Generation when configured in real AI mode
        if settings.AI_MODE == "real":
            client = get_voice_client()
            if client.is_configured:
                # Primary model with robust fallbacks
                models_to_try = [
                    (settings.GEMINI_TTS_MODEL or "gemini-2.5-flash-preview-tts").strip(),
                    "gemini-2.5-flash-preview-tts",
                    "gemini-2.5-flash",
                ]
                # Deduplicate while preserving order
                seen_models = set()
                candidate_models = []
                for m in models_to_try:
                    if m and m not in seen_models:
                        seen_models.add(m)
                        candidate_models.append(m)

                from google.genai import types

                speech_config = types.SpeechConfig(
                    voice_config=types.VoiceConfig(
                        prebuilt_voice_config=types.PrebuiltVoiceConfig(
                            voice_name=voice_name
                        )
                    )
                )

                config = types.GenerateContentConfig(
                    response_modalities=["AUDIO"],
                    speech_config=speech_config,
                    temperature=0.2,
                )

                prompt = f"{style_prompt}{text}"

                for current_model in candidate_models:
                    try:
                        t0 = asyncio.get_event_loop().time()
                        response = await asyncio.wait_for(
                            asyncio.to_thread(
                                client._client.models.generate_content,
                                model=current_model,
                                contents=prompt,
                                config=config,
                            ),
                            timeout=8.0,
                        )
                        generation_ms = round((asyncio.get_event_loop().time() - t0) * 1000, 2)

                        if response.candidates and response.candidates[0].content:
                            for part in response.candidates[0].content.parts:
                                if part.inline_data and part.inline_data.data:
                                    raw_data = part.inline_data.data
                                    mime = (part.inline_data.mime_type or "").lower()

                                    if raw_data.startswith(b'RIFF'):
                                        audio_bytes = raw_data
                                    else:
                                        rate = 24000
                                        if "rate=" in mime:
                                            m = re.search(r'rate=(\d+)', mime)
                                            if m:
                                                try:
                                                    rate = int(m.group(1))
                                                except Exception:
                                                    rate = 24000
                                        audio_bytes = pcm_to_wav(raw_data, sample_rate=rate, num_channels=1, bit_depth=16)
                                    break
                        if audio_bytes:
                            logger.info(
                                "Gemini TTS synthesized via %s in %.1fms (size=%d bytes).",
                                current_model, generation_ms, len(audio_bytes)
                            )
                            break
                    except Exception as ex:
                        error_detail = str(ex)
                        logger.warning("Gemini TTS synthesis attempt failed on %s: %s", current_model, error_detail)

            # In real mode, if Gemini fails or is unconfigured, NEVER return a mock sine wave.
            # Raise 503 so the client immediately falls back to high-quality flutter_tts!
            if not audio_bytes:
                logger.info("Real AI mode active: returning 503 so Flutter invokes flutter_tts fallback.")
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail=f"Gemini TTS generation failed ({error_detail or 'Service unavailable'}). Please use offline fallback."
                )

        # 4. In mock mode (e.g. unit tests), generate acoustic mock wav
        if not audio_bytes:
            audio_bytes = generate_mock_wav()

        # Validate resulting WAV container before saving to cache
        if not audio_bytes.startswith(b'RIFF') or len(audio_bytes) < 44:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Generated audio is invalid or corrupted."
            )

        # Save to disk cache
        with open(cache_file, "wb") as f:
            f.write(audio_bytes)

        return VoiceSpeakResponse(
            audio_base64=base64.b64encode(audio_bytes).decode("ascii"),
            mime_type="audio/wav",
            hash=audio_hash,
            cached=False,
            voice=return_voice,
            lang=norm_lang,
            generation_ms=generation_ms,
        )

@router.get("/audio/{audio_hash}")
async def get_cached_audio(audio_hash: str):
    clean_hash = os.path.basename(audio_hash.strip().replace(".wav", ""))
    cache_file = os.path.join(settings.VOICE_CACHE_PATH, f"{clean_hash}.wav")
    if not os.path.exists(cache_file):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Audio hash {clean_hash} not found in voice cache."
        )
    return FileResponse(cache_file, media_type="audio/wav")
