# OnTime

A TEACCH-inspired visual daily and weekly planner for **Caritas-Don Bosco (BBW Würzburg)**. It has two interfaces:

- **Participants** get a calm, visual "Now / Next" feed, a week view and help requests. They can mark activities as done and plan their own free time by typing or speaking.
- **Staff** manage participants and schedules, build drafts with AI (typed or dictated), add photos to activities, manage changes, and preview the participant view.

Built with Flutter (Android + Web), Supabase (auth, Postgres with RLS, Realtime, Storage) and a small FastAPI AI backend (OpenRouter).

## Features

| Area | What it does |
|---|---|
| Login | Supabase email login, session restore, role from `profiles` (staff / participant) |
| Schedules | Daily/weekly schedules, draft → publish, calm "plan changed" notices, Realtime updates across devices |
| Progress | Participants mark activities done (secure RPC); staff see "Done today: x of y" |
| Help | Participant support requests; staff acknowledge/resolve |
| Build with AI (staff) | Typed or spoken text → AI draft → staff review → publish. AI never publishes |
| Voice input | Device speech recognition (`speech_to_text`), German/English, no extra API key |
| Task photos | Staff add photos per activity (private Storage bucket, EXIF/GPS stripped, signed URLs); pictogram fallback |
| Plan my free time (participants) | Speak or type plans for genuinely free time. The database checks that nothing overlaps official activities, other plans or staff restrictions. Official activities can never be changed by participants |
| Staff UI | Today dashboard, participants, groups, schedule (day/week), routines, library, task colours, dark mode |

## Run it

**1. AI backend** (needed for "Build with AI" and free-time planning):

```bash
cd backend && python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
```

Put `OPENROUTER_API_KEY=...` in `backend/.env` (gitignored; see `backend/.env.example`), then start the server:

```bash
cd backend && APP_ENV=dev .venv/bin/uvicorn app.main:app --port 8000
```

**2. App** (repo root):

```bash
flutter pub get
```

```bash
flutter run -d chrome -t lib/main_mvp.dart
```

- **Android emulator:** add `--dart-define=AI_BACKEND_URL=http://10.0.2.2:8000`.
- **Physical phone:** use `--dart-define=AI_BACKEND_URL=http://<your-LAN-IP>:8000`, and start the backend with `--host 0.0.0.0`.
- **Offline demo with mock data** (no Supabase or AI needed): add `--dart-define=USE_MOCK_DATA=true`. Mock accounts are `staff`, `admin`, `lena`, `jonas`, `mia` and `elias`, all with password `demo`.

### Demo accounts (Supabase)

| Email | Role |
|---|---|
| `anna.weber.demo@example.com` | Staff (Lukas, Mia) |
| `ben.schmidt.demo@example.com` | Staff (Mia, Jonas) |
| `lukas.demo@example.com`, `mia.demo@example.com`, `jonas.demo@example.com` | Participants |

The shared demo password is **not** in git. Ask the AI/DB lead for it, and keep it in `supabase/.demo-credentials.local` (gitignored).

## Tests

```bash
flutter analyze
```

```bash
flutter test test/planner test/widget_test.dart
```

```bash
backend/.venv/bin/pytest -q backend
```

The live tests run against the real Supabase project and need the backend running and the demo password file:

```bash
flutter test test/integration
```

```bash
SUPABASE_URL=https://byuyanzfawjbuzlzbpev.supabase.co SUPABASE_ANON_KEY=sb_publishable_8TPJYscN6tp1_yhFHOvAEw_uoMkUNRN backend/.venv/bin/python -m pytest supabase/tests -q
```

## Project layout

```
lib/
  main_mvp.dart          entry point (Supabase + AI; mock mode via USE_MOCK_DATA)
  app/                   service wiring (AppServices), routing, theme scope
  core/                  domain logic, no widgets (models, schedule store, free-time rules)
  services/              Supabase sync/auth, AI client, speech input, task photos, free-time backend
  screens_participant/   participant UI (today feed, week, help, plan my free time)
  screens_staff/         staff UI
  widgets/               shared widgets
backend/                 FastAPI AI service (OpenRouter, deterministic validation)
supabase/                migrations, demo seed, RLS tests, integration guide (supabase/README.md)
docs/MVP_ARCHITECTURE.md architecture and how to extend it
```

## Security and privacy

- **Authorization lives in Postgres.** Every table has RLS, and sensitive changes go through RPCs (publishing, completion, participant plans). The Flutter app holds only the public Supabase publishable key, never a service-role key.
- **The OpenRouter key stays in the backend environment.** The app never calls OpenRouter directly.
- **No names or IDs are sent to the AI**, only the instruction text. Speech is recognised on the device by its own speech service; no audio is sent to our servers.
- **Photos are stored in a private bucket** under random file names, with metadata removed.
- **This is a hackathon prototype with fictional data.** It is not GDPR-certified. Before any real use: run a privacy review, rotate the demo passwords, disable public sign-ups, and serve the AI backend over HTTPS.

## Known limitations

- Not yet tested on a physical Android device (dictation, permissions).
- Library, routine templates, groups and participant display preferences are stored on the device only.
- There is no staff screen yet for "unavailable periods" (they are set in the database).
