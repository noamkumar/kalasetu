import uuid
from datetime import datetime, timezone
from sqlalchemy import (
    Column, String, Integer, Float, DateTime, ForeignKey, UniqueConstraint, Text
)
from sqlalchemy.orm import relationship
from app.db.base import Base

def generate_uuid() -> str:
    return str(uuid.uuid4())

def utc_now() -> datetime:
    return datetime.now(timezone.utc)

class Artisan(Base):
    __tablename__ = "artisans"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    phone = Column(String(20), unique=True, index=True, nullable=False)
    name = Column(String(100), nullable=False, default="")
    role = Column(String(20), nullable=False, default="artisan") # "artisan" or "buyer"
    craft_type = Column(String(50), nullable=False, default="")
    cluster_location = Column(String(120), nullable=False, default="")
    state = Column(String(60), nullable=False, default="")
    experience_years = Column(Integer, nullable=True)
    pehchan_id = Column(String(50), nullable=True)
    pehchan_photo_url = Column(String(255), nullable=True)
    bank_account_holder = Column(String(100), nullable=True)
    bank_account_number = Column(String(50), nullable=True)
    bank_ifsc = Column(String(20), nullable=True)
    bank_name = Column(String(100), nullable=True)
    preferred_language = Column(String(10), default="en", nullable=False)
    created_at = Column(DateTime(timezone=True), default=utc_now, nullable=False)
    updated_at = Column(DateTime(timezone=True), default=utc_now, onupdate=utc_now, nullable=False)

    products = relationship("Product", back_populates="artisan", cascade="all, delete-orphan")
    orders = relationship("Order", foreign_keys="Order.artisan_id", back_populates="artisan", cascade="all, delete-orphan")

class Product(Base):
    __tablename__ = "products"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    artisan_id = Column(String(36), ForeignKey("artisans.id"), nullable=False, index=True)
    category = Column(String(50), nullable=False, default="Pottery")
    price = Column(Float, nullable=False, default=0.0)
    cost_price = Column(Float, nullable=True)
    status = Column(String(20), nullable=False, default="live") # draft, pending_sync, live, sold_out, removed
    stock_quantity = Column(Integer, nullable=False, default=1)
    primary_image_url = Column(String(255), nullable=True)
    enhanced_image_url = Column(String(255), nullable=True)
    original_audio_url = Column(String(255), nullable=True)
    created_at = Column(DateTime(timezone=True), default=utc_now, nullable=False)
    updated_at = Column(DateTime(timezone=True), default=utc_now, onupdate=utc_now, nullable=False)

    artisan = relationship("Artisan", back_populates="products")
    translations = relationship("ProductTranslation", back_populates="product", cascade="all, delete-orphan")
    order_items = relationship("OrderItem", back_populates="product")

class ProductTranslation(Base):
    __tablename__ = "product_translations"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    product_id = Column(String(36), ForeignKey("products.id", ondelete="CASCADE"), nullable=False, index=True)
    language_code = Column(String(10), nullable=False, index=True)
    title = Column(String(200), nullable=False)
    description = Column(Text, nullable=True)
    tags = Column(String(255), nullable=True)
    materials = Column(String(255), nullable=True)
    care_instructions = Column(Text, nullable=True)

    __table_args__ = (
        UniqueConstraint("product_id", "language_code", name="uq_product_language"),
    )

    product = relationship("Product", back_populates="translations")

class Order(Base):
    __tablename__ = "orders"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    artisan_id = Column(String(36), ForeignKey("artisans.id"), nullable=False, index=True)
    buyer_id = Column(String(36), ForeignKey("artisans.id"), nullable=True, index=True)
    customer_name = Column(String(100), nullable=False)
    customer_phone = Column(String(20), nullable=False)
    customer_address = Column(Text, nullable=False)
    total_amount = Column(Float, nullable=False, default=0.0)
    payment_method = Column(String(30), nullable=False, default="cash_on_delivery") # cash_on_delivery or pay_later
    status = Column(String(20), nullable=False, default="new") # new, accepted, packed, shipped, delivered, cancelled, declined
    tracking_id = Column(String(100), nullable=True)
    courier_name = Column(String(100), nullable=True)
    created_at = Column(DateTime(timezone=True), default=utc_now, nullable=False)
    updated_at = Column(DateTime(timezone=True), default=utc_now, onupdate=utc_now, nullable=False)

    artisan = relationship("Artisan", foreign_keys=[artisan_id], back_populates="orders")
    items = relationship("OrderItem", back_populates="order", cascade="all, delete-orphan")
    events = relationship("OrderEvent", back_populates="order", cascade="all, delete-orphan", order_by="OrderEvent.created_at")

class OrderItem(Base):
    __tablename__ = "order_items"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    order_id = Column(String(36), ForeignKey("orders.id", ondelete="CASCADE"), nullable=False, index=True)
    product_id = Column(String(36), ForeignKey("products.id"), nullable=False)
    quantity = Column(Integer, nullable=False, default=1)
    unit_price = Column(Float, nullable=False, default=0.0)

    order = relationship("Order", back_populates="items")
    product = relationship("Product", back_populates="order_items")

class OrderEvent(Base):
    __tablename__ = "order_events"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    order_id = Column(String(36), ForeignKey("orders.id", ondelete="CASCADE"), nullable=False, index=True)
    status = Column(String(30), nullable=False)
    note = Column(Text, nullable=True)
    tracking_id = Column(String(100), nullable=True)
    courier_name = Column(String(100), nullable=True)
    created_at = Column(DateTime(timezone=True), default=utc_now, nullable=False)

    order = relationship("Order", back_populates="events")

class Notification(Base):
    __tablename__ = "notifications"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    user_id = Column(String(36), nullable=False, index=True)
    order_id = Column(String(36), nullable=True, index=True)
    title = Column(String(150), nullable=False)
    message = Column(Text, nullable=False)
    type = Column(String(50), nullable=False, default="order_update")
    is_read = Column(Integer, default=0, nullable=False)
    created_at = Column(DateTime(timezone=True), default=utc_now, nullable=False)

class SyncRecord(Base):
    __tablename__ = "sync_records"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    client_id = Column(String(64), nullable=False, index=True)
    entity_type = Column(String(30), nullable=False)
    entity_id = Column(String(36), nullable=False)
    action = Column(String(20), nullable=False)
    payload = Column(Text, nullable=False)
    status = Column(String(20), nullable=False, default="applied")
    synced_at = Column(DateTime(timezone=True), default=utc_now, nullable=False)
