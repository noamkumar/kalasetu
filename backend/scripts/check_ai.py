import io
import sys
import os
import re
import wave
import struct
import asyncio
from pathlib import Path
from typing import Optional, Tuple

# Ensure backend root is on sys.path
backend_dir = Path(__file__).resolve().parent.parent
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

from app.config import get_settings
from app.providers.gemini_client import GeminiClient, GeminiClientError

try:
    from PIL import Image, ImageDraw
    _HAS_PIL = True
except ImportError:
    _HAS_PIL = False

# Minimal 1x1 valid JPEG byte payload
_MINIMAL_JPEG = (
    b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x01\x00`\x00`\x00\x00\xff\xdb\x00C\x00"
    b"\x08\x06\x06\x07\x06\x05\x08\x07\x07\x07\t\t\x08\n\x0c\x14\r\x0c\x0b\x0b\x0c\x19"
    b"\x12\x13\x0f\x14\x1d\x1a\x1f\x1e\x1d\x1a\x1c\x1c $.' \",#\x1c\x1c(7),01444\x1f'9=82<.342"
    b"\xff\xc0\x00\x0b\x08\x00\x01\x00\x01\x01\x01\x11\x00\xff\xc4\x00\x1f\x00\x00\x01\x05\x01\x01"
    b"\x01\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x01\x02\x03\x04\x05\x06\x07\x08\t\n\x0b"
    b"\xff\xda\x00\x08\x01\x01\x00\x00?\x00\xbf\x00\xff\xd9"
)

def generate_test_image(format: str = "JPEG") -> bytes:
    """Generate a small product image (handcrafted terracotta pot on olive background)."""
    if _HAS_PIL:
        img = Image.new("RGB", (96, 96), color=(96, 108, 86))  # Olive background
        draw = ImageDraw.Draw(img)
        # Draw terracotta product (vase/pot shape) in the center
        draw.polygon(
            [(36, 68), (60, 68), (66, 48), (56, 30), (40, 30), (30, 48)],
            fill=(200, 90, 50)  # Terracotta color
        )
        draw.ellipse([38, 26, 58, 34], fill=(180, 80, 45))  # Rim
        buf = io.BytesIO()
        img.save(buf, format=format, quality=90)
        return buf.getvalue()
    return _MINIMAL_JPEG

def generate_test_audio() -> bytes:
    """Generate a minimal valid 1-second 8kHz mono WAV audio file in memory."""
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(1)  # Mono
        wf.setsampwidth(2)  # 16-bit
        wf.setframerate(8000)  # 8kHz
        # 0.5s of silence
        silence_frames = struct.pack("<h", 0) * 4000
        wf.writeframes(silence_frames)
    return buf.getvalue()

def parse_error_details(e: Exception) -> Tuple[Optional[int], str, str]:
    """Extract HTTP status code, error status string, and plain-English hint from an exception."""
    err_str = str(e)
    code = getattr(e, "code", None)
    if code is None:
        m = re.search(r"\b(400|401|403|404|429|500|502|503|504)\b", err_str)
        if m:
            try:
                code = int(m.group(1))
            except ValueError:
                pass

    status_name = getattr(e, "status", "") or ""
    if not status_name:
        for s in ["RESOURCE_EXHAUSTED", "PERMISSION_DENIED", "NOT_FOUND", "INVALID_ARGUMENT", "UNAVAILABLE"]:
            if s in err_str:
                status_name = s
                break

    lower = err_str.lower()
    if code == 429 or status_name == "RESOURCE_EXHAUSTED" or "quota" in lower or "rate limit" in lower:
        if "limit: 0" in lower or "limit 0" in lower:
            hint = "Billing not enabled for this key's project (free tier request limit is 0 for this model)."
        elif "free_tier" in lower:
            hint = "Free tier quota exhausted; billing may need to be enabled or wait for quota reset."
        else:
            hint = "Quota limit or rate limit exceeded for this key's project."
    elif code == 403 or status_name == "PERMISSION_DENIED":
        hint = "Permission denied; check API key permissions, API service enablement in Google Cloud Console, or project billing."
    elif code == 404 or status_name == "NOT_FOUND":
        hint = "Model not found; verify model name is supported by your API key and region."
    elif code == 400 or status_name == "INVALID_ARGUMENT":
        hint = "Invalid request arguments or unsupported modality for this model."
    elif "api key" in lower:
        hint = "API key is missing or invalid."
    else:
        hint = f"API error: {err_str[:120]}"

    return code, status_name, hint

