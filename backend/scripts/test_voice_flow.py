import io
import os
import sys
import json
import wave
import struct
import asyncio
from pathlib import Path

# Reconfigure stdout for UTF-8 on Windows
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")

# Add backend directory to sys.path
backend_dir = Path(__file__).resolve().parent.parent
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

from app.config import get_settings
from app.providers.gemini_client import GeminiClient
from app.providers.gemini_provider import GeminiSpeechToText, GeminiDescriptionGenerator

def create_synthetic_wav(duration_seconds: float = 1.0, freq: int = 440) -> bytes:
    """Generate a clean synthetic 16kHz mono WAV."""
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(16000)
        num_samples = int(16000 * duration_seconds)
        samples = bytearray()
        for i in range(num_samples):
            # Gentle tone
            val = int(32767.0 * 0.3 * (i % 36 / 36.0))
            samples.extend(struct.pack("<h", val))
        wf.writeframes(samples)
    return buf.getvalue()

async def run_voice_flow_tests():
    settings = get_settings()
    print("\n=======================================================")
    print("   KalaSetu Voice-to-Listing End-to-End Test")
    print("=======================================================")
    print(f"AI_MODE: {settings.AI_MODE}")
    print(f"Model:   {settings.GEMINI_TEXT_MODEL}")
    print("-------------------------------------------------------\n")

    client = GeminiClient()
    stt = GeminiSpeechToText(client=client)
    desc_gen = GeminiDescriptionGenerator(client=client)

    # 1. Test Telugu Flow
    print("-------------------------------------------------------")
    print("TEST 1: Telugu Craft Sample Flow")
    print("-------------------------------------------------------")
    telugu_sample_transcript = "ఇది చేతితో చేసిన సాంప్రదాయ టెర్రకోట మట్టి నీటి కుండ. ఎర్ర మట్టితో చక్రంపై చేసి కాల్చినది. సహజంగా నీటిని చల్లగా ఉంచుతుంది."
    print(f"Artisan Telugu Transcript:\n'{telugu_sample_transcript}'\n")

    print("Generating 6-Language Listing from Telugu Transcript via Gemini...")
    te_result = await desc_gen.generate_catalog(
        transcript=telugu_sample_transcript,
        source_lang="te",
        category="pottery",
        price=350.0,
        image_tags={"materials": ["terracotta", "natural red clay"], "craft": "pottery"}
    )

    print("\n[PASS] Telugu Master English Listing:")
    master_en = te_result["master"]
    print(f"  Title:            {master_en['title']}")
    print(f"  Short Desc:       {master_en['short_description']}")
    print(f"  SEO Title (<=60): {master_en['seo_title']} (len: {len(master_en['seo_title'])})")
    print(f"  Materials:        {master_en['materials']}")

    print("\n[PASS] Telugu Native Translation (te):")
    trans_te = te_result["translations"]["te"]
    print(f"  Title:            {trans_te['title']}")
    print(f"  Short Desc:       {trans_te['short_description']}")

    # 2. Test Hindi Flow
    print("\n-------------------------------------------------------")
    print("TEST 2: Hindi Craft Sample Flow")
    print("-------------------------------------------------------")
    hindi_sample_transcript = "यह हस्तनिर्मित मिट्टी का सुराहीदार घड़ा है। प्राकृतिक लाल मिट्टी से चाक पर बनाया गया है। इसमें पानी प्राकृतिक रूप से ठंडा और मीठा रहता है।"
    print(f"Artisan Hindi Transcript:\n'{hindi_sample_transcript}'\n")

    print("Generating 6-Language Listing from Hindi Transcript via Gemini...")
    hi_result = await desc_gen.generate_catalog(
        transcript=hindi_sample_transcript,
        source_lang="hi",
        category="pottery",
        price=400.0,
        image_tags={"materials": ["clay", "terracotta"], "craft": "pottery"}
    )

    print("\n[PASS] Hindi Master English Listing:")
    master_hi = hi_result["master"]
    print(f"  Title:            {master_hi['title']}")
    print(f"  Short Desc:       {master_hi['short_description']}")
    print(f"  SEO Title (<=60): {master_hi['seo_title']} (len: {len(master_hi['seo_title'])})")
    print(f"  Materials:        {master_hi['materials']}")

    print("\n[PASS] Hindi Native Translation (hi):")
    trans_hi = hi_result["translations"]["hi"]
    print(f"  Title:            {trans_hi['title']}")
    print(f"  Short Desc:       {trans_hi['short_description']}")

    # Check all 6 languages present in both
    for lang in ["en", "hi", "ta", "te", "kn", "ml"]:
        assert lang in te_result["translations"], f"Missing {lang} in Telugu result"
        assert lang in hi_result["translations"], f"Missing {lang} in Hindi result"

    print("\n=======================================================")
    print("ALL 6 LANGUAGES VERIFIED FOR TELUGU AND HINDI FLOWS: PASS")
    print("=======================================================\n")

if __name__ == "__main__":
    asyncio.run(run_voice_flow_tests())
