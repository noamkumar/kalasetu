from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from pydantic import BaseModel

from app.db.session import get_db
from app.models.db_models import Order, OrderItem, OrderEvent, Artisan, Product
from app.models.schemas import (
    OrderCreate, OrderResponse, OrderItemOut, OrderEventOut,
    OrderTimelineStep, OrderStatusUpdate
)
from app.services.auth_service import get_current_artisan, get_current_user_optional
from app.routers.notifications import create_notification

router = APIRouter(prefix="/orders", tags=["Orders"])

VALID_STATUSES = [
    "new", "pending", "accepted", "packed", "shipped", "delivered", "cancelled", "declined"
]

def _build_timeline(order: Order) -> List[OrderTimelineStep]:
    norm_status = order.status.lower().strip()
    if norm_status == "pending":
        norm_status = "new"

    # Terminal states
    if norm_status == "cancelled":
        return [
            OrderTimelineStep(
                key="new",
                label="Order Placed",
                completed=True,
                current=False,
                timestamp=order.created_at,
            ),
            OrderTimelineStep(
                key="cancelled",
                label="Order Cancelled",
                completed=True,
                current=True,
                timestamp=order.updated_at,
            ),
        ]

    if norm_status == "declined":
        return [
            OrderTimelineStep(
                key="new",
                label="Order Placed",
                completed=True,
                current=False,
                timestamp=order.created_at,
            ),
            OrderTimelineStep(
                key="declined",
                label="Order Declined",
                completed=True,
                current=True,
                timestamp=order.updated_at,
            ),
        ]

    steps_def = [
        ("new", "Order Placed"),
        ("accepted", "Accepted by Artisan"),
        ("packed", "Packed by Artisan"),
        ("shipped", f"Shipped ({order.courier_name or 'Courier'}: {order.tracking_id or 'In Transit'})" if order.tracking_id else "Shipped & Dispatched"),
        ("delivered", "Delivered to Customer"),
    ]

    status_order = ["new", "accepted", "packed", "shipped", "delivered"]
    curr_idx = status_order.index(norm_status) if norm_status in status_order else 0

    timeline = []
    # Build a lookup for event timestamps if available
    event_ts = {e.status.lower(): e.created_at for e in order.events} if order.events else {}

    for idx, (k, lbl) in enumerate(steps_def):
        is_completed = idx <= curr_idx
        is_current = idx == curr_idx
        ts = event_ts.get(k) or (order.created_at if idx == 0 else (order.updated_at if is_current else None))
        timeline.append(
            OrderTimelineStep(
                key=k,
                label=lbl,
                completed=is_completed,
                current=is_current,
                timestamp=ts,
            )
        )
    return timeline

def _build_order_response(order: Order) -> OrderResponse:
    items_out = [
        OrderItemOut(
            id=item.id,
            product_id=item.product_id,
            quantity=item.quantity,
            unit_price=item.unit_price,
        )
        for item in order.items
    ]
    events_out = [
        OrderEventOut(
            id=e.id,
            order_id=e.order_id,
            status=e.status,
            note=e.note,
            tracking_id=e.tracking_id,
            courier_name=e.courier_name,
            created_at=e.created_at,
        )
        for e in (order.events or [])
    ]

    return OrderResponse(
        id=order.id,
        artisan_id=order.artisan_id,
        buyer_id=order.buyer_id,
        customer_name=order.customer_name,
        customer_phone=order.customer_phone,
        customer_address=order.customer_address,
        total_amount=order.total_amount,
        payment_method=order.payment_method or "cash_on_delivery",
        status=order.status,
        tracking_id=order.tracking_id,
        courier_name=order.courier_name,
        created_at=order.created_at,
        updated_at=order.updated_at,
        items=items_out,
        events=events_out,
        timeline=_build_timeline(order),
    )

def _restore_order_stock(order: Order, db: Session):
    """Restore stock for cancelled or declined orders."""
    for item in order.items:
        prod = db.query(Product).filter(Product.id == item.product_id).first()
        if prod:
            prod.stock_quantity += item.quantity
            if prod.status == "sold_out" and prod.stock_quantity > 0:
                prod.status = "live"

@router.get("/notifications/unread-count")
@router.get("/unread-count")
def get_unread_order_count(
    current_artisan: Artisan = Depends(get_current_artisan),
    db: Session = Depends(get_db)
):
    count = db.query(Order).filter(
        Order.artisan_id == current_artisan.id,
        Order.status.in_(["new", "pending", "accepted"])
    ).count()
    return {"unread_count": count}

