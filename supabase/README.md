# Supabase backend (project `CARETAS-HACKATHON`, id `byuyanzfawjbuzlzbpev`, eu-west-1)

Authorization lives in Postgres RLS + RPCs, not in Flutter. The AI backend never writes here: Flutter sends an **approved** proposal to `save_schedule`.

```
URL  https://byuyanzfawjbuzlzbpev.supabase.co
KEY  sb_publishable_8TPJYscN6tp1_yhFHOvAEw_uoMkUNRN   # publishable = safe in the app. NEVER put a service_role/secret key in Flutter.
```
`supabase_flutter` is already in pubspec. Migrations: `supabase/migrations/*.sql` (apply in order). Demo data: `supabase/seed/demo_data.sql`. Live tests: `supabase/tests`.

## Demo accounts (fictional, all share one password)
Password is in the gitignored `supabase/.demo-credentials.local` (ask the AI/DB lead; rotate before any real use).
| Email | Role | Assigned |
|---|---|---|
| anna.weber.demo@example.com | staff | Lukas, Mia |
| ben.schmidt.demo@example.com | staff | Mia, Jonas |
| lukas.demo@example.com / mia.demo@example.com / jonas.demo@example.com | participant | – |

Re-seed on a fresh project: run the migrations, then `select set_config('app.demo_password','<pw>',false);` followed by `demo_data.sql` in the SQL editor.

## Flutter (all via `Supabase.instance.client`)
```dart
await Supabase.initialize(url: kSupabaseUrl, anonKey: kSupabasePublishableKey);   // restores the saved session automatically
final db = Supabase.instance.client;

// Login / logout / session restore
await db.auth.signInWithPassword(email: e, password: p);
await db.auth.signOut();                                  // invalidates the session
final user = db.auth.currentUser;                         // null => show login
db.auth.onAuthStateChange.listen((s) { /* route by s.session */ });

// Profile + role (route to staff or participant UI). No profile row => no access.
final me = await db.from('profiles').select().eq('id', user!.id).single();   // me['role'] == 'staff' | 'participant'

// Staff: assigned participants
final mine = await db.from('staff_participants')
    .select('participant:profiles!participant_id(id, display_name)');

// Daily schedule (participants automatically get only their own PUBLISHED schedules; staff get drafts too)
final day = await db.from('schedules')
    .select('*, activities(*, activity_steps(*))')
    .eq('participant_id', pid).eq('schedule_date', '2026-10-30')
    .order('sort_order', referencedTable: 'activities')
    .order('sort_order', referencedTable: 'activities.activity_steps').maybeSingle();

// Weekly
final week = await db.from('schedules').select('*, activities(*, activity_steps(*))')
    .eq('participant_id', pid).gte('schedule_date', mon).lte('schedule_date', sun).order('schedule_date');

// Staff: create/replace a DRAFT atomically from the approved AI proposal (items use the AI response field names), optionally publish
await db.rpc('save_schedule', params: {
  'p_participant_id': pid, 'p_schedule_date': '2026-10-30',
  'p_activities': proposal['items'],       // title,startTime,endTime,category,pictogramKeyword,location,subSteps[{title,durationMin}]
  'p_publish': false });
await db.rpc('publish_schedule', params: {'p_schedule_id': scheduleId});   // fails on empty or overlapping activities
await db.rpc('unpublish_schedule', params: {'p_schedule_id': scheduleId});

// Staff: edit one activity directly (title/time/location/... only; allowed on published schedules, change is audited)
await db.from('activities').update({'start_time': '09:30', 'location': 'Room 2'}).eq('id', activityId);

// Participant: complete (or undo) an activity / sub-step. ONLY these RPCs can change completion.
await db.rpc('complete_activity', params: {'p_activity_id': id, 'p_done': true});
await db.rpc('set_step_completed', params: {'p_step_id': id, 'p_done': true});

// Participant: support request (type: help | more_time | break | change). participant_id is set by the server.
await db.from('support_requests').insert({'request_type': 'more_time', 'activity_id': aid, 'note': 'optional'});
// Staff: list open requests, resolve
final open = await db.from('support_requests').select('*, participant:profiles!participant_id(display_name)').eq('status', 'open');
await db.rpc('resolve_support_request', params: {'p_request_id': rid});

// Staff: attendance (present | absent | late | excused); history; change log
await db.rpc('verify_attendance', params: {'p_activity_id': aid, 'p_status': 'present'});
final history = await db.from('activity_events').select().eq('activity_id', aid).order('created_at');
final changes = await db.from('schedule_changes').select().eq('schedule_id', sid).order('created_at');

// Monthly progress (participant: self; staff: assigned only) -> rows per day, sum client-side
final prog = await db.rpc('monthly_progress', params: {'p_participant_id': pid, 'p_month': '2026-10-01'});

// Realtime: schedule updates (RLS filters events per user)
db.channel('sched-$pid').onPostgresChanges(
  event: PostgresChangeEvent.all, schema: 'public', table: 'activities',
  callback: (p) => refresh()).subscribe();      // also: schedules, activity_steps, support_requests
```
Errors: RPC/DB failures throw `PostgrestException` (`code` 42501 = not allowed, PT404 = not found, 23514 = rule violated e.g. `overlapping_activities`, `empty_schedule`, `schedule_not_draft`).

