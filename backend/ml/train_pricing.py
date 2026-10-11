"""
KalaSetu - LightGBM Gradient Boosting Dynamic Pricing Model Training Script
Section 9 of Project Specification
"""
import os
import sys
import json
from pathlib import Path
import numpy as np
import pandas as pd
import lightgbm as lgb

import sqlite3
from pathlib import Path
import numpy as np
import pandas as pd
import lightgbm as lgb

# Fix Windows console UTF-8
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")

BASE_DIR = Path(__file__).resolve().parent
DATASET_PATH = BASE_DIR / "dataset" / "seed_prices.csv"
ARTIFACTS_DIR = BASE_DIR / "artifacts"
DB_PATH = BASE_DIR.parent / "kalasetu.db"

FEATURE_COLUMNS = [
    "category", "material", "technique", "region",
    "size_cm", "material_cost", "labour_hours", "quality_score",
    "cost_floor", "comparable_median", "craft_complexity", "finish_quality", "uniqueness", "season_factor"
]
CATEGORICAL_COLS = ["category", "material", "technique", "region", "craft_complexity", "finish_quality", "uniqueness"]
TARGET = "final_price"

def calculate_season_factor(month: int) -> float:
    """Computes Indian handicraft seasonality multiplier (festivals, wedding season)."""
    # Oct-Nov: Diwali / Dussehra festive rush (+12%)
    if month in (10, 11):
        return 1.12
    # Dec-Feb: Winter wedding season & Pongal / Makar Sankranti (+10%)
    if month in (12, 1, 2):
        return 1.10
    # Aug-Sep: Raksha Bandhan / Ganesh Chaturthi / Onam (+8%)
    if month in (8, 9):
        return 1.08
    # Mar-Jul: Off-season baseline (1.00)
    return 1.00

def derive_gemini_attributes(category: str, technique: str, quality_score: float, hours: float) -> tuple[str, str, str]:
    """Derives craft complexity, finish quality, and uniqueness."""
    # Complexity
    if hours >= 7.0 or any(k in technique.lower() for k in ["etched", "jali", "inlay", "silk", "hand-carved"]):
        complexity = "intricate" if hours < 10.0 else "masterpiece"
    elif hours >= 3.5:
        complexity = "moderate"
    else:
        complexity = "simple"

    # Finish quality
    if quality_score >= 88.0:
        finish = "refined" if "glaze" in technique.lower() or "silk" in category.lower() else "polished"
    elif quality_score >= 75.0:
        finish = "smooth"
    else:
        finish = "raw"

    # Uniqueness
    if any(k in technique.lower() for k in ["pit-fired", "bidri", "dhokra", "channapatna"]):
        uniqueness = "heirloom"
    elif any(k in technique.lower() for k in ["wheel-thrown", "handloom", "carved"]):
        uniqueness = "regional"
    else:
        uniqueness = "standard"

    return complexity, finish, uniqueness

def load_seed_data() -> pd.DataFrame:
    df = pd.read_csv(DATASET_PATH)
    return df

def load_app_sold_data() -> pd.DataFrame:
    """Loads and formats the app's own sold/ordered prices from kalasetu.db."""
    if not DB_PATH.exists():
        return pd.DataFrame()

    try:
        con = sqlite3.connect(DB_PATH)
        query = """
            SELECT 
                LOWER(p.category) as category,
                p.cost_price,
                COALESCE(oi.unit_price, p.price) as final_price,
                o.created_at
            FROM orders o
            JOIN order_items oi ON oi.order_id = o.id
            JOIN products p ON p.id = oi.product_id
            WHERE o.status IN ('delivered', 'shipped', 'accepted', 'packed', 'confirmed', 'new')
        """
        sold_df = pd.read_sql_query(query, con)
        con.close()

        if sold_df.empty:
            return pd.DataFrame()

        records = []
        for _, row in sold_df.iterrows():
            cat = str(row["category"]).strip().lower()
            if cat not in ["pottery", "handloom", "jewelry", "wood craft", "bamboo"]:
                cat = "pottery"
            final_p = float(row["final_price"])
            cost_p = float(row["cost_price"]) if row["cost_price"] else (final_p * 0.45)
            # Reasonable estimation of material cost vs labour
            mat_cost = round(cost_p * 0.45, 1)
            labour_hrs = round(max(1.0, (cost_p * 0.55) / 95.0), 1)

            # Month from created_at
            month = 10
            try:
                if row["created_at"]:
                    month = pd.to_datetime(row["created_at"]).month
            except Exception:
                month = 10

            records.append({
                "category": cat,
                "material": "terracotta" if cat == "pottery" else ("cotton" if cat == "handloom" else "mixed"),
                "size_cm": 25.0,
                "technique": "handcrafted",
                "region": "IN",
                "material_cost": mat_cost,
                "labour_hours": labour_hrs,
                "final_price": final_p,
                "quality_score": 85.0,
                "_month": month,
            })
        return pd.DataFrame(records)
    except Exception as e:
        print(f"Notice: Could not load sold prices from DB ({e}), using seed dataset.")
        return pd.DataFrame()

