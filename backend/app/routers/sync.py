import json
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models.db_models import Product, Order, SyncRecord, Artisan, ProductTranslation, OrderItem
from app.models.schemas import (
    SyncPushRequest, SyncPushResponse, SyncPullRequest, SyncPullResponse
)
from app.services.auth_service import get_current_artisan
from app.routers.products import _build_product_response
from app.routers.orders import _build_order_response

router = APIRouter(prefix="/sync", tags=["Sync"])

@router.post("/push", response_model=SyncPushResponse)
def sync_push(
    req: SyncPushRequest,
    current_artisan: Artisan = Depends(get_current_artisan),
    db: Session = Depends(get_db)
):
    processed = 0
    for item in req.items:
        # Save audit record in SyncRecord
        record = SyncRecord(
            client_id=item.client_id,
            entity_type=item.entity_type,
            entity_id=item.entity_id,
            action=item.action,
            payload=json.dumps(item.payload),
            status="applied",
        )
        db.add(record)

        # Apply product change
        if item.entity_type == "product":
            p_data = item.payload
            if item.action in ("create", "update"):
                existing = db.query(Product).filter(Product.id == item.entity_id).first()
                if not existing:
                    existing = Product(
                        id=item.entity_id,
                        artisan_id=current_artisan.id,
                        category=p_data.get("category", "Pottery"),
                        price=float(p_data.get("price", 0.0)),
                        cost_price=float(p_data["cost_price"]) if p_data.get("cost_price") else None,
                        status=p_data.get("status", "active"),
                        stock_quantity=int(p_data.get("stock_quantity", 1)),
                        primary_image_url=p_data.get("primary_image_url"),
                        enhanced_image_url=p_data.get("enhanced_image_url"),
                    )
                    db.add(existing)
                    db.flush()
                else:
                    existing.category = p_data.get("category", existing.category)
                    existing.price = float(p_data.get("price", existing.price))
                    existing.cost_price = float(p_data["cost_price"]) if p_data.get("cost_price") else existing.cost_price
                    existing.status = p_data.get("status", existing.status)
                    existing.stock_quantity = int(p_data.get("stock_quantity", existing.stock_quantity))

                # Handle translations in payload
                for t in p_data.get("translations", []):
                    lang = t.get("language_code", "en")
                    trans = db.query(ProductTranslation).filter(
                        ProductTranslation.product_id == existing.id,
                        ProductTranslation.language_code == lang
                    ).first()
                    if not trans:
                        trans = ProductTranslation(
                            product_id=existing.id,
                            language_code=lang,
                            title=t.get("title", "Untitled"),
                            description=t.get("description"),
                            tags=t.get("tags"),
                            materials=t.get("materials"),
                            care_instructions=t.get("care_instructions"),
                        )
                        db.add(trans)
                    else:
                        trans.title = t.get("title", trans.title)
                        trans.description = t.get("description", trans.description)
            elif item.action == "delete":
                existing = db.query(Product).filter(
                    Product.id == item.entity_id,
                    Product.artisan_id == current_artisan.id
                ).first()
                if existing:
                    db.delete(existing)

        processed += 1

    db.commit()
    return SyncPushResponse(processed=processed, success=True)

@router.post("/pull", response_model=SyncPullResponse)
def sync_pull(
    req: SyncPullRequest,
    current_artisan: Artisan = Depends(get_current_artisan),
    db: Session = Depends(get_db)
):
    query_p = db.query(Product).filter(Product.status == "active")
    query_o = db.query(Order).filter(Order.artisan_id == current_artisan.id)

    if req.last_pulled_at:
        query_p = query_p.filter(Product.updated_at >= req.last_pulled_at)
        query_o = query_o.filter(Order.updated_at >= req.last_pulled_at)

    products = query_p.all()
    orders = query_o.all()

    return SyncPullResponse(
        server_time=datetime.now(timezone.utc),
        products=[_build_product_response(p, lang="en") for p in products],
        orders=[_build_order_response(o) for o in orders],
    )