@router.get("", response_model=List[OrderResponse])
def list_orders(
    role: Optional[str] = Query(None, description="'artisan' or 'buyer'"),
    buyer_id: Optional[str] = Query(None, description="Filter by buyer ID"),
    current_user: Optional[Artisan] = Depends(get_current_user_optional),
    db: Session = Depends(get_db)
):
    query = db.query(Order)

    # If explicitly querying as buyer
    if (role == "buyer") or buyer_id or (current_user and current_user.role == "buyer"):
        target_buyer = buyer_id or (current_user.id if current_user else None)
        if target_buyer:
            query = query.filter(
                (Order.buyer_id == target_buyer) |
                ((Order.customer_phone == current_user.phone) if current_user else False)
            )
    elif current_user:
        # Defaults to artisan orders
        query = query.filter(Order.artisan_id == current_user.id)

    orders = query.order_by(Order.created_at.desc()).all()
    return [_build_order_response(o) for o in orders]

@router.get("/buyer", response_model=List[OrderResponse])
def list_buyer_orders(
    buyer_id: Optional[str] = Query(None),
    current_user: Optional[Artisan] = Depends(get_current_user_optional),
    db: Session = Depends(get_db)
):
    """Get all orders placed by the buyer."""
    target_id = buyer_id or (current_user.id if current_user else None)
    query = db.query(Order)
    if target_id:
        query = query.filter(
            (Order.buyer_id == target_id) |
            ((Order.customer_phone == current_user.phone) if current_user else False)
        )
    orders = query.order_by(Order.created_at.desc()).all()
    return [_build_order_response(o) for o in orders]

@router.get("/{order_id}", response_model=OrderResponse)
def get_order(
    order_id: str,
    db: Session = Depends(get_db)
):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    return _build_order_response(order)

@router.post("", response_model=OrderResponse, status_code=status.HTTP_201_CREATED)
def create_order(
    req: OrderCreate,
    current_user: Optional[Artisan] = Depends(get_current_user_optional),
    db: Session = Depends(get_db)
):
    """
    Place a new order.
    Validates stock availability, decreases quantity, marks sold_out when 0,
    creates order event timeline record and notifies the artisan.
    """
    # 1. Resolve ordered items list
    items_to_process = []
    if req.items and len(req.items) > 0:
        for item_in in req.items:
            items_to_process.append((item_in.product_id, item_in.quantity, item_in.unit_price))
    elif req.product_id:
        items_to_process.append((req.product_id, req.quantity or 1, req.unit_price))
    else:
        raise HTTPException(status_code=400, detail="Order must contain at least one item or a product_id")

    # 2. Check stock and determine artisan ID
    resolved_items = []
    total = 0.0
    target_artisan_id = None

    for prod_id, qty, u_price in items_to_process:
        product = db.query(Product).filter(Product.id == prod_id).first()
        if not product:
            raise HTTPException(status_code=404, detail=f"Product '{prod_id}' not found")
        if product.stock_quantity < qty:
            raise HTTPException(
                status_code=400,
                detail=f"Insufficient stock for product. Only {product.stock_quantity} remaining."
            )

        unit_cost = u_price if u_price is not None else product.price
        total += qty * unit_cost
        target_artisan_id = product.artisan_id

        # Decrease stock quantity
        product.stock_quantity -= qty
        if product.stock_quantity <= 0:
            product.stock_quantity = 0
            product.status = "sold_out"

        resolved_items.append((prod_id, qty, unit_cost))

    # 3. Associate buyer ID
    buyer_id = req.buyer_id or (current_user.id if current_user else None)

    order = Order(
        artisan_id=target_artisan_id,
        buyer_id=buyer_id,
        customer_name=req.customer_name,
        customer_phone=req.customer_phone,
        customer_address=req.customer_address,
        total_amount=total,
        payment_method=req.payment_method or "cash_on_delivery",
        status="new",
    )
    db.add(order)
    db.flush()

    # 4. Create OrderItems
    for prod_id, qty, unit_cost in resolved_items:
        item = OrderItem(
            order_id=order.id,
            product_id=prod_id,
            quantity=qty,
            unit_price=unit_cost,
        )
        db.add(item)

    # 5. Create initial OrderEvent
    initial_event = OrderEvent(
        order_id=order.id,
        status="new",
        note="Order placed by buyer",
    )
    db.add(initial_event)
    db.commit()
    db.refresh(order)

    # 6. Send Notification to artisan
    short_id = order.id[:6].upper()
    create_notification(
        db=db,
        user_id=target_artisan_id,
        order_id=order.id,
        title="New Order Received",
        message=f"New order #{short_id} received for ₹{total:.0f} from {req.customer_name}.",
        type="order_new",
    )

    return _build_order_response(order)

@router.patch("/{order_id}/accept", response_model=OrderResponse)
def accept_order(
    order_id: str,
    db: Session = Depends(get_db)
):
    """Artisan endpoint to accept a new order."""
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    if order.status not in ["new", "pending"]:
        raise HTTPException(status_code=400, detail=f"Cannot accept order in status '{order.status}'")

    order.status = "accepted"
    event = OrderEvent(
        order_id=order.id,
        status="accepted",
        note="Order accepted by artisan",
    )
    db.add(event)
    db.commit()
    db.refresh(order)

    short_id = order.id[:6].upper()
    if order.buyer_id:
        create_notification(
            db=db,
            user_id=order.buyer_id,
            order_id=order.id,
            title="Order Accepted",
            message=f"Your order #{short_id} has been accepted by the artisan.",
            type="order_accepted",
        )

    return _build_order_response(order)