async def run_checks():
    settings = get_settings()
    api_key = (settings.GEMINI_API_KEY or os.environ.get("GEMINI_API_KEY", "")).strip()

    print("\n=======================================================")
    print("           KalaSetu AI Verification Check")
    print("=======================================================")
    print(f"AI_MODE:             {settings.AI_MODE}")
    print(f"Text Model:          {settings.GEMINI_TEXT_MODEL}")
    print(f"Image Edit Model:    {settings.GEMINI_IMAGE_MODEL or '(none)'}")
    print(f"Image Edit Provider: {settings.IMAGE_EDIT_PROVIDER}")
    print(f"TTS Model:           {settings.GEMINI_TTS_MODEL or '(none)'}")
    print(f"TTS Voice:           {settings.GEMINI_TTS_VOICE or '(none)'}")
    print(f"Fallback Model:      {settings.GEMINI_FALLBACK_MODEL or '(none)'}")
    print(f"API Key Configured:  {'YES (' + api_key[:6] + '...' + api_key[-4:] + ')' if api_key else 'NO'}")
    print("-------------------------------------------------------\n")

    failed_checks = []

    if not api_key:
        err_msg = "GEMINI_API_KEY is not set. Add it to backend/.env or set environment variable."
        print(f"[FAIL] Text Generation: {err_msg}")
        print(f"[FAIL] Image Input:     {err_msg}")
        print(f"[FAIL] Audio Input:     {err_msg}")
        print(f"[FAIL] Grounded Search: {err_msg}")
        print(f"[FAIL] Image Edit:      {err_msg}")
        print(f"[FAIL] TTS:             {err_msg}")
        print("\nResult: FAIL (API key missing)\n")
        return False

    client = GeminiClient(api_key=api_key)

    # --- 1. Text Call ---
    print(f"Testing Text Generation call [Model: {settings.GEMINI_TEXT_MODEL}]...")
    text_passed = False
    try:
        response = await client.generate_text(
            prompt="Respond with the single word 'NAMASTE' only.",
            temperature=0.1,
            max_output_tokens=20,
        )
        if response and len(response.strip()) > 0:
            print(f"[PASS] Text Generation [Model: {settings.GEMINI_TEXT_MODEL}]: Successfully received '{response.strip()}'")
            text_passed = True
        else:
            err_msg = "Empty response received."
            print(f"[FAIL] Text Generation [Model: {settings.GEMINI_TEXT_MODEL}]: {err_msg}")
            failed_checks.append((f"Text Generation [Model: {settings.GEMINI_TEXT_MODEL}]", err_msg))
    except Exception as e:
        code, status_name, hint = parse_error_details(e)
        status_desc = f"HTTP {code}" if code else "Error"
        if status_name:
            status_desc += f" ({status_name})"
        err_line = f"{status_desc} - {hint}"
        print(f"[FAIL] Text Generation [Model: {settings.GEMINI_TEXT_MODEL}]: {err_line}")
        failed_checks.append((f"Text Generation [Model: {settings.GEMINI_TEXT_MODEL}]", err_line))

    # --- 2. Image Input Call ---
    print(f"\nTesting Image Input call (inline JPEG) [Model: {settings.GEMINI_TEXT_MODEL}]...")
    image_passed = False
    try:
        img_bytes = generate_test_image(format="JPEG")
        response = await client.generate_text(
            prompt="Identify the dominant color in this image in 1 or 2 words.",
            image_bytes=img_bytes,
            image_mime_type="image/jpeg",
            temperature=0.1,
            max_output_tokens=20,
        )
        if response and len(response.strip()) > 0:
            print(f"[PASS] Image Input [Model: {settings.GEMINI_TEXT_MODEL}]: Successfully analyzed image: '{response.strip()}'")
            image_passed = True
        else:
            err_msg = "Empty response received."
            print(f"[FAIL] Image Input [Model: {settings.GEMINI_TEXT_MODEL}]: {err_msg}")
            failed_checks.append((f"Image Input [Model: {settings.GEMINI_TEXT_MODEL}]", err_msg))
    except Exception as e:
        code, status_name, hint = parse_error_details(e)
        status_desc = f"HTTP {code}" if code else "Error"
        if status_name:
            status_desc += f" ({status_name})"
        err_line = f"{status_desc} - {hint}"
        print(f"[FAIL] Image Input [Model: {settings.GEMINI_TEXT_MODEL}]: {err_line}")
        failed_checks.append((f"Image Input [Model: {settings.GEMINI_TEXT_MODEL}]", err_line))

    # --- 3. Audio Input Call ---
    print(f"\nTesting Audio Input call (inline WAV) [Model: {settings.GEMINI_TEXT_MODEL}]...")
    audio_passed = False
    try:
        wav_bytes = generate_test_audio()
        response = await client.generate_text(
            prompt="Analyze this audio note. State if it contains speech or silence.",
            audio_bytes=wav_bytes,
            audio_mime_type="audio/wav",
            temperature=0.1,
            max_output_tokens=20,
        )
        if response and len(response.strip()) > 0:
            print(f"[PASS] Audio Input [Model: {settings.GEMINI_TEXT_MODEL}]: Successfully processed audio: '{response.strip()}'")
            audio_passed = True
        else:
            err_msg = "Empty response received."
            print(f"[FAIL] Audio Input [Model: {settings.GEMINI_TEXT_MODEL}]: {err_msg}")
            failed_checks.append((f"Audio Input [Model: {settings.GEMINI_TEXT_MODEL}]", err_msg))
    except Exception as e:
        code, status_name, hint = parse_error_details(e)
        status_desc = f"HTTP {code}" if code else "Error"
        if status_name:
            status_desc += f" ({status_name})"
        err_line = f"{status_desc} - {hint}"
        print(f"[FAIL] Audio Input [Model: {settings.GEMINI_TEXT_MODEL}]: {err_line}")
        failed_checks.append((f"Audio Input [Model: {settings.GEMINI_TEXT_MODEL}]", err_line))

    # --- 4. Grounded Search Call ---
    print(f"\nTesting Grounded Search call (Google Search Grounding via GeminiGateway) [Model: {settings.GEMINI_TEXT_MODEL}]...")
    grounded_passed = False
    try:
        from app.providers.gemini_client import GeminiGateway
        gateway = GeminiGateway(api_key=api_key)
        res = await gateway.generate_with_google_search(
            prompt="What is the current typical price of handmade terracotta chai cups in India in INR? Give 1 short sentence.",
            temperature=0.2,
        )
        if res and res.get("text"):
            sources = res.get("sources", [])
            print(f"[PASS] Grounded Search [Model: {settings.GEMINI_TEXT_MODEL}]: Received search grounded response.")
            print(f"       Text: {res['text'].strip()[:80]}...")
            print(f"       Sources found: {len(sources)}")
            grounded_passed = True
        else:
            err_msg = "Empty response received."
            print(f"[FAIL] Grounded Search [Model: {settings.GEMINI_TEXT_MODEL}]: {err_msg}")
            failed_checks.append((f"Grounded Search [Model: {settings.GEMINI_TEXT_MODEL}]", err_msg))
    except Exception as e:
        code, status_name, hint = parse_error_details(e)
        status_desc = f"HTTP {code}" if code else "Error"
        if status_name:
            status_desc += f" ({status_name})"
        err_line = f"{status_desc} - {hint}"
        print(f"[FAIL] Grounded Search [Model: {settings.GEMINI_TEXT_MODEL}]: {err_line}")
        failed_checks.append((f"Grounded Search [Model: {settings.GEMINI_TEXT_MODEL}]", err_line))

    # --- 5. Real Image Edit Call ---
    image_edit_model = (settings.GEMINI_IMAGE_MODEL or "").strip()
    image_edit_provider = settings.IMAGE_EDIT_PROVIDER
    print(f"\nTesting Image Edit call [Model: {image_edit_model or '(none)'} | Provider: {image_edit_provider}]...")
    image_edit_passed = False

    if not image_edit_model:
        err_msg = "GEMINI_IMAGE_MODEL is not configured in environment or .env."
        print(f"[FAIL] Image Edit [Model: (none) | Provider: {image_edit_provider}]: {err_msg}")
        failed_checks.append((f"Image Edit [Model: (none) | Provider: {image_edit_provider}]", err_msg))
    else:
        try:
            input_bytes = generate_test_image(format="PNG")
            tmp_dir = backend_dir / "tmp"
            tmp_dir.mkdir(parents=True, exist_ok=True)
            output_file = tmp_dir / "check_edit.png"

            prompt = "Please edit this product image: make the background pure white and keep the handcrafted terracotta pot centered."
            output_bytes = await client.edit_image(
                image_bytes=input_bytes,
                prompt=prompt,
                model=image_edit_model,
                mime_type="image/png",
            )

            if output_bytes and len(output_bytes) > 0:
                with open(output_file, "wb") as f:
                    f.write(output_bytes)

                if output_bytes != input_bytes:
                    print(f"[PASS] Image Edit [Model: {image_edit_model} | Provider: {image_edit_provider}]:")
                    print(f"       Received {len(output_bytes)} image bytes, verified output differs from input.")
                    print(f"       Saved output to {output_file.relative_to(backend_dir.parent)}.")
                    image_edit_passed = True
                else:
                    err_msg = "Model returned identical image bytes to input (image was not modified)."
                    print(f"[FAIL] Image Edit [Model: {image_edit_model} | Provider: {image_edit_provider}]: {err_msg}")
                    failed_checks.append((f"Image Edit [Model: {image_edit_model} | Provider: {image_edit_provider}]", err_msg))
            else:
                err_msg = "No image bytes returned in response."
                print(f"[FAIL] Image Edit [Model: {image_edit_model} | Provider: {image_edit_provider}]: {err_msg}")
                failed_checks.append((f"Image Edit [Model: {image_edit_model} | Provider: {image_edit_provider}]", err_msg))
        except Exception as e:
            code, status_name, hint = parse_error_details(e)
            status_desc = f"HTTP {code}" if code else "Error"
            if status_name:
                status_desc += f" ({status_name})"
            err_line = f"{status_desc} - {hint}"
            print(f"[FAIL] Image Edit [Model: {image_edit_model} | Provider: {image_edit_provider}]: {err_line}")
            failed_checks.append((f"Image Edit [Model: {image_edit_model} | Provider: {image_edit_provider}]", err_line))

    # --- 6. TTS Call ---
    tts_model = (settings.GEMINI_TTS_MODEL or "").strip()
    tts_voice = (settings.GEMINI_TTS_VOICE or "Kore").strip()
    print(f"\nTesting TTS call [Model: {tts_model or '(none)'} | Voice: {tts_voice}]...")
    tts_passed = False

    if not tts_model:
        err_msg = "GEMINI_TTS_MODEL is not configured in environment or .env."
        print(f"[FAIL] TTS [Model: (none) | Voice: {tts_voice}]: {err_msg}")
        failed_checks.append((f"TTS [Model: (none) | Voice: {tts_voice}]", err_msg))
    else:
        try:
            from google.genai import types
            cfg = types.GenerateContentConfig(
                response_modalities=["AUDIO"],
                speech_config=types.SpeechConfig(
                    voice_config=types.VoiceConfig(
                        prebuilt_voice_config=types.PrebuiltVoiceConfig(
                            voice_name=tts_voice
                        )
                    )
                ),
                temperature=0.2,
            )
            resp = await client._client.aio.models.generate_content(
                model=tts_model,
                contents="Namaste, welcome to KalaSetu.",
                config=cfg,
            )
            audio_bytes = None
            if resp.candidates and resp.candidates[0].content:
                for part in resp.candidates[0].content.parts:
                    if part.inline_data and part.inline_data.data:
                        audio_bytes = part.inline_data.data
                        break
            if audio_bytes and len(audio_bytes) > 0:
                print(f"[PASS] TTS [Model: {tts_model} | Voice: {tts_voice}]:")
                print(f"       Successfully synthesized audio ({len(audio_bytes)} audio bytes received).")
                tts_passed = True
            else:
                err_msg = "No audio bytes returned in response."
                print(f"[FAIL] TTS [Model: {tts_model} | Voice: {tts_voice}]: {err_msg}")
                failed_checks.append((f"TTS [Model: {tts_model} | Voice: {tts_voice}]", err_msg))
        except Exception as e:
            code, status_name, hint = parse_error_details(e)
            status_desc = f"HTTP {code}" if code else "Error"
            if status_name:
                status_desc += f" ({status_name})"
            err_line = f"{status_desc} - {hint}"
            print(f"[FAIL] TTS [Model: {tts_model} | Voice: {tts_voice}]: {err_line}")
            failed_checks.append((f"TTS [Model: {tts_model} | Voice: {tts_voice}]", err_line))

    # --- Summary ---
    print("\n=======================================================")
    print("                      Summary")
    print("=======================================================")
    print(f"Text Generation: [{'PASS' if text_passed else 'FAIL'}] [Model: {settings.GEMINI_TEXT_MODEL}]")
    print(f"Image Input:     [{'PASS' if image_passed else 'FAIL'}] [Model: {settings.GEMINI_TEXT_MODEL}]")
    print(f"Audio Input:     [{'PASS' if audio_passed else 'FAIL'}] [Model: {settings.GEMINI_TEXT_MODEL}]")
    print(f"Grounded Search: [{'PASS' if grounded_passed else 'FAIL'}] [Model: {settings.GEMINI_TEXT_MODEL}]")
    print(f"Image Edit:      [{'PASS' if image_edit_passed else 'FAIL'}] [Model: {image_edit_model or '(none)'} | Provider: {image_edit_provider}]")
    print(f"TTS:             [{'PASS' if tts_passed else 'FAIL'}] [Model: {tts_model or '(none)'} | Voice: {tts_voice}]")
    print("-------------------------------------------------------")
    print("Failed checks:")
    if failed_checks:
        for name, reason in failed_checks:
            print(f" - {name}: {reason}")
    else:
        print(" None")
    all_passed = text_passed and image_passed and audio_passed and grounded_passed and image_edit_passed and tts_passed
    print("-------------------------------------------------------")
    print(f"Overall: {'ALL CHECKS PASSED' if all_passed else 'SOME CHECKS FAILED'}")
    print("=======================================================\n")
    return all_passed

if __name__ == "__main__":
    success = asyncio.run(run_checks())
    sys.exit(0 if success else 1)
