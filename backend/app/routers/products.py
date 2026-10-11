from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from sqlalchemy import or_

from app.db.session import get_db
from app.models.db_models import Product, ProductTranslation, Artisan
from app.models.schemas import (
    ProductCreate, ProductUpdate, ProductResponse, TranslationOut
)
from app.services.auth_service import get_current_artisan

router = APIRouter(prefix="/products", tags=["Products"])

def build_product_response(product: Product, lang: str = "en") -> ProductResponse:
    # Find matching translation for requested lang
    matching = None
    en_trans = None
    for t in product.translations:
        if t.language_code == lang:
            matching = t
            break
        if t.language_code == "en":
            en_trans = t

    target = matching or en_trans or (product.translations[0] if product.translations else None)

    title = target.title if target else f"Product #{product.id[:6]}"
    description = target.description if target else None
    tags = target.tags if target else None
    materials = target.materials if target else None
    care_instructions = target.care_instructions if target else None

    trans_out = [
        TranslationOut(
            id=t.id,
            language_code=t.language_code,
            title=t.title,
            description=t.description,
            tags=t.tags,
            materials=t.materials,
            care_instructions=t.care_instructions,
        )
        for t in product.translations
    ]

    return ProductResponse(
        id=product.id,
        artisan_id=product.artisan_id,
        category=product.category,
        price=product.price,
        cost_price=product.cost_price,
        status=product.status,
        stock_quantity=product.stock_quantity,
        primary_image_url=product.primary_image_url,
        enhanced_image_url=product.enhanced_image_url,
        original_audio_url=product.original_audio_url,
        created_at=product.created_at,
        updated_at=product.updated_at,
        title=title,
        description=description,
        tags=tags,
        materials=materials,
        care_instructions=care_instructions,
        translations=trans_out,
    )

_build_product_response = build_product_response

@router.get("", response_model=List[ProductResponse])
def list_products(
    lang: str = Query("en", description="Language code for localized titles/descriptions"),
    category: Optional[str] = Query(None, description="Filter by category"),
    search: Optional[str] = Query(None, description="Search term in title or description"),
    artisan_id: Optional[str] = Query(None, description="Filter by artisan ID"),
    db: Session = Depends(get_db)
):
    query = db.query(Product)
    if artisan_id:
        query = query.filter(Product.artisan_id == artisan_id)
    else:
        query = query.filter(Product.status.in_(["live", "active"]))

    if category and category.lower() != "all":
        query = query.filter(Product.category.ilike(f"%{category}%"))
    if search:
        search_filter = f"%{search.strip()}%"
        query = query.join(Product.translations).filter(
            or_(
                ProductTranslation.title.ilike(search_filter),
                ProductTranslation.description.ilike(search_filter)
            )
        ).distinct()

    products = query.order_by(Product.created_at.desc()).all()
    return [build_product_response(p, lang=lang) for p in products]

@router.get("/{product_id}", response_model=ProductResponse)
def get_product(
    product_id: str,
    lang: str = Query("en"),
    db: Session = Depends(get_db)
):
    product = db.query(Product).filter(Product.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    return build_product_response(product, lang=lang)

@router.post("", response_model=ProductResponse, status_code=status.HTTP_201_CREATED)
def create_product(
    req: ProductCreate,
    current_artisan: Artisan = Depends(get_current_artisan),
    db: Session = Depends(get_db)
):
    status_val = "live" if req.status in ["active", "live", ""] else req.status
    product = Product(
        artisan_id=current_artisan.id,
        category=req.category,
        price=req.price,
        cost_price=req.cost_price,
        status=status_val,
        stock_quantity=req.stock_quantity,
        primary_image_url=req.primary_image_url,
        enhanced_image_url=req.enhanced_image_url,
        original_audio_url=req.original_audio_url,
    )
    db.add(product)
    db.flush()

    for t_in in req.translations:
        translation = ProductTranslation(
            product_id=product.id,
            language_code=t_in.language_code,
            title=t_in.title,
            description=t_in.description,
            tags=t_in.tags,
            materials=t_in.materials,
            care_instructions=t_in.care_instructions,
        )
        db.add(translation)

    db.commit()
    db.refresh(product)
    return _build_product_response(product, lang="en")

@router.patch("/{product_id}", response_model=ProductResponse)
def update_product(
    product_id: str,
    req: ProductUpdate,
    current_artisan: Artisan = Depends(get_current_artisan),
    db: Session = Depends(get_db)
):
    product = db.query(Product).filter(
        Product.id == product_id,
        Product.artisan_id == current_artisan.id
    ).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found or not owned by you")

    for field, value in req.model_dump(exclude={"translations"}, exclude_unset=True).items():
        setattr(product, field, value)

    if req.translations is not None:
        for t_in in req.translations:
            existing = db.query(ProductTranslation).filter(
                ProductTranslation.product_id == product.id,
                ProductTranslation.language_code == t_in.language_code
            ).first()
            if existing:
                existing.title = t_in.title
                existing.description = t_in.description
                existing.tags = t_in.tags
                existing.materials = t_in.materials
                existing.care_instructions = t_in.care_instructions
            else:
                db.add(ProductTranslation(
                    product_id=product.id,
                    language_code=t_in.language_code,
                    title=t_in.title,
                    description=t_in.description,
                    tags=t_in.tags,
                    materials=t_in.materials,
                    care_instructions=t_in.care_instructions,
                ))

    db.commit()
    db.refresh(product)
    return _build_product_response(product, lang="en")

@router.delete("/{product_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_product(
    product_id: str,
    current_artisan: Artisan = Depends(get_current_artisan),
    db: Session = Depends(get_db)
):
    product = db.query(Product).filter(
        Product.id == product_id,
        Product.artisan_id == current_artisan.id
    ).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found or not owned by you")

    db.delete(product)
    db.commit()
    return None
