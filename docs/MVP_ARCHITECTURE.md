# BBW Visual Planner – MVP architecture

> "Complexity stays with the system and staff. Clarity reaches the participant."

This document describes the MVP added on `feat/participant-ui`. It is built
**additively**. The original demo (`lib/main.dart`, `ParticipantHome`,
`StaffDashboard`, `lib/models/schedule_item.dart`, `lib/services/`) is unchanged.

## Running

**Real backend (default).** `lib/main_mvp.dart` uses Supabase (auth, schedules,
progress, support requests, Realtime) and the FastAPI AI backend:

```bash
# 1. AI backend (once): put OPENROUTER_API_KEY=... into backend/.env (gitignored)
cd backend && python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
APP_ENV=dev .venv/bin/uvicorn app.main:app --port 8000
# 2. App (another terminal, repo root)
flutter run -d chrome -t lib/main_mvp.dart
# Android emulator: add --dart-define=AI_BACKEND_URL=http://10.0.2.2:8000
```

Sign in with the Supabase demo accounts in `supabase/README.md` (staff
`anna.weber.demo@example.com`, participant `lukas.demo@example.com`, …). The
shared demo password is not in git; ask the AI/DB lead. Live end-to-end test:
`flutter test test/integration/live_supabase_test.dart` (needs the backend
running and `supabase/.demo-credentials.local`).

Still local in this mode: library, routine templates, participant support
preferences, and the "acknowledged" state of support requests.

**Offline prototype (mock data):**

```bash
flutter run -d chrome -t lib/main_mvp.dart --dart-define=USE_MOCK_DATA=true
```

Mock demo accounts (password `demo` for all of them):

| Username | Role | Shows |
|---|---|---|
| `staff` | Staff | Professional interface |
| `admin` | Admin | Professional interface + library editing |
| `lena` | Participant | Minimal information, symbols only, reduced motion |
| `jonas` | Participant | Detailed information (what to bring, when to leave), 5/2/1-min warnings |
| `mia` | Participant | Standard information, photo-style visuals |
| `elias` | Participant | High contrast, large text |

The app starts with a **simulated time of 09:40 today**, during the morning
workshop, so the core scenario can be shown right away. You can change it
under Staff → Settings → Demo time.

Tests: `flutter test test/planner`

## Directory structure

```
lib/
  main_mvp.dart              MVP entry point (main.dart untouched)
  theme.dart                 Design tokens, palettes (standard / high contrast), category styles
  app/                       App root, service wiring, role-aware redirect, RoleGuard
  core/                      Pure domain layer (no screens)
    models/                  User/Role, Participant(+Profile), ScheduledEvent, ScheduleSnapshot,
                             ChangeEvent, SupportRequest, RoutineTemplate, library items, FeedEntry
    logic/                   FeedBuilder, ChangePlanner, ChangeFactory, ImpactChecker,
                             ChangeNoticeBuilder, ParticipantDay, CardPresentation, RoutineAssigner
    state/                   ChangeNotifier stores (schedule, participants, support, library, routines)
    auth/                    AuthService (+ MockAuthService), AuthController, RolePermissions
    ai/                      EventDraftGenerator (+ MockEventDraftGenerator)
    time/                    Clock (System / Fixed / DemoClock), TimeFormat
    data/                    Fictional demo data only
  widgets/                   Shared UI primitives (ActivityVisual, StatusBadge, CalmProgressBar, …)
  screens_auth/              AuthLayout, LoginPage, LoginForm
  screens_participant/       Participant UI (shell, today feed, cards, changes, details, week, help)
  screens_staff/             Staff UI (shell, today, participants, schedule, editor, changes,
                             preview, routines, library, settings, AI builder)
test/planner/                Logic and widget tests for the MVP
```

Each feature has its own folder. Changing one feature should not require
editing another feature's files.

## Role model

`Role { participant, staff, admin }` → `RolePermissions` (in `core/auth/permissions.dart`)
is the **only** place that maps roles to permissions. `RoleAwareRedirect` picks
the interface, and `RoleGuard` gates professional areas.

The participant interface contains **no** editing, deleting or publishing
widgets. Participants can only view, acknowledge changes and ask for help.

