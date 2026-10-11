import os
import uuid
from fastapi import APIRouter, UploadFile, File, HTTPException
from app.config import get_settings

from app.providers.storage_provider import get_storage_provider

router = APIRouter(prefix="", tags=["Media"])
settings = get_settings()

@router.post("/upload")
async def upload_file(file: UploadFile = File(...)):
    # Validate extension
    allowed = {".jpg", ".jpeg", ".png", ".webp", ".wav", ".mp3", ".m4a"}
    ext = os.path.splitext(file.filename or "")[1].lower()
    if ext not in allowed:
        raise HTTPException(status_code=400, detail=f"Unsupported file format: {ext}")

    content_types = {
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".png": "image/png",
        ".webp": "image/webp",
        ".wav": "audio/wav",
        ".mp3": "audio/mpeg",
        ".m4a": "audio/mp4",
    }
    content_type = content_types.get(ext, file.content_type or "application/octet-stream")

    filename = f"{uuid.uuid4()}{ext}"
    contents = await file.read()
    
    storage = get_storage_provider()
    file_url = await storage.upload_file(contents, filename, content_type=content_type)

    return {
        "url": file_url,
        "filename": filename,
        "size_bytes": len(contents)
    }
