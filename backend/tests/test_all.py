import json
from datetime import date

import httpx
import pytest
from fastapi.testclient import TestClient

from app.config import Settings, get_settings
from app.main import app, get_planner, get_transcriber
from app.planner import OpenRouterPlanner, ServiceError
from app.schemas import GenerateRoutineRequest
from app.stt import GladiaTranscriber, Transcript
from app.validation import build_proposal

REQ = GenerateRoutineRequest(instruction="x")
GOOD = {"items": [
    {"title": "Wake up", "date": "2026-10-30", "startTime": "07:00", "category": "PERSONAL"},
    {"title": "Brush teeth"},
    {"title": "Breakfast", "date": "2026-10-30", "startTime": "8:00", "category": "BREAK"},
    {"title": "Training", "date": "2026-10-30", "startTime": "09:00", "category": "BBW_TRAINING"}],
    "missingInformation": ["No time for brushing teeth"]}


def codes(p):
    return {i.code for i in p.issues}


def test_no_invented_times_and_normalisation():
    p = build_proposal(GOOD, REQ, "text", "m")
    assert p.items[1].startTime is None and p.items[1].timeRange == ""
    assert p.items[2].startTime == "08:00" and p.items[2].timeRange == "08:00"
    assert p.status == "draft" and p.requiresApproval and p.valid
    assert "missing_time" in codes(p)


def test_overlap_invalid_time_duplicate_order():
    raw = {"items": [
        {"title": "A", "startTime": "09:00", "endTime": "10:00"},
        {"title": "B", "startTime": "09:30", "endTime": "10:30"},
        {"title": "B", "startTime": "09:30", "endTime": "10:30"},
        {"title": "C", "startTime": "25:99"},
        {"title": "D", "startTime": "08:00", "endTime": "07:00"},
        {"title": "E", "date": "2026-02-31"}]}
    p = build_proposal(raw, REQ, "text", "m")
    assert {"overlap", "duplicate_activity", "invalid_time", "invalid_range",
            "invalid_date", "order_mismatch"} <= codes(p)
    assert not p.valid


def test_forbidden_action_and_unsupported_request():
    raw = {"items": [{"title": "Lunch", "action": "delete_all", "publish": True}],
           "unsupportedRequests": ["delete my schedule"]}
    p = build_proposal(raw, REQ, "text", "m")
    assert {"unsupported_action", "unsupported_request"} <= codes(p) and not p.valid


def test_existing_conflict_and_empty():
    req = GenerateRoutineRequest(instruction="x", existingItems=[
        {"title": "Workshop", "date": "2026-10-30", "startTime": "09:00", "endTime": "11:00"}])
    p = build_proposal({"items": [{"title": "Gym", "date": "2026-10-30", "startTime": "10:00",
                                   "endTime": "11:00"}]}, req, "text", "m")
    assert "conflict_existing" in codes(p)
    assert "no_activities" in codes(build_proposal({"items": []}, REQ, "text", "m"))


# ---- OpenRouter planner with mocked HTTP ----
def or_settings(**kw):
    return Settings(openrouter_api_key="k", openrouter_model_primary="p", openrouter_model_fallback="f", **kw)


def or_response(content):
    return httpx.Response(200, json={"choices": [{"message": {"content": content}}]})


async def test_planner_falls_back_on_bad_primary():
    seen = []

    def handler(request):
        model = json.loads(request.content)["model"]
        seen.append(model)
        return or_response("not json") if model == "p" else or_response("```json\n" + json.dumps(GOOD) + "\n```")

    planner = OpenRouterPlanner(or_settings(), httpx.AsyncClient(transport=httpx.MockTransport(handler)))
    raw, model = await planner.plan("hi", date(2026, 10, 29))
    assert seen == ["p", "f"] and model == "f" and len(raw["items"]) == 4


async def test_planner_all_fail_and_no_key():
    c = httpx.AsyncClient(transport=httpx.MockTransport(lambda r: httpx.Response(429)))
    with pytest.raises(ServiceError) as e:
        await OpenRouterPlanner(or_settings(), c).plan("hi", date(2026, 10, 29))
    assert e.value.code == "planner_failed"
    with pytest.raises(ServiceError) as e:
        await OpenRouterPlanner(Settings(openrouter_api_key=""), c).plan("hi", date(2026, 10, 29))
    assert e.value.code == "openrouter_not_configured"


# ---- Gladia with mocked HTTP ----
def gladia_client(duration=5, final="done"):
    calls = []

    def handler(request):
        calls.append((request.method, request.url.path))
        p = request.url.path
        if p == "/v2/upload":
            return httpx.Response(200, json={"audio_url": "https://x/a", "audio_metadata": {"audio_duration": duration}})
        if p == "/v2/pre-recorded" and request.method == "POST":
            return httpx.Response(200, json={"id": "job1"})
        if request.method == "DELETE":
            return httpx.Response(202)
        return httpx.Response(200, json={"status": final, "result": {"transcription": {
            "full_transcript": "Morgen um sieben aufstehen", "languages": ["de"]}}})
    return httpx.AsyncClient(transport=httpx.MockTransport(handler)), calls


