-- Core schema. Roles come ONLY from public.profiles (written by admin/service role), never from client metadata.
create schema if not exists app;
revoke all on schema app from public, anon;
grant usage on schema app to authenticated;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (length(btrim(display_name)) between 1 and 80),
  role text not null check (role in ('participant','staff')),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.staff_participants (
  staff_id uuid not null references public.profiles(id) on delete cascade,
  participant_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (staff_id, participant_id),
  check (staff_id <> participant_id)
);
create index on public.staff_participants (participant_id);

create table public.schedules (
  id uuid primary key default gen_random_uuid(),
  participant_id uuid not null references public.profiles(id) on delete cascade,
  schedule_date date not null,
  status text not null default 'draft' check (status in ('draft','published')),
  created_by uuid not null references public.profiles(id),
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (participant_id, schedule_date),
  check ((status = 'published') = (published_at is not null))
);
create index on public.schedules (schedule_date);

create table public.activities (
  id uuid primary key default gen_random_uuid(),
  schedule_id uuid not null references public.schedules(id) on delete cascade,
  title text not null check (length(btrim(title)) between 1 and 120),
  description text check (length(description) <= 1000),
  start_time time,  -- nullable: unspecified times are never invented
  end_time time,
  sort_order integer not null default 0,
  status text not null default 'pending' check (status in ('pending','completed')),
  completed_at timestamptz,
  icon_key text check (length(icon_key) <= 40),
  category text check (category in ('BBW_TRAINING','RESIDENTIAL','BREAK','PERSONAL')),
  pictogram_url text check (length(pictogram_url) <= 500),
  location text check (length(location) <= 120),
  staff_name text check (length(staff_name) <= 80),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_time is null or start_time is not null),
  check (end_time is null or end_time > start_time),
  check ((status = 'completed') = (completed_at is not null))
);
create index on public.activities (schedule_id, sort_order);

create table public.activity_steps (
  id uuid primary key default gen_random_uuid(),
  activity_id uuid not null references public.activities(id) on delete cascade,
  title text not null check (length(btrim(title)) between 1 and 120),
  sort_order integer not null default 0,
  duration_min integer check (duration_min between 1 and 600),  -- nullable, never invented
  is_completed boolean not null default false,
  completed_at timestamptz,
  check (is_completed = (completed_at is not null))
);
create index on public.activity_steps (activity_id, sort_order);

create table public.activity_events (
  id uuid primary key default gen_random_uuid(),
  activity_id uuid not null references public.activities(id) on delete cascade,
  actor_id uuid not null references public.profiles(id),
  event_type text not null check (event_type in
    ('completed','uncompleted','step_completed','step_uncompleted','attendance_verified')),
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now()
);
create index on public.activity_events (activity_id, created_at desc);
create index on public.activity_events (actor_id);

create table public.attendance (
  id uuid primary key default gen_random_uuid(),
  activity_id uuid not null unique references public.activities(id) on delete cascade,
  verified_by uuid not null references public.profiles(id),
  attendance_status text not null check (attendance_status in ('present','absent','late','excused')),
  verified_at timestamptz not null default now()
);

create table public.support_requests (
  id uuid primary key default gen_random_uuid(),
  participant_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  activity_id uuid references public.activities(id) on delete set null,
  request_type text not null check (request_type in ('help','more_time','break','change')),
  note text check (length(note) <= 500),
  status text not null default 'open' check (status in ('open','resolved')),
  created_at timestamptz not null default now(),
  resolved_by uuid references public.profiles(id),
  resolved_at timestamptz,
  check ((status = 'resolved') = (resolved_at is not null and resolved_by is not null))
);
create index on public.support_requests (participant_id, status);

-- activity_id has no FK on purpose: history must survive activity deletion.
create table public.schedule_changes (
  id uuid primary key default gen_random_uuid(),
  schedule_id uuid not null references public.schedules(id) on delete cascade,
  activity_id uuid,
  changed_by uuid not null references public.profiles(id),
  old_values jsonb,
  new_values jsonb,
  created_at timestamptz not null default now()
);
create index on public.schedule_changes (schedule_id, created_at desc);