**Mapping to `ScheduleItem`:** `timeRange` = `"${start_time.substring(0,5)} - ${end_time.substring(0,5)}"`, only start → just the start, none → show "no time set". `isCompleted = status == 'completed'`, `category`, `location`→`locationName`, `staff_name`→`staffName`, `pictogram_url` or ARASAAC lookup of `icon_key`; `activity_steps` → `SubStep` (`duration_min` can be null, `is_completed`). `isModifiedAlert` has no column yet: derive it from `schedule_changes` (staff only) or add later.

## Task photos (custom activity images)
Private bucket `task-images` (max 2 MB; JPEG/PNG/WebP). `activities.image_path` stores the **object path only**: `participants/{participant_id}/{random_uuid}.jpg`. Never store bytes, public URLs or signed URLs, and never put names in paths. `icon_key`/`pictogram_url` are unchanged and remain the fallback.

| Who | Upload | Read | Delete |
|---|---|---|---|
| Assigned staff | ✓ (their participants' folders) | ✓ | ✓ if no activity uses it |
| Participant | ✗ | own folder only | ✗ |
| Other staff / participants / anon | ✗ | ✗ | ✗ |

Objects are never overwritten: there is no UPDATE policy and `upsert` is refused. To replace a photo, upload a new one, repoint the activity, then delete the old one. The DB trigger rejects an `image_path` that is in another participant's folder (`image_wrong_participant`) or that doesn't exist (`image_not_found`).

`save_schedule` items accept `"imagePath"`. If an item has **no** `imagePath` key, its current photo is kept (planner sync and AI drafts never drop it); `"imagePath": null` removes it. Staff can also set it directly: `update activities set image_path = …` (RLS: assigned staff only).

**Flutter.** `services.photos` (an `ActivityPhotos`, null in mock mode) is the whole contract. It reuses the signed-in Supabase session and needs no extra keys:
```dart
final photos = AppScope.of(context).photos;            // null → hide the photo button
await photos?.setActivityPhoto(eventId: e.id, participantId: pid, original: bytes); // upload + attach + delete old
await photos?.removeActivityPhoto(eventId: e.id, participantId: pid);
photos?.hasPhoto(e.id, pid);
```
- `original` is the raw file from the picker (e.g. `image_picker` → `readAsBytes()`). The service decodes it, applies orientation, scales to max 1280 px, re-encodes as JPEG q80 and drops **all EXIF/GPS metadata** in a background isolate before upload. Typical result: 150–400 KB.
- Only **published** activities can get a photo. A shared event gets one photo per participant.
- Rendering needs no UI change. The sync turns `image_path` into a signed URL (valid 2 h, cached, refreshed automatically on reload) in `VisualRef.photoUrl`, and `ActivityVisual` shows it, falling back to the pictogram/icon on error. It respects the participant's "symbols only" preference as before.
- Low-level use: `TaskImageService(db)`: `upload`, `signedUrl(s)`, `deleteIfUnused`. Signed URLs are bearer links, so never log or persist them.

Live tests: `flutter test test/integration/live_task_photos_test.dart`.

## Security design (short)
- Roles exist only in `public.profiles`, written by admins/service role; clients have no insert/update on it. A signup with `role: staff` metadata gets no profile → sees nothing (tested).
- Client write grants are column-level: nobody can write `status`, `completed_at`, audit tables, attendance or events directly. Those change only via the RPCs above, which check the caller.
- SECURITY DEFINER functions use `search_path = ''`, `EXECUTE` only for `authenticated` (not anon); helpers live in a non-exposed `app` schema.
- Decisions: `schedule_changes` only logs **published** schedules and is staff-only (participants get live updates through Realtime; draft edits must not leak). Participants cannot see drafts. Assignments (`staff_participants`) and profiles are admin-managed (no client UI). `activity_events` rows are removed if their activity is deleted by staff.
- Skipped for the demo: notification delivery (use Realtime for now), media/photo storage, per-participant preferences.

## Manual settings still needed (Dashboard)
Authentication → Providers → Email: **disable "Allow new users to sign up"** (accounts must be created by an admin). Enable **leaked password protection** (Auth → Passwords; may need a paid plan). Rotate the demo password before showing outsiders.
