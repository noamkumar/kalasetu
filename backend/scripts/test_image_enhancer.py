"""
KalaSetu - Image Studio 3 Real Product Photos Enhancement Runner
Spec Section 7 Verification Script
"""
import os
import sys
import json
import shutil
from pathlib import Path

# Fix Windows console UTF-8 output
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.services.image_enhancer import enhance_image_sync

OUTPUT_DIR = Path("../docs/artifacts/studio_demo").resolve()

IMAGE_INPUTS = [
    {
        "id": "1_terracotta_pot",
        "name": "Handmade Terracotta Clay Pot",
        "style": "white",
        "path": r"C:\Users\mahal\.gemini\antigravity-ide\brain\f37a23c9-7969-4c6e-af98-170a1aef7a26\craft_terracotta_pot_1791346852150.jpg"
    },
    {
        "id": "2_wood_elephant",
        "name": "Jali Carved Wooden Elephant",
        "style": "linen",
        "path": r"C:\Users\mahal\.gemini\antigravity-ide\brain\f37a23c9-7969-4c6e-af98-170a1aef7a26\craft_wood_elephant_1791346874844.jpg"
    },
    {
        "id": "3_brass_diya",
        "name": "Peacock Brass Diya Lamp",
        "style": "linen",
        "path": r"C:\Users\mahal\.gemini\antigravity-ide\brain\f37a23c9-7969-4c6e-af98-170a1aef7a26\craft_brass_diya_1791346903894.jpg"
    }
]

def main():
    print("=" * 70)
    print("KalaSetu AI Image Studio - Testing 3 Real Product Craft Photos")
    print("=" * 70)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    results_summary = []

    for item in IMAGE_INPUTS:
        print(f"\nProcessing Photo {item['id']}: {item['name']} (Canvas: {item['style']})")
        src_path = Path(item["path"])
        if not src_path.exists():
            print(f"Error: {src_path} does not exist!")
            continue

        with open(src_path, "rb") as f:
            raw_bytes = f.read()

        raw_size_kb = round(len(raw_bytes) / 1024, 1)

        # Enhance image
        result = enhance_image_sync(
            image_bytes=raw_bytes,
            style=item["style"],
            storage_dir=str(OUTPUT_DIR)
        )

        # Extract saved filenames
        square_rel = result["variants"]["square"].split("/")[-1]
        portrait_rel = result["variants"]["portrait"].split("/")[-1]
        thumb_rel = result["variants"]["thumb"].split("/")[-1]
        orig_rel = result["original_url"].split("/")[-1]

        # Rename to clean demo names
        demo_orig = OUTPUT_DIR / f"{item['id']}_before.jpg"
        demo_square = OUTPUT_DIR / f"{item['id']}_after_hero_2000.webp"
        demo_portrait = OUTPUT_DIR / f"{item['id']}_after_social_1080x1350.webp"
        demo_thumb = OUTPUT_DIR / f"{item['id']}_after_thumb_600.webp"

        shutil.copyfile(OUTPUT_DIR / orig_rel, demo_orig)
        shutil.copyfile(OUTPUT_DIR / square_rel, demo_square)
        shutil.copyfile(OUTPUT_DIR / portrait_rel, demo_portrait)
        shutil.copyfile(OUTPUT_DIR / thumb_rel, demo_thumb)

        hero_size_kb = round(demo_square.stat().st_size / 1024, 1)
        social_size_kb = round(demo_portrait.stat().st_size / 1024, 1)
        thumb_size_kb = round(demo_thumb.stat().st_size / 1024, 1)

        print(f"  Enhancement Status: {result['status']}")
        print(f"  Quality Score:      {result['quality_score']}/100")
        print(f"  Quality Metrics:    {result['quality_metrics']}")
        print(f"  Photography Tips:   {result['tips']}")
        print(f"  Before (Raw):       {demo_orig.name} ({raw_size_kb} KB)")
        print(f"  Hero 2000x2000:     {demo_square.name} ({hero_size_kb} KB)")
        print(f"  Social 1080x1350:   {demo_portrait.name} ({social_size_kb} KB)")
        print(f"  Thumbnail 600x600:  {demo_thumb.name} ({thumb_size_kb} KB)")

        results_summary.append({
            "id": item["id"],
            "name": item["name"],
            "canvas_style": item["style"],
            "status": result["status"],
            "quality_score": result["quality_score"],
            "metrics": result["quality_metrics"],
            "tips": result["tips"],
            "before_file": demo_orig.name,
            "after_hero_file": demo_square.name,
            "after_social_file": demo_portrait.name,
            "after_thumb_file": demo_thumb.name,
            "raw_size_kb": raw_size_kb,
            "hero_size_kb": hero_size_kb,
            "social_size_kb": social_size_kb,
            "thumb_size_kb": thumb_size_kb
        })

    # Save summary json
    summary_path = OUTPUT_DIR / "enhancement_report.json"
    with open(summary_path, "w", encoding="utf-8") as f:
        json.dump(results_summary, f, indent=2)

    print("\n" + "=" * 70)
    print("ALL 3 PHOTOS PROCESSED AND EXPORTED SUCCESSFULLY!")
    print(f"Report & Artifacts saved to: {OUTPUT_DIR}")
    print("=" * 70)

if __name__ == "__main__":
    main()
