# Caritas AI backend (FastAPI)

AI never publishes anything. Every response is `status: "draft"`, `requiresApproval: true`. Persisting an approved plan is the Supabase service's job (not in this folder).

## Run
```bash
cd backend
python3 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt
cp .env.example .env            # fill OPENROUTER_API_KEY and GLADIA_API_KEY
.venv/bin/uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
.venv/bin/python -m pytest -q   # mocked tests, no keys needed
```
Docs UI: http://localhost:8000/docs · `GET /health` shows which keys are configured.

## Connecting from Flutter
| Client | Base URL |
|---|---|
| Chrome (`flutter run -d chrome`) | `http://localhost:8000` (CORS allows `localhost:*` only when `APP_ENV=dev`) |
| Android emulator | `http://10.0.2.2:8000` |
| Physical phone, same Wi-Fi | `http://<Mac LAN IP>:8000` (server must use `--host 0.0.0.0`; allow in macOS firewall) |
| Physical phone via USB | `adb reverse tcp:8000 tcp:8000`, then `http://localhost:8000` |

Android blocks plain HTTP by default (API 28+): a debug build needs `android:usesCleartextTraffic="true"` in `android/app/src/debug/AndroidManifest.xml` (frontend team's call; production must be HTTPS). Outside dev set `CORS_ORIGINS` explicitly. If `AI_BACKEND_API_KEY` is set, send `X-API-Key` (do not ship a real one in the app; replace with Supabase JWT checks later).
Remove the client-side Gemini key in `lib/services/ai_routine_service.dart` and call this API instead.

Errors: HTTP 4xx/5xx with `{"detail": {"code": "...", "message": "..."}}`. Codes: `unauthorized`, `audio_too_large`, `audio_too_long`, `unsupported_audio_type`, `empty_audio`, `empty_transcript`, `instruction_too_long`, `planner_failed`, `stt_failed`, `stt_timeout`, `*_not_configured` (503).

## Endpoints
### `POST /ai/transcribe` (multipart)
Fields: `audio` (file: wav, mp3, m4a, aac, ogg, opus, flac, webm; max 10 MB / 60 s), `language` (optional `de`|`en`; omitted = detect between de/en).
```json
{"transcript": "Morgen um sieben aufstehen ...", "language": "de", "durationSec": 6.2}
```
### `POST /ai/generate-routine` (JSON)
```json
{"instruction": "Tomorrow I want to wake up at seven, brush my teeth, shower, have breakfast at eight, and go to vocational training at nine.",
 "referenceDate": "2026-10-29", "requesterRole": "participant", "participantId": "demo-lukas",
 "existingItems": [{"title": "Workshop", "date": "2026-10-30", "startTime": "09:00", "endTime": "11:00"}]}
```
Only `instruction` is required. `referenceDate` = "today" for resolving relative days (default: today in Europe/Berlin).
### `POST /ai/speech-to-routine` (multipart)
`audio` + optional `language`, `referenceDate`, `requesterRole`, `participantId`. Returns `{transcript, language, proposal}`. Show the transcript in an editable field; if the user edits it, re-submit via `/ai/generate-routine`.

### Proposal response (`RoutineProposal`)
```json
{"proposalId": "uuid", "status": "draft", "requiresApproval": true, "source": "text",
 "participantId": "demo-lukas", "date": "2026-10-30", "valid": true, "model": "google/gemma-4-31b-it:free",
 "items": [{"id": "uuid", "title": "Wake up", "category": "PERSONAL", "colorHex": 8412884,
            "date": "2026-10-30", "startTime": "07:00", "endTime": null, "timeRange": "07:00",
            "locationName": "", "staffName": "", "pictogramUrl": "", "pictogramKeyword": "bed",
            "createdByStaff": false, "isModifiedAlert": false, "isCompleted": false, "subSteps": []},
           {"id": "uuid", "title": "Brush teeth", "startTime": null, "timeRange": "", "...": "..."}],
 "issues": [{"severity": "info", "code": "missing_time", "message": "No time was given for this activity.", "itemIndex": 1}],
 "missingInformation": ["No time given for brushing teeth"]}
```
- Items match `ScheduleItem` field names (`id,title,category,colorHex,timeRange,locationName,staffName,pictogramUrl,createdByStaff,isModifiedAlert,isCompleted,subSteps`) and colours match `schedule_item.dart`.
- **Proposed model changes (not made, need frontend agreement):** `ScheduleItem` gets optional `date`, `startTime`, `endTime`; `SubStep.durationMin` becomes nullable (we never invent durations); `timeRange` may be `""`; show "add a time" in the preview. Resolve `pictogramKeyword` through ARASAAC as the existing service does.
- `issues.severity`: `error` blocks approval (`valid=false`: `overlap`, `invalid_time`, `invalid_date`, `invalid_range`, `missing_title`, `no_activities`, `unsupported_action`, `too_many_items`); `warning` (`duplicate_activity`, `order_mismatch`, `conflict_existing`, `unsupported_request`, ...) and `info` (`missing_time`, `missing_end_time`) are shown but allow approval.
- `requesterRole` is a client claim and sets only `createdByStaff`. Real authorisation comes with Supabase auth.

## Models (set by env, swap without code changes)
Primary `google/gemma-4-31b-it:free` (open-weight Gemma; supports `response_format`), fallback `nvidia/nemotron-3.5-super-vl:free` (open-weight; supports structured outputs). Chosen from OpenRouter's live model list on 2026-10-29; **instruction-following quality is unverified until a live test**. Free tier: 20 req/min, 50 req/day (1000/day after buying 10 credits). Free endpoints can be unavailable or slow; the backend tries primary then fallback.

## Privacy (read before real data)
Prototype = fictional participant data only. This is not GDPR compliance.
- **Gladia** (hosted): audio and transcripts leave our server. Needs a DPA, a confirmed EU processing region, and a retention check. We request job deletion after each transcript (best effort, unverified live).
- **OpenRouter**: forwards prompts to third-party providers, often US-based. Free endpoints may log or train on prompts, so no real data. Open weights do not make the hosted call private.
- We hold audio in memory only (no temp files), enforce size/duration limits, and never log audio, transcripts or instructions.
- Real deployment needs HTTPS, auth, consent and a records-of-processing review. Self-hosted Whisper in the EU removes the Gladia transfer.

## Supabase handoff
Not implemented. The Supabase service should: accept an approved, possibly edited proposal; re-validate (reuse `app/validation.py` or equivalent); check the caller's role; then write. `proposalId` and item `id`s are UUIDs; replace or keep them on insert as you prefer. Nothing in `app/` touches a database.
