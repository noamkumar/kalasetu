from pydantic import BaseModel, Field, ConfigDict
from typing import Optional, List, Dict, Any
from datetime import datetime

# --- Auth Schemas ---
class OTPSendRequest(BaseModel):
    phone: str = Field(..., description="10-digit mobile number")

class OTPSendResponse(BaseModel):
    message: str
    debug_otp: Optional[str] = None

class OTPVerifyRequest(BaseModel):
    phone: str
    otp: str

class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    is_new_user: bool = False

# --- Artisan Profile Schemas ---
class ArtisanBase(BaseModel):
    name: str = ""
    role: str = "artisan" # "artisan" or "buyer"
    craft_type: str = ""
    cluster_location: str = ""
    state: str = ""
    experience_years: Optional[int] = None
    pehchan_id: Optional[str] = None
    pehchan_photo_url: Optional[str] = None
    bank_account_holder: Optional[str] = None
    bank_account_number: Optional[str] = None
    bank_ifsc: Optional[str] = None
    bank_name: Optional[str] = None
    preferred_language: str = "en"

class ArtisanUpdate(BaseModel):
    name: Optional[str] = None
    role: Optional[str] = None
    craft_type: Optional[str] = None
    cluster_location: Optional[str] = None
    state: Optional[str] = None
    experience_years: Optional[int] = None
    pehchan_id: Optional[str] = None
    pehchan_photo_url: Optional[str] = None
    bank_account_holder: Optional[str] = None
    bank_account_number: Optional[str] = None
    bank_ifsc: Optional[str] = None
    bank_name: Optional[str] = None
    preferred_language: Optional[str] = None

class ArtisanResponse(ArtisanBase):
    id: str
    phone: str
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)

# --- Product & Translation Schemas ---
class TranslationIn(BaseModel):
    language_code: str
    title: str
    description: Optional[str] = None
    tags: Optional[str] = None
    materials: Optional[str] = None
    care_instructions: Optional[str] = None

class TranslationOut(TranslationIn):
    id: str

    model_config = ConfigDict(from_attributes=True)

class ProductCreate(BaseModel):
    category: str = "Pottery"
    price: float
    cost_price: Optional[float] = None
    status: str = "active"
    stock_quantity: int = 1
    primary_image_url: Optional[str] = None
    enhanced_image_url: Optional[str] = None
    original_audio_url: Optional[str] = None
    translations: List[TranslationIn] = []

class ProductUpdate(BaseModel):
    category: Optional[str] = None
    price: Optional[float] = None
    cost_price: Optional[float] = None
    status: Optional[str] = None
    stock_quantity: Optional[int] = None
    primary_image_url: Optional[str] = None
    enhanced_image_url: Optional[str] = None
    translations: Optional[List[TranslationIn]] = None

class ProductResponse(BaseModel):
    id: str
    artisan_id: str
    category: str
    price: float
    cost_price: Optional[float] = None
    status: str
    stock_quantity: int
    primary_image_url: Optional[str] = None
    enhanced_image_url: Optional[str] = None
    original_audio_url: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    # Localized fields
    title: str
    description: Optional[str] = None
    tags: Optional[str] = None
    materials: Optional[str] = None
    care_instructions: Optional[str] = None
    translations: List[TranslationOut] = []

    model_config = ConfigDict(from_attributes=True)

# --- Order Schemas ---
class OrderItemIn(BaseModel):
    product_id: str
    quantity: int = 1
    unit_price: Optional[float] = None

class OrderItemOut(BaseModel):
    id: str
    product_id: str
    quantity: int = 1
    unit_price: float

    model_config = ConfigDict(from_attributes=True)

class OrderEventOut(BaseModel):
    id: str
    order_id: str
    status: str
    note: Optional[str] = None
    tracking_id: Optional[str] = None
    courier_name: Optional[str] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

class OrderCreate(BaseModel):
    product_id: Optional[str] = None
    quantity: Optional[int] = 1
    unit_price: Optional[float] = None
    items: Optional[List[OrderItemIn]] = None
    customer_name: str
    customer_phone: str
    customer_address: str
    payment_method: str = "cash_on_delivery" # "cash_on_delivery" or "pay_later"
    buyer_id: Optional[str] = None

class OrderStatusUpdate(BaseModel):
    status: str
    tracking_id: Optional[str] = None
    courier_name: Optional[str] = None
    note: Optional[str] = None

class OrderTimelineStep(BaseModel):
    key: str
    label: str
    completed: bool
    current: bool
    timestamp: Optional[datetime] = None

class OrderResponse(BaseModel):
    id: str
    artisan_id: str
    buyer_id: Optional[str] = None
    customer_name: str
    customer_phone: str
    customer_address: str
    total_amount: float
    payment_method: str = "cash_on_delivery"
    status: str
    tracking_id: Optional[str] = None
    courier_name: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    items: List[OrderItemOut] = []
    events: List[OrderEventOut] = []
    timeline: List[OrderTimelineStep] = []

    model_config = ConfigDict(from_attributes=True)

# --- Marketplace & Notification Schemas ---
class MarketplaceProductsResponse(BaseModel):
    items: List[ProductResponse]
    total: int
    page: int
    limit: int
    total_pages: int

class NotificationResponse(BaseModel):
    id: str
    user_id: str
    order_id: Optional[str] = None
    title: str
    message: str
    type: str = "order_update"
    is_read: bool = False
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

# --- Sync Schemas ---
class SyncItem(BaseModel):
    client_id: str
    entity_type: str
    entity_id: str
    action: str
    payload: dict

class SyncPushRequest(BaseModel):
    items: List[SyncItem]

class SyncPushResponse(BaseModel):
    processed: int
    success: bool

class SyncPullRequest(BaseModel):
    last_pulled_at: Optional[datetime] = None

class SyncPullResponse(BaseModel):
    server_time: datetime
    products: List[ProductResponse]
    orders: List[OrderResponse]

# --- Assistant Schemas ---
class AssistantChatRequest(BaseModel):
    message: str
    current_screen: Optional[str] = "home"
    language: Optional[str] = "en"
    session_id: Optional[str] = None
    history: Optional[List[Dict[str, Any]]] = None
    image_id: Optional[str] = None

class AssistantChatResponse(BaseModel):
    reply: str
    action: str = "none" # "navigate" | "change_language" | "explain" | "edit_image" | "select_image" | "none"
    route: Optional[str] = None
    target_lang: Optional[str] = None
    suggestions: List[str] = []
    image_id: Optional[str] = None
    image_url: Optional[str] = None
    can_undo: bool = False
    can_redo: bool = False

# --- Analytics Schemas ---
class PopularCraftItem(BaseModel):
    category: str
    orders_count: int
    revenue: float

class DailyTrendPoint(BaseModel):
    date: str
    day: int
    revenue: float
    orders: int

class AnalyticsSummaryResponse(BaseModel):
    total_revenue: float
    total_orders: int
    pending_orders: int
    delivered_orders: int
    active_products: int
    popular_crafts: List[PopularCraftItem] = []
    trend_30_days: List[DailyTrendPoint] = []
