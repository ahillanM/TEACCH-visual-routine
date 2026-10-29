"""Gladia pre-recorded transcription. Audio is held in memory only (never written to disk)."""
import asyncio
import time
from dataclasses import dataclass

import httpx

from .config import Settings
from .planner import ServiceError


@dataclass
class Transcript:
    text: str
    language: str | None = None
    duration_sec: float | None = None


class GladiaTranscriber:
    def __init__(self, settings: Settings, client: httpx.AsyncClient | None = None):
        self.s = settings
        self.client = client

    async def transcribe(self, data: bytes, filename: str, content_type: str,
                         language: str | None = None) -> Transcript:
        if not self.s.gladia_api_key:
            raise ServiceError("gladia_not_configured", "GLADIA_API_KEY is not set.", 503)
        client = self.client or httpx.AsyncClient(timeout=30)
        headers = {"x-gladia-key": self.s.gladia_api_key}
        base = self.s.gladia_base_url.rstrip("/")
        job_id = None
        try:
            up = await client.post(f"{base}/v2/upload", headers=headers,
                                   files={"audio": (filename, data, content_type)})
            up.raise_for_status()
            up_json = up.json()
            duration = (up_json.get("audio_metadata") or {}).get("audio_duration")
            if duration is not None and duration > self.s.max_audio_seconds:
                raise ServiceError("audio_too_long",
                                   f"Audio is longer than {self.s.max_audio_seconds}s.", 413)

            langs = [language] if language else [x.strip() for x in self.s.gladia_languages.split(",") if x.strip()]
            job = await client.post(f"{base}/v2/pre-recorded", headers=headers, json={
                "audio_url": up_json["audio_url"], "model": self.s.gladia_model,
                "language_config": {"languages": langs, "code_switching": False}})
            job.raise_for_status()
            job_id = job.json()["id"]

            deadline = time.monotonic() + self.s.gladia_poll_timeout_s
            while True:
                res = await client.get(f"{base}/v2/pre-recorded/{job_id}", headers=headers)
                res.raise_for_status()
                body = res.json()
                if body.get("status") == "done":
                    tr = (body.get("result") or {}).get("transcription") or {}
                    text = (tr.get("full_transcript") or "").strip()
                    if not text:
                        raise ServiceError("empty_transcript", "No speech was recognised.", 422)
                    found = tr.get("languages") or []
                    return Transcript(text, found[0] if found else None, duration)
                if body.get("status") == "error":
                    raise ServiceError("stt_failed", "Transcription failed.", 502)
                if time.monotonic() > deadline:
                    raise ServiceError("stt_timeout", "Transcription timed out.", 504)
                await asyncio.sleep(self.s.gladia_poll_interval_s)
        except httpx.HTTPError as e:
            raise ServiceError("stt_unavailable", f"Speech service error: {type(e).__name__}", 502)
        finally:
            if job_id:  # best effort: ask Gladia to delete the stored job/audio
                try:
                    await client.delete(f"{base}/v2/pre-recorded/{job_id}", headers=headers)
                except Exception:
                    pass
            if self.client is None:
                await client.aclose()