> ⚠️ This is UI-level gating only. Production must enforce the same rules
> server-side (for example Supabase row-level security). Hiding a button in the
> frontend is not authorisation.

## Schedule lifecycle

```
staff edit ──► DRAFT (ScheduleStore.drafts) ──► publish() ──► new ScheduleSnapshot vN+1
                    (participants never see drafts)          + ChangeEvent (who/what/when)
                                                                    │
participant sees snapshot vAck ◄── until "I understand" ◄───────────┘
participant acknowledges ──► sees vN+1, feed re-centres on NOW
```

* `ScheduledEvent` is one organisational event with `assignedParticipantIds`.
  Change it once, and every assigned schedule is affected.
* Every publish creates an immutable, versioned `ScheduleSnapshot`.
* `ScheduleStore.displayedSnapshotFor(participant)` keeps the participant on
  their last acknowledged version while a relevant change is pending. Cards
  never rearrange unexpectedly.
* Participants not affected by a change move to the new version silently.

## Participant experience

* **TODAY**: a finite vertical feed, built by `FeedBuilder`. It opens positioned on NOW.
  Scroll up for past activities and down for upcoming ones, ending with "That's everything planned for today."
* Every gap becomes a meaningful state: **Waiting** (≤ 15 min), **Free time**
  (longer), or "Your day starts at …". There is always a NOW.
* Cards: `TaskCard`, `TravelCard`, `FreeTimeCard`, `WaitingCard` (+ preparing) and
  `DayFinishedCard`, all built on `CardFrame`. They show **Done / Now / Next / Later** as text plus an icon, never colour alone.
* NOW card: calm `TimeProgress` ("About 20 min left"), an optional
  `TransitionWarning` (5 or 5/2/1 minutes), and "Next: …".
* Tapping a card opens `TaskDetailsPage`: where, with whom, what to bring, what to do, and what comes afterwards.
* **Plan changed**: a calm banner opens `ChangeNoticePage`. It shows what was
  cancelled, what happens instead, and that the next activity *still* starts at its time. The buttons are
  *I understand*, *More information* and *I need help*.
* **Add Something to Do**: a button on free-time cards. The participant chooses
  **Use AI** (types plain text, which is sent to `EventDraftGenerator`, or split
  locally if AI is unavailable) or **Do It Myself** (picks an idea, a start and a
  length). `FreeTimePlanner` keeps everything inside the free-time window, so staff
  activities are never touched. The result is published with
  `ScheduleStore.addParticipantEvents`. This does not show a "plan changed" notice, and
  the card says "You added this".
* **Task colours**: a colour band at the top of the card, when staff gave the task a colour.
* **WEEK**: a simple visual row per day.
* **HELP**: four large options. Each needs a confirmation step, then creates a support request.

## Staff experience

Sidebar sections: **Today · Participants · Schedule · Routines · Library · Settings**.

* **Today**: what needs attention: open support requests, unacknowledged changes,
  overlaps, changes today, preparation, drafts. It also has support requests
  (open → acknowledged → resolved) and each participant's now/next.
* **Participants**: search, detail page, support preferences editor,
  **Preview as Participant** and assign routine.
* **Schedule**: Day (time grid with overlap layout), Week and Participant views,
  *Add manually*, *Build with AI*, plus publishing of drafts.
* **Activity editor**: library pre-fill, all fields from the brief, a **Task Colour**
  picker (`TaskColor`; mustard is left out because it means "changed"), a live
  impact check, and **Save Draft · Preview · Publish**.
* **Groups** (Participants page): staff create named groups (`GroupStore`). Every
  `ParticipantSelector` shows them as one-tap chips (editor, assign routine, Build
  with AI), so activities, changes and routines reach a whole group at once.
* **Cancel activity…**: `ChangeManagementPage`. It runs: (1) "What happens instead?"
  (Free time / Replacement / Move another activity / Plan B), (2) impact, (3) participant
  preview, then **Publish change**.
* **Routines**: templates you can create, edit, duplicate and assign. Assigning creates *drafts*.
* **Library**: activities, places, people and pictograms (adding requires the admin role).

### Cancellation rules

