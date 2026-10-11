import math
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import or_

from app.db.session import get_db
from app.models.db_models import Product, ProductTranslation
from app.models.schemas import ProductResponse, MarketplaceProductsResponse
from app.routers.products import build_product_response

router = APIRouter(prefix="/marketplace", tags=["Marketplace"])

@router.get("/products", response_model=MarketplaceProductsResponse)
def list_marketplace_products(
    lang: str = Query("en", description="Language code for localized titles/descriptions"),
    category: Optional[str] = Query(None, description="Filter by craft category"),
    search: Optional[str] = Query(None, description="Search term in title or description"),
    page: int = Query(1, ge=1, description="Page number"),
    limit: int = Query(20, ge=1, le=100, description="Items per page"),
    db: Session = Depends(get_db)
):
    """
    Public marketplace product catalog.
    Returns paginated, localized products that are currently 'live'.
    """
    query = db.query(Product).filter(Product.status.in_(["live", "active"]))

    if category and category.lower() != "all":
        query = query.filter(Product.category.ilike(f"%{category.strip()}%"))

    if search and search.strip():
        search_filter = f"%{search.strip()}%"
        query = query.join(Product.translations).filter(
            or_(
                ProductTranslation.title.ilike(search_filter),
                ProductTranslation.description.ilike(search_filter)
            )
        ).distinct()

    total = query.count()
    total_pages = math.ceil(total / limit) if total > 0 else 1

    products = (
        query.order_by(Product.created_at.desc())
        .offset((page - 1) * limit)
        .limit(limit)
        .all()
    )

    items = [build_product_response(p, lang=lang) for p in products]

    return MarketplaceProductsResponse(
        items=items,
        total=total,
        page=page,
        limit=limit,
        total_pages=total_pages,
    )

@router.get("/products/{product_id}", response_model=ProductResponse)
def get_marketplace_product(
    product_id: str,
    lang: str = Query("en", description="Language code"),
    db: Session = Depends(get_db)
):
    """
    Public product details endpoint localized for buyer.
    """
    product = db.query(Product).filter(
        Product.id == product_id,
        Product.status.in_(["live", "active", "sold_out"])
    ).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found in marketplace")
    return build_product_response(product, lang=lang)
