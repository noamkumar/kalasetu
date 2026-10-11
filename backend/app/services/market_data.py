"""
KalaSetu - Market Data & Comparables Service
Section 9 of Project Specification
"""
import os
import csv
import json
import logging
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple
import numpy as np

logger = logging.getLogger("kalasetu.market_data")

class MarketDataService:
    def __init__(self, dataset_path: Optional[str] = None):
        if dataset_path is None:
            base_dir = Path(__file__).resolve().parent.parent.parent
            self.dataset_path = base_dir / "ml" / "dataset" / "seed_prices.csv"
        else:
            self.dataset_path = Path(dataset_path)

        self._records: List[Dict[str, Any]] = []
        self._load_dataset()

    def _load_dataset(self):
        if not self.dataset_path.exists():
            logger.warning(f"Market dataset not found at {self.dataset_path}")
            return

        try:
            with open(self.dataset_path, "r", encoding="utf-8") as f:
                reader = csv.DictReader(f)
                for row in reader:
                    self._records.append({
                        "category": row["category"].strip().lower(),
                        "material": row["material"].strip().lower(),
                        "technique": row["technique"].strip(),
                        "region": row["region"].strip(),
                        "size_cm": float(row["size_cm"]),
                        "material_cost": float(row["material_cost"]),
                        "labour_hours": float(row["labour_hours"]),
                        "final_price": int(float(row["final_price"])),
                        "quality_score": float(row["quality_score"]),
                    })
            logger.info(f"Loaded {len(self._records)} market reference listings from {self.dataset_path.name}")
        except Exception as e:
            logger.error(f"Failed to load market data: {e}")

    def get_comparables(
        self,
        category: str,
        materials: List[str],
        region: Optional[str] = None,
        limit: int = 4
    ) -> Dict[str, Any]:
        """
        Retrieves comparable products matching category and materials,
        computing median, 25th, and 75th percentile statistics.
        """
        if not self._records:
            return {"comparables": [], "stats": None}

        cat_clean = category.strip().lower()
        mat_clean_list = [m.strip().lower() for m in materials if m.strip()]

        matches = []
        for rec in self._records:
            # Category match
            if rec["category"] != cat_clean and cat_clean not in rec["category"]:
                continue

            # Material similarity
            sim = 0.5  # Base match for category
            rec_mat = rec["material"]
            for m in mat_clean_list:
                if m in rec_mat or rec_mat in m:
                    sim += 0.4
                    break

            if region and rec["region"].upper() == region.strip().upper():
                sim += 0.08

            sim = min(0.96, round(sim, 2))
            matches.append((sim, rec))

        if not matches:
            return {"comparables": [], "stats": None}

        # Sort by similarity descending
        matches.sort(key=lambda x: x[0], reverse=True)

        prices = [m[1]["final_price"] for m in matches]
        p25 = int(np.percentile(prices, 25))
        median = int(np.percentile(prices, 50))
        p75 = int(np.percentile(prices, 75))

        top_matches = matches[:limit]
        comparables = []
        for sim, item in top_matches:
            # Craft realistic artisan listing title
            title = f"{item['technique'].replace('-', ' ').title()} {item['category'].title()} ({item['material'].title()})"
            comparables.append({
                "title": title,
                "price": item["final_price"],
                "similarity": sim,
                "region": item["region"],
            })

        return {
            "comparables": comparables,
            "stats": {
                "count": len(matches),
                "min": int(np.min(prices)),
                "max": int(np.max(prices)),
                "median": median,
                "p25": p25,
                "p75": p75,
            }
        }

    async def get_market_trends_grounded(
        self,
        category: str,
        materials: List[str],
        region: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Retrieves current market trends for this craft in India using Gemini with
        Google Search Grounding.
        Returns:
        - price_range (min, max, median)
        - comparables_count
        - source_links ([{title, url}])
        - date_fetched (YYYY-MM-DD)
        - evidence_level ('grounded' or 'thin')
        - label ('Market benchmarked' or 'Estimate')
        Caches 24 hours per category/material. Shows 'Estimate' when evidence is thin.
        """
        import time
        from datetime import datetime, timezone
        from app.config import get_settings

        base_dir = Path(__file__).resolve().parent.parent.parent
        cache_file = base_dir / "ml" / "artifacts" / "market_trends_cache.json"

        cat_clean = (category or "pottery").strip().lower()
        mat_clean = (materials[0] if materials else "natural").strip().lower()
        cache_key = f"{cat_clean}:{mat_clean}"

        # 1. Check 24-hour cache
        cache: Dict[str, Any] = {}
        if cache_file.exists():
            try:
                with open(cache_file, "r", encoding="utf-8") as f:
                    cache = json.load(f)
            except Exception:
                cache = {}

        now_ts = time.time()
        today_str = datetime.now(timezone.utc).strftime("%Y-%m-%d")

        if cache_key in cache:
            entry = cache[cache_key]
            cached_ts = entry.get("timestamp", 0)
            if now_ts - cached_ts < 86400:  # 24 hours TTL
                entry_copy = dict(entry)
                entry_copy["cached"] = True
                return entry_copy

        # 2. Derive baseline from local dataset for fallback & numbers
        comps = self.get_comparables(category=cat_clean, materials=materials, region=region)
        stats = comps.get("stats")
        if stats and stats["count"] > 0:
            base_min = stats["min"]
            base_max = stats["max"]
            base_med = stats["median"]
            comp_count = stats["count"]
        else:
            base_min = 299
            base_max = 1499
            base_med = 649
            comp_count = 0

        # 3. Call Gemini with Google Search Grounding if configured
        settings = get_settings()
        sources: List[Dict[str, str]] = []
        evidence_level = "thin"
        search_summary = ""

        if settings.AI_MODE == "real" and settings.GEMINI_API_KEY:
            try:
                from app.providers.gemini_client import GeminiClient
                client = GeminiClient()
                prompt = (
                    f"Search current e-commerce and artisan marketplace selling prices in India (INR) for authentic "
                    f"handcrafted {mat_clean} {cat_clean}. Check Indian craft platforms like Amazon Karigar, Craftsvilla, "
                    f"ONDC, Jaypore, Meesho, and Etsy India. Give typical price ranges and reputable market links."
                )
                search_res = await client.generate_with_google_search(prompt=prompt)
                search_summary = search_res.get("text", "")
                raw_sources = search_res.get("sources", [])
                for s in raw_sources:
                    uri = s.get("uri", "")
                    title = s.get("title", "") or uri
                    if uri and uri.startswith("http"):
                        sources.append({"title": title, "url": uri})

                if len(sources) >= 2 or (sources and "₹" in search_summary):
                    evidence_level = "grounded"
            except Exception as e:
                logger.info(f"Grounded search unavailable, using robust baseline: {e}")
                evidence_level = "thin"

        # When evidence is thin: label is 'Estimate'
        if not sources and comp_count == 0:
            evidence_level = "thin"
            label = "Estimate"
            status_text = "Estimate based on your costs only"
        elif sources:
            evidence_level = "grounded"
            label = "Market benchmarked"
            status_text = "Market benchmarked"
        else:
            evidence_level = "dataset_benchmarked"
            label = "Market benchmarked"
            status_text = "Market benchmarked"

        trend_result = {
            "category": cat_clean,
            "material": mat_clean,
            "price_range": {
                "min": base_min,
                "max": base_max,
                "median": base_med,
            },
            "comparables_count": max(len(sources), comp_count),
            "source_links": sources,
            "date_fetched": today_str,
            "evidence_level": evidence_level,
            "label": label,
            "status_text": status_text,
            "timestamp": now_ts,
            "cached": False,
        }

        # 4. Write back to 24-hour cache
        try:
            cache_file.parent.mkdir(parents=True, exist_ok=True)
            cache[cache_key] = trend_result
            with open(cache_file, "w", encoding="utf-8") as f:
                json.dump(cache, f, indent=2)
        except Exception as e:
            logger.warning(f"Could not persist market cache: {e}")

        return trend_result