-- ---------- helpers (SECURITY DEFINER, empty search_path, not exposed through the API) ----------
create function app.is_staff() returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'staff' and p.is_active) $$;
create function app.is_participant() returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'participant' and p.is_active) $$;
create function app.is_assigned(p_participant uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select app.is_staff() and exists (select 1 from public.staff_participants sp
    where sp.staff_id = (select auth.uid()) and sp.participant_id = p_participant) $$;
create function app.staff_manages_schedule(p_schedule uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.schedules s where s.id = p_schedule and app.is_assigned(s.participant_id)) $$;
create function app.staff_manages_activity(p_activity uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.activities a where a.id = p_activity and app.staff_manages_schedule(a.schedule_id)) $$;
create function app.can_read_schedule(p_schedule uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.schedules s where s.id = p_schedule and (
    app.is_assigned(s.participant_id)
    or (s.participant_id = (select auth.uid()) and s.status = 'published' and app.is_participant()))) $$;
create function app.can_read_activity(p_activity uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.activities a where a.id = p_activity and app.can_read_schedule(a.schedule_id)) $$;
revoke execute on all functions in schema app from public, anon;
grant execute on all functions in schema app to authenticated;

-- ---------- integrity triggers ----------
create function app.touch_updated_at() returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at := now(); return new; end $$;
create trigger trg_schedules_touch before update on public.schedules for each row execute function app.touch_updated_at();
create trigger trg_activities_touch before update on public.activities for each row execute function app.touch_updated_at();

create function app.check_roles() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_table_name = 'staff_participants' then
    if not exists (select 1 from public.profiles where id = new.staff_id and role = 'staff')
       or not exists (select 1 from public.profiles where id = new.participant_id and role = 'participant') then
      raise exception 'assignment requires a staff and a participant profile';
    end if;
  elsif not exists (select 1 from public.profiles where id = new.participant_id and role = 'participant') then
    raise exception 'participant_id must be a participant profile';
  end if;
  return new;
end $$;
create trigger trg_sp_roles before insert or update on public.staff_participants for each row execute function app.check_roles();
create trigger trg_sched_roles before insert or update of participant_id on public.schedules for each row execute function app.check_roles();

-- ---------- audit trail (written by triggers only; clients have no write grants) ----------
create function app.log_activity_change() returns trigger language plpgsql security definer set search_path = '' as $$
declare v_sched uuid := coalesce(new.schedule_id, old.schedule_id); v_old jsonb; v_new jsonb; v_actor uuid;
begin
  if tg_op = 'UPDATE' then
    v_old := to_jsonb(old) - 'status' - 'completed_at' - 'updated_at';
    v_new := to_jsonb(new) - 'status' - 'completed_at' - 'updated_at';
    if v_old = v_new then return null; end if;  -- completion is not a schedule change
  elsif tg_op = 'INSERT' then v_new := to_jsonb(new);
  else v_old := to_jsonb(old); end if;
  -- only published schedules are audited; null when the schedule is being cascade-deleted
  select coalesce((select auth.uid()), s.created_by) into v_actor
    from public.schedules s where s.id = v_sched and s.status = 'published';
  if v_actor is null then return null; end if;
  insert into public.schedule_changes (schedule_id, activity_id, changed_by, old_values, new_values)
  values (v_sched, coalesce(new.id, old.id), v_actor, v_old, v_new);
  return null;
end $$;
create trigger trg_activities_audit after insert or update or delete on public.activities
  for each row execute function app.log_activity_change();

create function app.log_schedule_change() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'UPDATE' and old.status = new.status and old.schedule_date = new.schedule_date then return null; end if;
  insert into public.schedule_changes (schedule_id, changed_by, old_values, new_values)
  values (new.id, coalesce((select auth.uid()), new.created_by),
    case when tg_op = 'UPDATE' then jsonb_build_object('status', old.status, 'schedule_date', old.schedule_date) end,
    jsonb_build_object('status', new.status, 'schedule_date', new.schedule_date));
  return null;
end $$;
create trigger trg_schedules_audit after insert or update on public.schedules
  for each row execute function app.log_schedule_change();
