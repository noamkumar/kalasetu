from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models.db_models import Notification, Artisan
from app.models.schemas import NotificationResponse
from app.services.auth_service import get_current_user_optional

router = APIRouter(prefix="/notifications", tags=["Notifications"])

def create_notification(
    db: Session,
    user_id: str,
    title: str,
    message: str,
    order_id: Optional[str] = None,
    type: str = "order_update",
) -> Notification:
    notif = Notification(
        user_id=user_id,
        order_id=order_id,
        title=title,
        message=message,
        type=type,
        is_read=0,
    )
    db.add(notif)
    db.commit()
    db.refresh(notif)
    return notif

@router.get("", response_model=List[NotificationResponse])
def list_notifications(
    user_id: Optional[str] = Query(None, description="Optional user ID filter"),
    current_user: Optional[Artisan] = Depends(get_current_user_optional),
    db: Session = Depends(get_db)
):
    target_id = user_id or (current_user.id if current_user else None)
    query = db.query(Notification)
    if target_id:
        query = query.filter(Notification.user_id == target_id)
    notifs = query.order_by(Notification.created_at.desc()).limit(50).all()

    return [
        NotificationResponse(
            id=n.id,
            user_id=n.user_id,
            order_id=n.order_id,
            title=n.title,
            message=n.message,
            type=n.type,
            is_read=bool(n.is_read),
            created_at=n.created_at,
        )
        for n in notifs
    ]

@router.get("/unread-count")
def get_unread_count(
    user_id: Optional[str] = Query(None),
    current_user: Optional[Artisan] = Depends(get_current_user_optional),
    db: Session = Depends(get_db)
):
    target_id = user_id or (current_user.id if current_user else None)
    query = db.query(Notification).filter(Notification.is_read == 0)
    if target_id:
        query = query.filter(Notification.user_id == target_id)
    count = query.count()
    return {"unread_count": count}

@router.patch("/{notification_id}/read", response_model=NotificationResponse)
def mark_notification_read(
    notification_id: str,
    db: Session = Depends(get_db)
):
    notif = db.query(Notification).filter(Notification.id == notification_id).first()
    if not notif:
        raise HTTPException(status_code=404, detail="Notification not found")
    notif.is_read = 1
    db.commit()
    db.refresh(notif)
    return NotificationResponse(
        id=notif.id,
        user_id=notif.user_id,
        order_id=notif.order_id,
        title=notif.title,
        message=notif.message,
        type=notif.type,
        is_read=True,
        created_at=notif.created_at,
    )

@router.patch("/read-all")
def mark_all_read(
    user_id: Optional[str] = Query(None),
    current_user: Optional[Artisan] = Depends(get_current_user_optional),
    db: Session = Depends(get_db)
):
    target_id = user_id or (current_user.id if current_user else None)
    query = db.query(Notification).filter(Notification.is_read == 0)
    if target_id:
        query = query.filter(Notification.user_id == target_id)
    query.update({"is_read": 1})
    db.commit()
    return {"status": "ok", "message": "All marked as read"}
