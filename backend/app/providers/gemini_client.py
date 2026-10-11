import json
import re
import time
import asyncio
import logging
from typing import Any, Optional, Dict, List
from google import genai
from google.genai import types
from google.genai.errors import APIError

import sys
from app.config import get_settings

logger = logging.getLogger("kalasetu.gemini")

def scrub_secrets_str(text: str) -> str:
    """Removes API keys and secrets so they are NEVER logged."""
    if not text:
        return ""
    text = re.sub(r'AIza[0-9A-Za-z\-_]{35}', '[REDACTED_API_KEY]', text)
    text = re.sub(r'AQ\.[0-9A-Za-z\-_]{30,}', '[REDACTED_API_KEY]', text)
    text = re.sub(r'(?:key|token|secret|password)[=:]\s*["\']?[0-9A-Za-z\-_\.]{15,}["\']?', 'key=[REDACTED]', text, flags=re.IGNORECASE)
    return text

def parse_ai_error(e: Exception, model_name: str) -> Dict[str, Any]:
    """Extract HTTP status, Gemini error status, model name, and plain-English hint from an exception.
    Never exposes API keys.
    """
    raw_str = scrub_secrets_str(str(e))
    cause = getattr(e, "__cause__", None)
    cause_str = scrub_secrets_str(str(cause)) if cause else ""
    full_str = f"{raw_str} {cause_str}"

    code: Optional[int] = getattr(e, "http_status", None) or getattr(e, "code", None)
    if code is None and cause:
        code = getattr(cause, "code", None)
    if code is None:
        m = re.search(r"\b(400|401|403|404|429|500|502|503|504)\b", full_str)
        if m:
            try:
                code = int(m.group(1))
            except ValueError:
                pass

    status_name = getattr(e, "gemini_status", None) or getattr(e, "status", None)
    if not status_name and cause:
        status_name = getattr(cause, "status", None)
    if not status_name:
        for s in ["RESOURCE_EXHAUSTED", "PERMISSION_DENIED", "NOT_FOUND", "INVALID_ARGUMENT", "UNAVAILABLE", "INTERNAL", "UNAUTHENTICATED", "NO_IMAGE_RETURNED"]:
            if s in full_str:
                status_name = s
                break
    if not status_name:
        if code == 429:
            status_name = "RESOURCE_EXHAUSTED"
        elif code == 403:
            status_name = "PERMISSION_DENIED"
        elif code == 404:
            status_name = "NOT_FOUND"
        elif code == 401:
            status_name = "UNAUTHENTICATED"
        else:
            status_name = "ERROR"

    lower = full_str.lower()
    if status_name == "NO_IMAGE_RETURNED" or "no image" in lower:
        hint = "no image returned"
        if not code:
            code = 502
    elif code == 429 or status_name == "RESOURCE_EXHAUSTED" or "quota" in lower:
        if "limit: 0" in lower or "limit 0" in lower:
            hint = "billing not enabled (free tier request limit is 0 for this model)"
        elif "free_tier" in lower:
            hint = "free tier quota exhausted"
        else:
            hint = "quota limit reached"
    elif code == 404 or status_name == "NOT_FOUND" or ("model" in lower and "not found" in lower):
        hint = "model name not found"
    elif code == 403 or status_name == "PERMISSION_DENIED":
        hint = "permission denied: check API key permissions or project billing"
    elif code == 401 or status_name == "UNAUTHENTICATED" or "api key" in lower:
        hint = "api key invalid or missing"
    elif code == 400 or status_name == "INVALID_ARGUMENT":
        hint = "invalid argument or unsupported modality"
    elif code in (500, 502, 503, 504) or status_name in ("UNAVAILABLE", "INTERNAL"):
        hint = "Gemini service temporarily unavailable"
    else:
        hint = f"AI call failed: {raw_str[:80]}"

    return {
        "http_status": code or 500,
        "gemini_status": status_name,
        "model": model_name,
        "hint": hint,
    }

def log_ai_failure(e: Exception, model_name: str) -> Dict[str, Any]:
    """Logs the mandatory backend log line for failed AI calls without leaking API keys."""
    info = parse_ai_error(e, model_name)
    line = (
        f"[AI_ERROR] HTTP status: {info['http_status']} | "
        f"Gemini error status: {info['gemini_status']} | "
        f"Model: {info['model']} | "
        f"Hint: {info['hint']}"
    )
    logger.error(line)
    print(line, file=sys.stderr, flush=True)
    return info

