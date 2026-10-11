import os
import io
import logging
from abc import ABC, abstractmethod
from functools import lru_cache
from typing import Optional

from app.config import get_settings

logger = logging.getLogger("kalasetu.storage")


class StorageProvider(ABC):
    @abstractmethod
    async def upload_file(
        self,
        file_bytes: bytes,
        filename: str,
        content_type: str = "image/jpeg"
    ) -> str:
        """Uploads file content and returns accessible URL."""
        pass

    @abstractmethod
    async def get_url(self, filename: str) -> str:
        """Returns the public or accessible URL for a given filename."""
        pass

    @abstractmethod
    async def read_file(self, filename: str) -> Optional[bytes]:
        """Reads and returns file bytes."""
        pass

    @abstractmethod
    async def delete_file(self, filename: str) -> bool:
        """Deletes a stored file."""
        pass


class LocalStorageProvider(StorageProvider):
    def __init__(self, local_path: Optional[str] = None):
        settings = get_settings()
        self.local_path = local_path or settings.STORAGE_LOCAL_PATH
        os.makedirs(self.local_path, exist_ok=True)

    async def upload_file(
        self,
        file_bytes: bytes,
        filename: str,
        content_type: str = "image/jpeg"
    ) -> str:
        dest_path = os.path.join(self.local_path, filename)
        with open(dest_path, "wb") as f:
            f.write(file_bytes)
        return await self.get_url(filename)

    async def get_url(self, filename: str) -> str:
        # Returns web-accessible URL served by static mount
        return f"/static/uploads/{filename}"

    async def read_file(self, filename: str) -> Optional[bytes]:
        dest_path = os.path.join(self.local_path, filename)
        if not os.path.exists(dest_path):
            return None
        with open(dest_path, "rb") as f:
            return f.read()

    async def delete_file(self, filename: str) -> bool:
        dest_path = os.path.join(self.local_path, filename)
        if os.path.exists(dest_path):
            try:
                os.remove(dest_path)
                return True
            except Exception as e:
                logger.warning(f"Failed to delete local file {dest_path}: {e}")
        return False


class S3StorageProvider(StorageProvider):
    """S3-compatible Object Storage Provider for production (AWS S3, Supabase Storage, Cloudflare R2)."""
    def __init__(self):
        settings = get_settings()
        self.bucket = settings.STORAGE_BUCKET
        self.endpoint_url = settings.STORAGE_ENDPOINT_URL or None
        self.access_key = settings.STORAGE_ACCESS_KEY
        self.secret_key = settings.STORAGE_SECRET_KEY
        self.region = settings.STORAGE_REGION or "us-east-1"
        self.public_url_base = settings.STORAGE_PUBLIC_URL_BASE.rstrip("/") if settings.STORAGE_PUBLIC_URL_BASE else None

        import boto3
        from botocore.config import Config

        boto_config = Config(
            signature_version="s3v4",
            s3={"addressing_style": "virtual" if not self.endpoint_url else "path"},
            retries={"max_attempts": 3, "mode": "standard"}
        )

        client_kwargs = {
            "service_name": "s3",
            "region_name": self.region,
            "config": boto_config,
        }
        if self.endpoint_url:
            client_kwargs["endpoint_url"] = self.endpoint_url
        if self.access_key and self.secret_key:
            client_kwargs["aws_access_key_id"] = self.access_key
            client_kwargs["aws_secret_access_key"] = self.secret_key

        self.s3_client = boto3.client(**client_kwargs)
        logger.info(f"Initialized S3StorageProvider for bucket: {self.bucket} (endpoint: {self.endpoint_url or 'AWS S3'})")

    async def upload_file(
        self,
        file_bytes: bytes,
        filename: str,
        content_type: str = "image/jpeg"
    ) -> str:
        put_kwargs = {
            "Bucket": self.bucket,
            "Key": filename,
            "Body": file_bytes,
            "ContentType": content_type,
        }
        try:
            self.s3_client.put_object(**put_kwargs)
        except Exception as e:
            logger.error(f"S3 upload error for {filename}: {e}")
            raise e
        return await self.get_url(filename)

    async def get_url(self, filename: str) -> str:
        if self.public_url_base:
            return f"{self.public_url_base}/{filename}"
        if self.endpoint_url:
            return f"{self.endpoint_url}/{self.bucket}/{filename}"
        return f"https://{self.bucket}.s3.{self.region}.amazonaws.com/{filename}"

    async def read_file(self, filename: str) -> Optional[bytes]:
        try:
            resp = self.s3_client.get_object(Bucket=self.bucket, Key=filename)
            return resp["Body"].read()
        except Exception as e:
            logger.warning(f"S3 get_object failed for {filename}: {e}")
            return None

    async def delete_file(self, filename: str) -> bool:
        try:
            self.s3_client.delete_object(Bucket=self.bucket, Key=filename)
            return True
        except Exception as e:
            logger.warning(f"S3 delete_object failed for {filename}: {e}")
            return False


@lru_cache()
def get_storage_provider() -> StorageProvider:
    settings = get_settings()
    backend = settings.STORAGE_BACKEND.lower()
    if backend in ("s3", "supabase") or (settings.STORAGE_ACCESS_KEY and settings.STORAGE_ENDPOINT_URL):
        try:
            return S3StorageProvider()
        except Exception as e:
            logger.error(f"Failed to initialize S3StorageProvider ({e}); falling back to LocalStorageProvider")
            return LocalStorageProvider()
    return LocalStorageProvider()
