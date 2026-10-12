import logging
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.models.db_models import Artisan
from app.models.schemas import (
    OTPSendRequest, OTPSendResponse, OTPVerifyRequest, TokenResponse,
    ArtisanResponse, ArtisanUpdate
)
from app.services.auth_service import (
    send_otp, verify_otp, normalize_phone, validate_and_normalize_phone,
    is_demo_phone, is_demo_mode_active, mask_phone,
    create_access_token, create_refresh_token,
    get_current_artisan
)
from app.config import get_settings

logger = logging.getLogger("kalasetu.auth")
router = APIRouter(prefix="", tags=["Auth"])
settings = get_settings()

@router.post("/auth/otp/send", response_model=OTPSendResponse)
def handle_send_otp(req: OTPSendRequest):
    try:
        norm = validate_and_normalize_phone(req.phone)
    except ValueError as e:
        logger.warning(f"[AUTH OTP SEND REJECTED] Phone format error: {e}")
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

    is_demo = is_demo_phone(norm)
    demo_mode = is_demo_mode_active()
    logger.info(
        f"[AUTH OTP SEND] Phone: {mask_phone(norm)} | "
        f"Is demo account: {is_demo} | Demo mode: {demo_mode}"
    )
    otp = send_otp(norm)

    if demo_mode or is_demo:
        message = "Demo mode: Enter 123456 to continue"
        debug_hint = "123456"
    else:
        message = "OTP sent successfully"
        debug_hint = None

    return OTPSendResponse(
        message=message,
        debug_otp=debug_hint
    )

@router.post("/auth/otp/verify", response_model=TokenResponse)
def handle_verify_otp(req: OTPVerifyRequest, db: Session = Depends(get_db)):
    try:
        norm = validate_and_normalize_phone(req.phone)
    except ValueError as e:
        logger.warning(f"[AUTH OTP VERIFY REJECTED] Phone format error: {e}")
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

    is_demo = is_demo_phone(norm)
    demo_mode = is_demo_mode_active()
    logger.info(
        f"[AUTH OTP VERIFY] Phone: {mask_phone(norm)} | "
        f"Is demo account: {is_demo} | Demo mode: {demo_mode}"
    )
    is_valid = verify_otp(norm, req.otp)
    if not is_valid:
        logger.warning(
            f"[AUTH OTP VERIFY REJECTED] Phone: {mask_phone(norm)} | Is demo: {is_demo} | "
            f"Reason: code mismatch or expired"
        )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired OTP code"
        )
    logger.info(f"[AUTH OTP VERIFY ACCEPTED] Phone: {mask_phone(norm)} | Is demo: {is_demo}")

    # Find or create artisan matching normalized, raw 10-digit, or entered format
    raw_10 = norm[3:] if norm.startswith("+91") else norm
    artisan = db.query(Artisan).filter(
        (Artisan.phone == norm) | (Artisan.phone == req.phone) | (Artisan.phone == raw_10)
    ).first()
    is_new_user = False
    if not artisan:
        is_new_user = True
        artisan = Artisan(phone=norm)
        db.add(artisan)
        db.commit()
        db.refresh(artisan)
    else:
        # Prevent duplicate user accounts by consolidating to normalized E.164
        if artisan.phone != norm:
            artisan.phone = norm
            db.commit()
            db.refresh(artisan)

    access_token = create_access_token(data={"sub": artisan.id, "phone": artisan.phone})
    refresh_token = create_refresh_token(data={"sub": artisan.id, "phone": artisan.phone})

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        is_new_user=is_new_user
    )

@router.get("/me", response_model=ArtisanResponse)
def get_my_profile(current_artisan: Artisan = Depends(get_current_artisan)):
    return current_artisan

@router.patch("/me", response_model=ArtisanResponse)
def update_my_profile(
    update_data: ArtisanUpdate,
    current_artisan: Artisan = Depends(get_current_artisan),
    db: Session = Depends(get_db)
):
    for field, value in update_data.model_dump(exclude_unset=True).items():
        setattr(current_artisan, field, value)
    db.commit()
    db.refresh(current_artisan)
    return current_artisan