def train():
    print("=" * 65)
    print("Training KalaSetu Dynamic Pricing Model (LightGBM)")
    print("=" * 65)

    if not DATASET_PATH.exists():
        raise FileNotFoundError(f"Dataset not found at {DATASET_PATH}")

    df_seed = load_seed_data()
    print(f"Loaded {len(df_seed)} seed samples from {DATASET_PATH.name}")

    df_sold = load_app_sold_data()
    if not df_sold.empty:
        print(f"Loaded {len(df_sold)} sold transaction records from app database {DB_PATH.name}")
        df = pd.concat([df_seed, df_sold], ignore_index=True)
    else:
        df = df_seed.copy()

    # Calculate Cost Floor for each item:
    # floor = material_cost + (labour_hours * 95) + 10% overhead
    df["cost_floor"] = df["material_cost"] + (df["labour_hours"] * 95.0)
    df["cost_floor"] = np.ceil(df["cost_floor"] * 1.10).astype(float)

    # Calculate Comparable Median per category & material
    cat_medians = df.groupby(["category"])["final_price"].median().to_dict()
    df["comparable_median"] = df["category"].map(cat_medians).fillna(df["final_price"].median()).astype(float)

    # Derive Gemini visual attributes
    complexities = []
    finishes = []
    uniquenesses = []
    for _, row in df.iterrows():
        c, f, u = derive_gemini_attributes(
            category=str(row["category"]),
            technique=str(row.get("technique", "handcrafted")),
            quality_score=float(row.get("quality_score", 80.0)),
            hours=float(row.get("labour_hours", 3.0)),
        )
        complexities.append(c)
        finishes.append(f)
        uniquenesses.append(u)

    df["craft_complexity"] = complexities
    df["finish_quality"] = finishes
    df["uniqueness"] = uniquenesses

    # Season factor
    months = df.get("_month", pd.Series([10] * len(df)))
    df["season_factor"] = [calculate_season_factor(m) for m in months]

    # Category mappings for LightGBM
    cat_mappings = {}
    for col in CATEGORICAL_COLS:
        unique_vals = sorted(df[col].dropna().unique().tolist())
        cat_mappings[col] = unique_vals
        df[col] = pd.Categorical(df[col], categories=unique_vals)

    # Train / Test split (80/20) with deterministic seed
    np.random.seed(42)
    indices = np.arange(len(df))
    np.random.shuffle(indices)
    split_idx = int(len(df) * 0.8)
    train_idx, test_idx = indices[:split_idx], indices[split_idx:]

    train_df = df.iloc[train_idx]
    test_df = df.iloc[test_idx]

    X_train = train_df[FEATURE_COLUMNS]
    y_train = train_df[TARGET]
    X_test = test_df[FEATURE_COLUMNS]
    y_test = test_df[TARGET]

    train_data = lgb.Dataset(X_train, label=y_train)
    test_data = lgb.Dataset(X_test, label=y_test, reference=train_data)

    params = {
        "objective": "regression",
        "metric": "rmse",
        "boosting_type": "gbdt",
        "learning_rate": 0.08,
        "num_leaves": 25,
        "min_child_samples": 4,
        "feature_fraction": 0.85,
        "verbose": -1,
        "random_state": 42
    }

    print("Fitting Gradient Boosting Model on combined dataset...")
    bst = lgb.train(
        params,
        train_data,
        num_boost_round=160,
        valid_sets=[test_data]
    )

    preds = bst.predict(X_test)
    mae = float(np.mean(np.abs(preds - y_test)))
    rmse = float(np.sqrt(np.mean((preds - y_test) ** 2)))
    ss_tot = np.sum((y_test - np.mean(y_test)) ** 2)
    ss_res = np.sum((y_test - preds) ** 2)
    r2 = float(1.0 - (ss_res / ss_tot)) if ss_tot > 0 else 0.0

    print("\nModel Evaluation Metrics:")
    print(f"  Total samples: {len(df)}")
    print(f"  R² Score:      {r2:.4f}")
    print(f"  MAE:           ₹{mae:.2f}")
    print(f"  RMSE:          ₹{rmse:.2f}")

    ARTIFACTS_DIR.mkdir(parents=True, exist_ok=True)
    model_path = ARTIFACTS_DIR / "pricing_model.txt"
    bst.save_model(str(model_path))
    print(f"\nModel artifact saved: {model_path.resolve()}")

    meta = {
        "version": "2.0.0",
        "algorithm": "LightGBM GradientBoostingRegressor",
        "num_samples": len(df),
        "r2_score": round(r2, 4),
        "mae": round(mae, 2),
        "rmse": round(rmse, 2),
        "feature_columns": FEATURE_COLUMNS,
        "categorical_columns": CATEGORICAL_COLS,
        "category_mappings": cat_mappings,
        "category_medians": cat_medians,
    }
    meta_path = ARTIFACTS_DIR / "model_meta.json"
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2)
    print(f"Metadata saved: {meta_path.resolve()}")
    print("=" * 65)

if __name__ == "__main__":
    train()