async def test_gladia_happy_path_and_cleanup():
    c, calls = gladia_client()
    st = Settings(gladia_api_key="g", gladia_poll_interval_s=0)
    t = await GladiaTranscriber(st, c).transcribe(b"RIFF", "a.wav", "audio/wav")
    assert t.text.startswith("Morgen") and t.language == "de"
    assert ("DELETE", "/v2/pre-recorded/job1") in calls


async def test_gladia_too_long_and_error():
    st = Settings(gladia_api_key="g", gladia_poll_interval_s=0, max_audio_seconds=60)
    c, _ = gladia_client(duration=120)
    with pytest.raises(ServiceError) as e:
        await GladiaTranscriber(st, c).transcribe(b"x", "a.wav", "audio/wav")
    assert e.value.code == "audio_too_long"
    c, _ = gladia_client(final="error")
    with pytest.raises(ServiceError) as e:
        await GladiaTranscriber(st, c).transcribe(b"x", "a.wav", "audio/wav")
    assert e.value.code == "stt_failed"


# ---- API ----
class FakePlanner:
    async def plan(self, instruction, today):
        return GOOD, "fake/model"


class FakeStt:
    async def transcribe(self, data, filename, content_type, language=None):
        return Transcript("tomorrow wake up at seven", "en", 3.0)


@pytest.fixture
def client():
    s = Settings(max_audio_bytes=100, ai_backend_api_key="")
    app.dependency_overrides[get_settings] = lambda: s
    app.dependency_overrides[get_planner] = lambda: FakePlanner()
    app.dependency_overrides[get_transcriber] = lambda: FakeStt()
    yield TestClient(app)
    app.dependency_overrides.clear()


def test_api_generate(client):
    r = client.post("/ai/generate-routine", json={"instruction": "tomorrow ...", "referenceDate": "2026-10-29"})
    assert r.status_code == 200 and r.json()["status"] == "draft" and len(r.json()["items"]) == 4
    assert client.post("/ai/generate-routine", json={"instruction": "x", "referenceDate": "bad"}).status_code == 422
    assert client.post("/ai/generate-routine", json={"instruction": ""}).status_code == 422


def test_api_transcribe_and_limits(client):
    ok = client.post("/ai/transcribe", files={"audio": ("a.wav", b"1234", "audio/wav")})
    assert ok.status_code == 200 and ok.json()["transcript"].startswith("tomorrow")
    assert client.post("/ai/transcribe", files={"audio": ("a.wav", b"x" * 101, "audio/wav")}).status_code == 413
    assert client.post("/ai/transcribe", files={"audio": ("a.exe", b"1", "audio/wav")}).status_code == 415
    assert client.post("/ai/transcribe", files={"audio": ("a.wav", b"", "audio/wav")}).status_code == 422


def test_api_speech_to_routine_and_auth(client):
    r = client.post("/ai/speech-to-routine", files={"audio": ("a.m4a", b"1234", "audio/mp4")})
    assert r.status_code == 200 and r.json()["proposal"]["source"] == "speech"
    app.dependency_overrides[get_settings] = lambda: Settings(ai_backend_api_key="secret")
    assert client.post("/ai/generate-routine", json={"instruction": "x"}).status_code == 401
    assert client.post("/ai/generate-routine", json={"instruction": "x"},
                       headers={"X-API-Key": "secret"}).status_code == 200


def test_cors_dev_localhost(client):
    r = client.options("/ai/generate-routine", headers={
        "Origin": "http://localhost:54321", "Access-Control-Request-Method": "POST",
        "Access-Control-Request-Headers": "content-type"})
    assert r.headers.get("access-control-allow-origin") == "http://localhost:54321"


def test_named_weekday_is_resolved_deterministically():
    from datetime import date
    from app.schemas import GenerateRoutineRequest
    req = GenerateRoutineRequest(instruction="On Saturday breakfast at 8 and Samstag nothing else",
                                 requesterRole="participant")
    raw = {"items": [{"title": "Breakfast", "date": "2026-11-01", "startTime": "08:00"},  # LLM said Sunday
                     {"title": "Football", "date": None, "startTime": "14:00"},
                     {"title": "Movie", "date": "2026-11-07", "startTime": "20:00"}]}  # a Saturday: kept
    p = build_proposal(raw, req, "text", "m", date(2026, 10, 29))  # Thursday
    assert [i.date for i in p.items] == ["2026-10-31", "2026-10-31", "2026-11-07"]
    assert "date_corrected" in codes(p)
    # Two different weekdays named: leave the model's dates alone.
    req2 = GenerateRoutineRequest(instruction="Friday gym, Saturday football", requesterRole="participant")
    p2 = build_proposal({"items": [{"title": "Gym", "date": "2026-10-30", "startTime": "10:00"}]},
                        req2, "text", "m", date(2026, 10, 29))
    assert p2.items[0].date == "2026-10-30"
