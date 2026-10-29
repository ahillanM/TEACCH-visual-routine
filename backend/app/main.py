import logging
import secrets
from datetime import date, datetime
from zoneinfo import ZoneInfo

from fastapi import Depends, FastAPI, File, Form, Header, HTTPException, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import ValidationError

from .config import Settings, get_settings
from .planner import OpenRouterPlanner, ServiceError
from .schemas import (GenerateRoutineRequest, RoutineProposal, SpeechToRoutineResponse,
                      TranscribeResponse)
from .stt import GladiaTranscriber, Transcript
from .validation import build_proposal

log = logging.getLogger("ai")  # never log transcripts, instructions or audio
ALLOWED_EXT = {"wav", "mp3", "m4a", "aac", "ogg", "opus", "flac", "webm", "mp4"}

app = FastAPI(title="Caritas Routine AI", version="0.1.0")
_s = get_settings()
app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in _s.cors_origins.split(",") if o.strip()],
    # Flutter web (Chrome) serves from a random localhost port: only allowed in dev.
    allow_origin_regex=r"^http://(localhost|127\.0\.0\.1)(:\d+)?$" if _s.app_env == "dev" else None,
    allow_methods=["GET", "POST"], allow_headers=["Content-Type", "X-API-Key"])


def get_planner(s: Settings = Depends(get_settings)):
    return OpenRouterPlanner(s)


def get_transcriber(s: Settings = Depends(get_settings)):
    return GladiaTranscriber(s)


def require_api_key(x_api_key: str | None = Header(default=None), s: Settings = Depends(get_settings)):
    if s.ai_backend_api_key and not secrets.compare_digest(x_api_key or "", s.ai_backend_api_key):
        raise HTTPException(401, {"code": "unauthorized", "message": "Missing or invalid X-API-Key."})


@app.exception_handler(ServiceError)
async def service_error_handler(_: Request, e: ServiceError):
    log.warning("service_error code=%s", e.code)
    return JSONResponse(status_code=e.status, content={"detail": {"code": e.code, "message": e.message}})


def _today(s: Settings, reference: str | None) -> date:
    if reference:
        try:
            return date.fromisoformat(reference)
        except ValueError:
            raise HTTPException(422, {"code": "invalid_reference_date", "message": "referenceDate must be YYYY-MM-DD."})
    return datetime.now(ZoneInfo(s.default_timezone)).date()


async def _plan(req: GenerateRoutineRequest, source: str, s: Settings, planner) -> RoutineProposal:
    if len(req.instruction) > s.max_instruction_chars:
        raise HTTPException(413, {"code": "instruction_too_long",
                                  "message": f"Max {s.max_instruction_chars} characters."})
    today = _today(s, req.referenceDate)
    raw, model = await planner.plan(req.instruction, today)
    try:
        return build_proposal(raw, req, source, model, today)
    except ValidationError:
        raise ServiceError("invalid_model_output", "Model output failed validation.", 502)


async def _transcribe(audio: UploadFile, language: str | None, s: Settings, stt) -> Transcript:
    name = audio.filename or "audio"
    if name.rsplit(".", 1)[-1].lower() not in ALLOWED_EXT:
        raise HTTPException(415, {"code": "unsupported_audio_type",
                                  "message": f"Allowed extensions: {', '.join(sorted(ALLOWED_EXT))}."})
    if language and language not in {"de", "en"}:
        raise HTTPException(422, {"code": "unsupported_language", "message": "language must be 'de' or 'en'."})
    chunks, size = [], 0
    while chunk := await audio.read(64 * 1024):
        size += len(chunk)
        if size > s.max_audio_bytes:
            raise HTTPException(413, {"code": "audio_too_large",
                                      "message": f"Max {s.max_audio_bytes} bytes."})
        chunks.append(chunk)
    if not size:
        raise HTTPException(422, {"code": "empty_audio", "message": "Audio file is empty."})
    return await stt.transcribe(b"".join(chunks), name,
                                audio.content_type or "application/octet-stream", language)


@app.get("/health")
def health(s: Settings = Depends(get_settings)):
    return {"ok": True, "openrouterConfigured": bool(s.openrouter_api_key),
            "gladiaConfigured": bool(s.gladia_api_key)}


@app.post("/ai/transcribe", response_model=TranscribeResponse, dependencies=[Depends(require_api_key)])
async def transcribe(audio: UploadFile = File(...), language: str | None = Form(None),
                     s: Settings = Depends(get_settings), stt=Depends(get_transcriber)):
    t = await _transcribe(audio, language, s, stt)
    return TranscribeResponse(transcript=t.text, language=t.language, durationSec=t.duration_sec)


@app.post("/ai/generate-routine", response_model=RoutineProposal, dependencies=[Depends(require_api_key)])
async def generate_routine(req: GenerateRoutineRequest, s: Settings = Depends(get_settings),
                           planner=Depends(get_planner)):
    return await _plan(req, "text", s, planner)


@app.post("/ai/speech-to-routine", response_model=SpeechToRoutineResponse,
          dependencies=[Depends(require_api_key)])
async def speech_to_routine(audio: UploadFile = File(...), language: str | None = Form(None),
                            referenceDate: str | None = Form(None),
                            requesterRole: str = Form("participant"),
                            participantId: str | None = Form(None),
                            s: Settings = Depends(get_settings), stt=Depends(get_transcriber),
                            planner=Depends(get_planner)):
    t = await _transcribe(audio, language, s, stt)
    try:
        req = GenerateRoutineRequest(instruction=t.text, referenceDate=referenceDate,
                                     requesterRole=requesterRole, participantId=participantId)
    except ValidationError:
        raise HTTPException(422, {"code": "invalid_request", "message": "Invalid form fields."})
    return SpeechToRoutineResponse(transcript=t.text, language=t.language,
                                   proposal=await _plan(req, "speech", s, planner))