| Case | Staff choice | Result |
|---|---|---|
| A | Replacement activity | New event in the same slot, same participants |
| B | Free time | Gap becomes Free time; nothing else moves |
| C | Move another activity | Only the activity staff picked moves, to the time staff picked |
| – | Plan B | Library Plan B activity in the same slot |

The app **never** moves the next activity on its own (see `ChangePlanner` and
the test `the next activity is NOT pulled earlier automatically`).

### Preview as participant

`ParticipantPreview` renders the real participant widgets (`ParticipantTodayView`,
`ChangeNoticePage`) inside a phone frame. They are wrapped in
`ParticipantPresentationScope` with that participant's profile, so the preview and the real
UI cannot drift apart. Unpublished changes are previewed with hypothetical
snapshots (`ScheduleSnapshot.applying`) and `ChangeFactory`.

## Mock vs real

| Area | Prototype | Needs backend integration |
|---|---|---|
| Authentication | `MockAuthService`, in-memory demo accounts | Supabase Auth behind `AuthService` |
| Schedules | `ScheduleStore` + `InMemoryScheduleRepository` | Supabase table/realtime behind `ScheduleRepository` |
| Authorisation | `RolePermissions` in the UI | Server-side RLS policies |
| Support requests | `SupportRequestStore` (local) | Push to staff devices |
| AI "Build with AI" | `MockEventDraftGenerator` (rule-based, offline) | Gemini via the backend team's service |
| Reminders | Visual transition warnings while the app is open | OS notifications (`flutter_local_notifications` / push) |
| Sound / vibration | Stored preferences only | Platform audio / haptics |
| Photos | Illustrated placeholders + ARASAAC pictograms | Approved institution photo storage |
| Time | `DemoClock` (shiftable for demos) | `SystemClock` |
| Offline | Architecture ready (`ScheduleRepository`) | Cache the last published snapshot locally |

## How to…

**Add a participant card type.** Add a value to `FeedEntryKind`, produce it in
`FeedBuilder`, create `screens_participant/cards/<name>_card.dart` built on
`CardFrame`, and map it in `FeedEntryCard`.

**Add a staff feature.** Create `screens_staff/<feature>/`, add an
`AdminDestination` in `admin_shell.dart`, and add its page to `_page()`.

**Change colours.** Edit only `lib/theme.dart` ("Groovy Calm"). `PlannerPalette` has
three variants: `standard` (light), `highContrast` (participant option) and `dark` (staff
only, toggled from the staff app bar via `AdminThemeController` in `lib/app/admin_theme.dart`).
Each meaning is a `SemanticTone` (`color` = text-safe, `accent` = pure hue, `soft` = tint):
petrol = work, lavender = support, apricot = travel, mustard = change, dusty blue =
residential/personal, sage = free time and meals. Red (`danger`) is only for real errors.
Use `CategoryStyle.of(category, context.palette)` for categories.
`test/planner/theme_contrast_test.dart` checks WCAG AA for every palette.
These display colours replace the CLAUDE.md §5 hex values in the UI. The legacy
`ScheduleItem.colorHex` data is unchanged.

**Change information density.** Edit `CardPresentation.forProfile` in
`core/logic/presentation_rules.dart`. Cards only read that object.

**Replace mock services.** Implement `AuthService`, `ScheduleRepository` and
`EventDraftGenerator`, then wire them in `AppServices`. Screens do not change.

## Integration notes for the team

* **Not yet synced to Supabase** (backend change needed in `lib/services/supabase_sync.dart`):
  * `ScheduledEvent.color` and `ScheduledEvent.createdByParticipantId`. Add them to
    `meta` in `_toItem` and read them in `_fromRow`.
  * Participant groups. These are only in `GroupStore` (in memory).
  * Participants publishing their own activities may also need an RLS policy.
* **UI text style**: buttons, headings, tabs, badges and form labels use Title Case.
  Sentences, hints and status messages use sentence case.

* `lib/main.dart` still runs the original demo. To switch to the MVP during final
  integration, change it to `runApp(const PlannerApp());` (import
  `app/planner_app.dart`).
* The locked `ScheduleItem` model is untouched. `ActivityCategory.legacyCode`
  maps categories to its category codes when the two need bridging.
* `test/widget_test.dart` (Flutter template) was already broken before this
  work (it references `MyApp`). It is left untouched.
