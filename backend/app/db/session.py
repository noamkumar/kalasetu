from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, Session
from app.config import get_settings

settings = get_settings()

def get_normalized_database_url(url: str) -> str:
    """Normalize Heroku/Render/Supabase postgres:// URL to SQLAlchemy postgresql+psycopg2:// format."""
    if url.startswith("postgres://"):
        return url.replace("postgres://", "postgresql+psycopg2://", 1)
    if url.startswith("postgresql://") and not url.startswith("postgresql+"):
        return url.replace("postgresql://", "postgresql+psycopg2://", 1)
    return url

db_url = get_normalized_database_url(settings.DATABASE_URL)
is_sqlite = db_url.startswith("sqlite")

connect_args = {"check_same_thread": False} if is_sqlite else {}
engine_kwargs = {}
if not is_sqlite:
    engine_kwargs.update({
        "pool_pre_ping": True,
        "pool_recycle": 300,
        "pool_size": 10,
        "max_overflow": 20,
    })

engine = create_engine(
    db_url,
    connect_args=connect_args,
    echo=False,
    **engine_kwargs
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def run_sqlite_migrations():
    """Ensure missing columns in existing SQLite tables are created without data loss."""
    if not settings.DATABASE_URL.startswith("sqlite"):
        return
    with engine.connect() as conn:
        for stmt in [
            "ALTER TABLE artisans ADD COLUMN role VARCHAR(20) DEFAULT 'artisan'",
            "ALTER TABLE orders ADD COLUMN buyer_id VARCHAR(36)",
            "ALTER TABLE orders ADD COLUMN payment_method VARCHAR(30) DEFAULT 'cash_on_delivery'",
            "ALTER TABLE orders ADD COLUMN tracking_id VARCHAR(100)",
            "ALTER TABLE orders ADD COLUMN courier_name VARCHAR(100)",
        ]:
            try:
                conn.execute(text(stmt))
                conn.commit()
            except Exception:
                pass

def run_startup_migrations():
    """Ensure database schema and migrations run automatically on startup."""
    import os
    from app.db.base import Base
    import app.models.db_models  # noqa: F401

    run_sqlite_migrations()

    try:
        from alembic.config import Config
        from alembic import command
        # Locate alembic.ini relative to this file
        base_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        alembic_ini = os.path.join(base_dir, "alembic.ini")
        if os.path.exists(alembic_ini):
            alembic_cfg = Config(alembic_ini)
            command.upgrade(alembic_cfg, "head")
        else:
            Base.metadata.create_all(bind=engine)
    except Exception:
        Base.metadata.create_all(bind=engine)

def get_db():
    db: Session = SessionLocal()
    try:
        yield db
    finally:
        db.close()