@router.patch("/{order_id}/decline", response_model=OrderResponse)
def decline_order(
    order_id: str,
    db: Session = Depends(get_db)
):
    """Artisan endpoint to decline a new order and restore inventory."""
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    if order.status not in ["new", "pending"]:
        raise HTTPException(status_code=400, detail=f"Cannot decline order in status '{order.status}'")

    order.status = "declined"
    _restore_order_stock(order, db)

    event = OrderEvent(
        order_id=order.id,
        status="declined",
        note="Order declined by artisan",
    )
    db.add(event)
    db.commit()
    db.refresh(order)

    short_id = order.id[:6].upper()
    if order.buyer_id:
        create_notification(
            db=db,
            user_id=order.buyer_id,
            order_id=order.id,
            title="Order Declined",
            message=f"Your order #{short_id} was declined by the artisan.",
            type="order_declined",
        )

    return _build_order_response(order)

@router.patch("/{order_id}/cancel", response_model=OrderResponse)
def cancel_order(
    order_id: str,
    db: Session = Depends(get_db)
):
    """
    Cancel order before shipping. Restores stock.
    Allowed only when status is new, accepted, or packed.
    """
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    if order.status in ["shipped", "delivered"]:
        raise HTTPException(
            status_code=400,
            detail="Cannot cancel order after it has been shipped or delivered"
        )
    if order.status in ["cancelled", "declined"]:
        raise HTTPException(status_code=400, detail=f"Order is already {order.status}")

    order.status = "cancelled"
    _restore_order_stock(order, db)

    event = OrderEvent(
        order_id=order.id,
        status="cancelled",
        note="Order cancelled before shipping",
    )
    db.add(event)
    db.commit()
    db.refresh(order)

    short_id = order.id[:6].upper()
    # Notify artisan
    create_notification(
        db=db,
        user_id=order.artisan_id,
        order_id=order.id,
        title="Order Cancelled",
        message=f"Order #{short_id} was cancelled by the buyer.",
        type="order_cancelled",
    )
    # Notify buyer if exists
    if order.buyer_id:
        create_notification(
            db=db,
            user_id=order.buyer_id,
            order_id=order.id,
            title="Order Cancelled",
            message=f"Your order #{short_id} has been cancelled successfully.",
            type="order_cancelled",
        )

    return _build_order_response(order)

@router.patch("/{order_id}/status", response_model=OrderResponse)
@router.put("/{order_id}/status", response_model=OrderResponse)
def update_order_status(
    order_id: str,
    req: OrderStatusUpdate,
    db: Session = Depends(get_db)
):
    norm_status = req.status.lower().strip()
    if norm_status not in VALID_STATUSES:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid status '{req.status}'. Must be one of: {', '.join(VALID_STATUSES)}"
        )

    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    if norm_status in ["cancelled", "declined"] and order.status not in ["cancelled", "declined"]:
        _restore_order_stock(order, db)

    order.status = norm_status
    if req.tracking_id:
        order.tracking_id = req.tracking_id
    if req.courier_name:
        order.courier_name = req.courier_name

    note_text = req.note or f"Status updated to {norm_status}"
    if norm_status == "shipped" and req.tracking_id:
        note_text = f"Shipped via {req.courier_name or 'Courier'} (Tracking: {req.tracking_id})"

    event = OrderEvent(
        order_id=order.id,
        status=norm_status,
        note=note_text,
        tracking_id=req.tracking_id or order.tracking_id,
        courier_name=req.courier_name or order.courier_name,
    )
    db.add(event)
    db.commit()
    db.refresh(order)

    # Send Notification to buyer on each status change
    short_id = order.id[:6].upper()
    status_messages = {
        "packed": f"Your order #{short_id} has been packed and is ready for courier pickup.",
        "shipped": f"Your order #{short_id} has been shipped via {order.courier_name or 'courier'}. Tracking: {order.tracking_id or 'N/A'}",
        "delivered": f"Your order #{short_id} has been delivered. Thank you!",
        "accepted": f"Your order #{short_id} has been accepted by the artisan.",
        "cancelled": f"Your order #{short_id} was cancelled.",
        "declined": f"Your order #{short_id} was declined.",
    }

    if order.buyer_id and norm_status in status_messages:
        create_notification(
            db=db,
            user_id=order.buyer_id,
            order_id=order.id,
            title=f"Order {norm_status.capitalize()}",
            message=status_messages[norm_status],
            type=f"order_{norm_status}",
        )

    return _build_order_response(order)