class GeminiClientError(Exception):
    """Base exception for Gemini client errors."""
    def __init__(
        self,
        message: str,
        http_status: Optional[int] = None,
        gemini_status: Optional[str] = None,
        model: Optional[str] = None,
        hint: Optional[str] = None,
    ):
        super().__init__(message)
        self.message = message
        self.http_status = http_status
        self.gemini_status = gemini_status
        self.model = model
        self.hint = hint


class GeminiClient:
    """Wrapper for Google Gemini API via official google-genai SDK.
    
    Features:
    - Text and JSON mode generation
    - Inline audio and image part handling
    - Automatic retries with exponential backoff on 429 / 5xx
    - Configurable request timeout
    - Fallback model switching on model-not-found / deprecated errors
    - Structured logging of latency without exposing credentials
    """

    def __init__(
        self,
        api_key: Optional[str] = None,
        default_model: Optional[str] = None,
        fallback_model: Optional[str] = None,
        timeout_seconds: Optional[int] = None,
    ):
        settings = get_settings()
        if api_key is not None:
            self.api_key = api_key.strip()
        else:
            self.api_key = (settings.GEMINI_API_KEY or "").strip()
        self.default_model = default_model or settings.GEMINI_TEXT_MODEL
        self.fallback_model = (fallback_model or settings.GEMINI_FALLBACK_MODEL or "").strip()
        self.timeout_seconds = timeout_seconds or settings.REQUEST_TIMEOUT_SECONDS

        timeout_ms = int(self.timeout_seconds * 1000) if self.timeout_seconds else 60000
        http_options = types.HttpOptions(timeout=timeout_ms)

        if self.api_key:
            self._client = genai.Client(api_key=self.api_key, http_options=http_options)
        else:
            self._client = None

    @property
    def is_configured(self) -> bool:
        return bool(self.api_key and self._client)

    def _ensure_client(self):
        if not self.is_configured:
            raise GeminiClientError(
                "Gemini API key is not configured. Set GEMINI_API_KEY in environment or .env."
            )

    def _build_parts(
        self,
        prompt: str,
        image_bytes: Optional[bytes] = None,
        image_mime_type: Optional[str] = None,
        audio_bytes: Optional[bytes] = None,
        audio_mime_type: Optional[str] = None,
    ) -> list[Any]:
        parts = []
        if image_bytes:
            parts.append(
                types.Part.from_bytes(
                    data=image_bytes,
                    mime_type=image_mime_type or "image/jpeg",
                )
            )
        if audio_bytes:
            parts.append(
                types.Part.from_bytes(
                    data=audio_bytes,
                    mime_type=audio_mime_type or "audio/wav",
                )
            )
        parts.append(prompt)
        return parts

    def _is_retryable_error(self, err: Exception) -> bool:
        err_str = str(err).lower()
        if isinstance(err, APIError):
            code = getattr(err, "code", None)
            if code in (429, 500, 502, 503, 504):
                return True
        return any(x in err_str for x in ["429", "rate limit", "resource exhausted", "500", "502", "503", "504", "server error", "timeout"])

    def _is_model_unavailable_error(self, err: Exception) -> bool:
        err_str = str(err).lower()
        return any(x in err_str for x in [
            "not found", "404", "deprecated", "not supported", "unknown model",
            "503", "unavailable", "high demand", "spikes in demand", "overloaded",
            "resource_exhausted", "quota", "resource exhausted", "quota exceeded"
        ])

    def _log_latency(self, model: str, latency_ms: float, status: str, json_mode: bool, error: Optional[str] = None):
        log_payload = {
            "event": "gemini_call",
            "model": model,
            "latency_ms": round(latency_ms, 2),
            "status": status,
            "json_mode": json_mode,
        }
        if error:
            log_payload["error"] = error
        logger.info(json.dumps(log_payload))

    def generate_text_sync(
        self,
        prompt: str,
        system_instruction: Optional[str] = None,
        image_bytes: Optional[bytes] = None,
        image_mime_type: Optional[str] = None,
        audio_bytes: Optional[bytes] = None,
        audio_mime_type: Optional[str] = None,
        model: Optional[str] = None,
        temperature: Optional[float] = None,
        max_output_tokens: Optional[int] = None,
        max_retries: int = 3,
    ) -> str:
        """Synchronous text generation with retries, timeout, and fallback model support."""
        self._ensure_client()
        current_model = model or self.default_model
        parts = self._build_parts(prompt, image_bytes, image_mime_type, audio_bytes, audio_mime_type)

        config_kwargs: dict[str, Any] = {}
        if system_instruction:
            config_kwargs["system_instruction"] = system_instruction
        if temperature is not None:
            config_kwargs["temperature"] = temperature
        if max_output_tokens is not None:
            config_kwargs["max_output_tokens"] = max_output_tokens

        config = types.GenerateContentConfig(**config_kwargs) if config_kwargs else None

        attempts = 0
        tried_fallback = False

        while attempts < max_retries:
            attempts += 1
            start_time = time.perf_counter()
            try:
                response = self._client.models.generate_content(
                    model=current_model,
                    contents=parts,
                    config=config,
                )
                elapsed_ms = (time.perf_counter() - start_time) * 1000
                self._log_latency(current_model, elapsed_ms, "success", json_mode=False)
                return response.text or ""
            except Exception as e:
                elapsed_ms = (time.perf_counter() - start_time) * 1000
                if self._is_model_unavailable_error(e) and self.fallback_model and not tried_fallback:
                    self._log_latency(current_model, elapsed_ms, "fallback_triggered", json_mode=False, error=str(e))
                    current_model = self.fallback_model
                    tried_fallback = True
                    continue

                if self._is_retryable_error(e) and attempts < max_retries:
                    self._log_latency(current_model, elapsed_ms, f"retry_{attempts}", json_mode=False, error=str(e))
                    time.sleep(1.5 * attempts)
                    continue

                self._log_latency(current_model, elapsed_ms, "failed", json_mode=False, error=str(e))
                raise GeminiClientError(f"Gemini text generation failed: {e}") from e

        raise GeminiClientError(f"Gemini text generation exceeded max retries ({max_retries})")

    async def generate_text(
        self,
        prompt: str,
        system_instruction: Optional[str] = None,
        image_bytes: Optional[bytes] = None,
        image_mime_type: Optional[str] = None,
        audio_bytes: Optional[bytes] = None,
        audio_mime_type: Optional[str] = None,
        model: Optional[str] = None,
        temperature: Optional[float] = None,
        max_output_tokens: Optional[int] = None,
        max_retries: int = 3,
    ) -> str:
        """Asynchronous text generation with retries, timeout, and fallback model support."""
        self._ensure_client()
        current_model = model or self.default_model
        parts = self._build_parts(prompt, image_bytes, image_mime_type, audio_bytes, audio_mime_type)

        config_kwargs: dict[str, Any] = {}
        if system_instruction:
            config_kwargs["system_instruction"] = system_instruction
        if temperature is not None:
            config_kwargs["temperature"] = temperature
        if max_output_tokens is not None:
            config_kwargs["max_output_tokens"] = max_output_tokens

        config = types.GenerateContentConfig(**config_kwargs) if config_kwargs else None

        attempts = 0
        tried_fallback = False

        while attempts < max_retries:
            attempts += 1
            start_time = time.perf_counter()
            try:
                response = await self._client.aio.models.generate_content(
                    model=current_model,
                    contents=parts,
                    config=config,
                )
                elapsed_ms = (time.perf_counter() - start_time) * 1000
                self._log_latency(current_model, elapsed_ms, "success", json_mode=False)
                return response.text or ""
            except Exception as e:
                elapsed_ms = (time.perf_counter() - start_time) * 1000
                if self._is_model_unavailable_error(e) and self.fallback_model and not tried_fallback:
                    self._log_latency(current_model, elapsed_ms, "fallback_triggered", json_mode=False, error=str(e))
                    current_model = self.fallback_model
                    tried_fallback = True
                    continue

                if self._is_retryable_error(e) and attempts < max_retries:
                    self._log_latency(current_model, elapsed_ms, f"retry_{attempts}", json_mode=False, error=str(e))
                    await asyncio.sleep(1.5 * attempts)
                    continue

                self._log_latency(current_model, elapsed_ms, "failed", json_mode=False, error=str(e))
                raise GeminiClientError(f"Gemini async text generation failed: {e}") from e

        raise GeminiClientError(f"Gemini text generation exceeded max retries ({max_retries})")

    def generate_json_sync(
        self,
        prompt: str,
        schema: Optional[Any] = None,
        system_instruction: Optional[str] = None,
        image_bytes: Optional[bytes] = None,
        image_mime_type: Optional[str] = None,
        audio_bytes: Optional[bytes] = None,
        audio_mime_type: Optional[str] = None,
        model: Optional[str] = None,
        temperature: Optional[float] = None,
        max_output_tokens: Optional[int] = None,
        max_retries: int = 3,
    ) -> Any:
        """Synchronous JSON mode generation returning parsed JSON object/list."""
        self._ensure_client()
        current_model = model or self.default_model
        parts = self._build_parts(prompt, image_bytes, image_mime_type, audio_bytes, audio_mime_type)

        config_kwargs: dict[str, Any] = {
            "response_mime_type": "application/json"
        }
        if schema:
            config_kwargs["response_schema"] = schema
        if system_instruction:
            config_kwargs["system_instruction"] = system_instruction
        if temperature is not None:
            config_kwargs["temperature"] = temperature
        if max_output_tokens is not None:
            config_kwargs["max_output_tokens"] = max_output_tokens

        config = types.GenerateContentConfig(**config_kwargs)

        attempts = 0
        tried_fallback = False

        while attempts < max_retries:
            attempts += 1
            start_time = time.perf_counter()
            try:
                response = self._client.models.generate_content(
                    model=current_model,
                    contents=parts,
                    config=config,
                )
                elapsed_ms = (time.perf_counter() - start_time) * 1000
                self._log_latency(current_model, elapsed_ms, "success", json_mode=True)
                return self._parse_json(response.text or "{}")
            except Exception as e:
                elapsed_ms = (time.perf_counter() - start_time) * 1000
                if self._is_model_unavailable_error(e) and self.fallback_model and not tried_fallback:
                    self._log_latency(current_model, elapsed_ms, "fallback_triggered", json_mode=True, error=str(e))
                    current_model = self.fallback_model
                    tried_fallback = True
                    continue

                if self._is_retryable_error(e) and attempts < max_retries:
                    self._log_latency(current_model, elapsed_ms, f"retry_{attempts}", json_mode=True, error=str(e))
                    time.sleep(1.5 * attempts)
                    continue

                self._log_latency(current_model, elapsed_ms, "failed", json_mode=True, error=str(e))
                raise GeminiClientError(f"Gemini JSON generation failed: {e}") from e

        raise GeminiClientError(f"Gemini JSON generation exceeded max retries ({max_retries})")

    async def generate_json(
        self,
        prompt: str,
        schema: Optional[Any] = None,
        system_instruction: Optional[str] = None,
        image_bytes: Optional[bytes] = None,
        image_mime_type: Optional[str] = None,
        audio_bytes: Optional[bytes] = None,
        audio_mime_type: Optional[str] = None,
        model: Optional[str] = None,
        temperature: Optional[float] = None,
        max_output_tokens: Optional[int] = None,
        max_retries: int = 3,
    ) -> Any:
        """Asynchronous JSON mode generation returning parsed JSON object/list."""
        self._ensure_client()
        current_model = model or self.default_model
        parts = self._build_parts(prompt, image_bytes, image_mime_type, audio_bytes, audio_mime_type)

        config_kwargs: dict[str, Any] = {
            "response_mime_type": "application/json"
        }
        if schema:
            config_kwargs["response_schema"] = schema
        if system_instruction:
            config_kwargs["system_instruction"] = system_instruction
        if temperature is not None:
            config_kwargs["temperature"] = temperature
        if max_output_tokens is not None:
            config_kwargs["max_output_tokens"] = max_output_tokens

        config = types.GenerateContentConfig(**config_kwargs)

        attempts = 0
        tried_fallback = False

        while attempts < max_retries:
            attempts += 1
            start_time = time.perf_counter()
            try:
                response = await self._client.aio.models.generate_content(
                    model=current_model,
                    contents=parts,
                    config=config,
                )
                elapsed_ms = (time.perf_counter() - start_time) * 1000
                self._log_latency(current_model, elapsed_ms, "success", json_mode=True)
                return self._parse_json(response.text or "{}")
            except Exception as e:
                elapsed_ms = (time.perf_counter() - start_time) * 1000
                if self._is_model_unavailable_error(e) and self.fallback_model and not tried_fallback:
                    self._log_latency(current_model, elapsed_ms, "fallback_triggered", json_mode=True, error=str(e))
                    current_model = self.fallback_model
                    tried_fallback = True
                    continue

                if self._is_retryable_error(e) and attempts < max_retries:
                    self._log_latency(current_model, elapsed_ms, f"retry_{attempts}", json_mode=True, error=str(e))
                    await asyncio.sleep(1.5 * attempts)
                    continue

                self._log_latency(current_model, elapsed_ms, "failed", json_mode=True, error=str(e))
                raise GeminiClientError(f"Gemini async JSON generation failed: {e}") from e

        raise GeminiClientError(f"Gemini JSON generation exceeded max retries ({max_retries})")

    @staticmethod
    def _parse_json(raw_text: str) -> Any:
        text = raw_text.strip()
        # Strip markdown fences if present
        if text.startswith("```"):
            text = re.sub(r"^```(?:json)?\s*", "", text, flags=re.IGNORECASE)
            text = re.sub(r"\s*```$", "", text)
        return json.loads(text)

    def _extract_grounding_metadata(self, response: Any) -> Dict[str, Any]:
        metadata: Dict[str, Any] = {
            "sources": [],
            "search_queries": [],
            "has_grounding": False,
        }
        if not response or not hasattr(response, "candidates") or not response.candidates:
            return metadata

        cand = response.candidates[0]
        gm = getattr(cand, "grounding_metadata", None)
        if not gm:
            return metadata

        queries = getattr(gm, "web_search_queries", None) or []
        metadata["search_queries"] = [str(q) for q in queries]

        chunks = getattr(gm, "grounding_chunks", None) or []
        sources = []
        for c in chunks:
            web = getattr(c, "web", None)
            if web:
                sources.append({
                    "title": getattr(web, "title", "") or "",
                    "uri": getattr(web, "uri", "") or "",
                })
        metadata["sources"] = sources
        metadata["has_grounding"] = len(sources) > 0 or len(queries) > 0
        return metadata

    async def generate_with_google_search(
        self,
        prompt: str,
        model: Optional[str] = None,
        temperature: Optional[float] = 0.2,
        max_output_tokens: Optional[int] = None,
    ) -> Dict[str, Any]:
        """Generates content grounded with live Google Search."""
        self._ensure_client()
        current_model = model or self.default_model

        config_kwargs: dict[str, Any] = {
            "tools": [types.Tool(google_search=types.GoogleSearch())]
        }
        if temperature is not None:
            config_kwargs["temperature"] = temperature
        if max_output_tokens is not None:
            config_kwargs["max_output_tokens"] = max_output_tokens

        config = types.GenerateContentConfig(**config_kwargs)

        try:
            response = await self._client.aio.models.generate_content(
                model=current_model,
                contents=[prompt],
                config=config,
            )
            grounding = self._extract_grounding_metadata(response)
            return {
                "text": response.text or "",
                "sources": grounding["sources"],
                "search_queries": grounding["search_queries"],
                "has_grounding": grounding["has_grounding"],
            }
        except Exception as e:
            logger.warning(f"Google search grounding call failed: {e}")
            raise GeminiClientError(f"Search grounding failed: {e}") from e

    def generate_with_google_search_sync(
        self,
        prompt: str,
        model: Optional[str] = None,
        temperature: Optional[float] = 0.2,
        max_output_tokens: Optional[int] = None,
    ) -> Dict[str, Any]:
        """Synchronous content generation grounded with live Google Search."""
        self._ensure_client()
        current_model = model or self.default_model

        config_kwargs: dict[str, Any] = {
            "tools": [types.Tool(google_search=types.GoogleSearch())]
        }
        if temperature is not None:
            config_kwargs["temperature"] = temperature
        if max_output_tokens is not None:
            config_kwargs["max_output_tokens"] = max_output_tokens

        config = types.GenerateContentConfig(**config_kwargs)

        try:
            response = self._client.models.generate_content(
                model=current_model,
                contents=[prompt],
                config=config,
            )
            grounding = self._extract_grounding_metadata(response)
            return {
                "text": response.text or "",
                "sources": grounding["sources"],
                "search_queries": grounding["search_queries"],
                "has_grounding": grounding["has_grounding"],
            }
        except Exception as e:
            logger.warning(f"Google search grounding sync call failed: {e}")
            raise GeminiClientError(f"Search grounding failed: {e}") from e

    async def edit_image(
        self,
        image_bytes: bytes,
        prompt: str,
        model: Optional[str] = None,
        mime_type: str = "image/jpeg",
    ) -> bytes:
        """Requests image edit from Gemini image models, returning edited image bytes.
        Raises GeminiClientError if editing fails or quota/billing limits are encountered.
        """
        self._ensure_client()
        settings = get_settings()
        target_model = model or settings.GEMINI_IMAGE_MODEL
        if not target_model:
            raise GeminiClientError("GEMINI_IMAGE_MODEL is not configured in settings or environment.")

        output_bytes = None
        last_error = None
        # 1. Try generate_content with image response modality enabled
        try:
            config = types.GenerateContentConfig(
                response_modalities=["IMAGE", "TEXT"],
            )
            response = await self._client.aio.models.generate_content(
                model=target_model,
                contents=[
                    types.Part.from_bytes(data=image_bytes, mime_type=mime_type),
                    prompt,
                ],
                config=config,
            )
            if response.candidates and response.candidates[0].content:
                for part in response.candidates[0].content.parts:
                    if part.inline_data and part.inline_data.data:
                        output_bytes = part.inline_data.data
                        break
        except Exception as e:
            last_error = e
            logger.warning(f"generate_content image edit failed on {target_model}: {e}")
            # 2. Fallback attempt with edit_image API (for Imagen models)
            try:
                raw_ref = types.RawReferenceImage(
                    reference_image=types.Image(image_bytes=image_bytes, mime_type=mime_type),
                    reference_id=1,
                )
                res_edit = await asyncio.to_thread(
                    self._client.models.edit_image,
                    model=target_model,
                    prompt=prompt,
                    reference_images=[raw_ref],
                )
                if res_edit and res_edit.generated_images:
                    for g in res_edit.generated_images:
                        if g.image and g.image.image_bytes:
                            output_bytes = g.image.image_bytes
                            break
            except Exception:
                pass
            if not output_bytes:
                info = log_ai_failure(e, target_model)
                raise GeminiClientError(
                    f"Image edit failed on model {target_model}: [HTTP {info['http_status']} {info['gemini_status']}] {info['hint']}",
                    http_status=info["http_status"],
                    gemini_status=info["gemini_status"],
                    model=info["model"],
                    hint=info["hint"],
                ) from e

        # If generate_content succeeded without exception but returned no inline image data,
        # try the edit_image fallback before failing
        if not output_bytes:
            try:
                raw_ref = types.RawReferenceImage(
                    reference_image=types.Image(image_bytes=image_bytes, mime_type=mime_type),
                    reference_id=1,
                )
                res_edit = await asyncio.to_thread(
                    self._client.models.edit_image,
                    model=target_model,
                    prompt=prompt,
                    reference_images=[raw_ref],
                )
                if res_edit and res_edit.generated_images:
                    for g in res_edit.generated_images:
                        if g.image and g.image.image_bytes:
                            output_bytes = g.image.image_bytes
                            break
            except Exception as e_edit:
                last_error = e_edit
                logger.warning(f"edit_image fallback attempt also returned no image: {e_edit}")

        if not output_bytes:
            err = GeminiClientError(
                f"No image bytes returned by Gemini model '{target_model}'.",
                http_status=502,
                gemini_status="NO_IMAGE_RETURNED",
                model=target_model,
                hint="no image returned",
            )
            log_ai_failure(last_error or err, target_model)
            raise err from last_error

        if output_bytes == image_bytes:
            err = GeminiClientError(
                f"Gemini model '{target_model}' returned identical unmodified image.",
                http_status=502,
                gemini_status="NO_IMAGE_RETURNED",
                model=target_model,
                hint="no image returned",
            )
            log_ai_failure(err, target_model)
            raise err

        return output_bytes

class GeminiGateway(GeminiClient):
    """Gateway interface for Google Gemini models and capabilities."""
    pass

