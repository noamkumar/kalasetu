from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.models.db_models import Artisan
from app.models.schemas import (
    OTPSendRequest, OTPSendResponse, OTPVerifyRequest, TokenResponse,
    ArtisanResponse, ArtisanUpdate
)
from app.services.auth_service import (
    send_otp, verify_otp, normalize_phone, is_demo_phone,
    create_access_token, create_refresh_token,
    get_current_artisan
)
from app.config import get_settings

router = APIRouter(prefix="", tags=["Auth"])
settings = get_settings()

@router.post("/auth/otp/send", response_model=OTPSendResponse)
def handle_send_otp(req: OTPSendRequest):
    phone = req.phone.strip().replace(" ", "").replace("-", "")
    if len(phone) < 10:
        raise HTTPException(status_code=400, detail="Invalid phone number format")
    norm = normalize_phone(phone)
    otp = send_otp(norm)
    debug_hint = otp if (settings.APP_ENV == "development" or is_demo_phone(norm)) else None
    return OTPSendResponse(
        message="OTP sent successfully",
        debug_otp=debug_hint
    )

@router.post("/auth/otp/verify", response_model=TokenResponse)
def handle_verify_otp(req: OTPVerifyRequest, db: Session = Depends(get_db)):
    phone = req.phone.strip().replace(" ", "").replace("-", "")
    if len(phone) < 10:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid phone number format"
        )
    norm = normalize_phone(phone)
    if not verify_otp(norm, req.otp):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired OTP code"
        )
    # Find or create artisan matching normalized, raw 10-digit, or entered format
    raw_10 = norm[3:] if norm.startswith("+91") else norm
    artisan = db.query(Artisan).filter(
        (Artisan.phone == norm) | (Artisan.phone == phone) | (Artisan.phone == raw_10)
    ).first()
    is_new_user = False
    if not artisan:
        is_new_user = True
        artisan = Artisan(phone=phone)
        db.add(artisan)
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
