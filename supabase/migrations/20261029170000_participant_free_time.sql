-- Participant free-time planning ("Plan my free time").
--
-- Design: personal activities live in their own table instead of public.activities.
-- * Staff days are replaced atomically by save_schedule (unmatched rows are deleted) and
--   publishing rejects overlaps; mixing participant rows into them would either wipe them or
--   block staff. A separate table keeps official schedules, history and attendance untouched.
-- * Origin is structural: participants have NO write grant on activities or this table; the
--   only way in is save_personal_free_time_plan, which derives the participant from auth.uid().
-- * Availability is computed here, never trusted from the client or the AI:
--     busy = official activities (published AND staff drafts) + personal activities
--            + staff-defined unavailable periods, inside a configurable planning window.
--   Conservative rules: an official activity WITHOUT a time blocks the whole day (staff must
--   set a time first); one with a start but no end blocks until the next official start (or
--   the end of the window). A whole-day unavailable period blocks the day.
-- * save_personal_free_time_plan and save_schedule take the same per-participant-per-day
--   advisory lock, so concurrent writes are serialised and re-checked.
-- * Saved personal activities are read-only for participants (only completion via RPC);
--   assigned staff may delete them.

-- ---------- configuration ----------
create table public.planning_settings (
  id boolean primary key default true check (id),
  window_start time not null default '07:00',
  window_end time not null default '22:00',
  max_days_ahead int not null default 30 check (max_days_ahead between 1 and 365),
  max_items int not null default 15 check (max_items between 1 and 30),
  check (window_end > window_start)
);
insert into public.planning_settings default values;
alter table public.planning_settings enable row level security;
create policy planning_settings_read on public.planning_settings for select to authenticated using (true);
grant select on public.planning_settings to authenticated;

-- ---------- staff-defined restrictions ----------
create table public.unavailable_periods (
  id uuid primary key default gen_random_uuid(),
  participant_id uuid not null references public.profiles(id) on delete cascade,
  period_date date not null,
  start_time time,            -- both null = the whole day
  end_time time,
  reason text check (length(reason) <= 120),
  created_by uuid default auth.uid() references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  check ((start_time is null) = (end_time is null)),
  check (end_time is null or end_time > start_time)
);
create index on public.unavailable_periods (participant_id, period_date);
alter table public.unavailable_periods enable row level security;
create policy unavailable_read on public.unavailable_periods for select to authenticated
  using (app.is_assigned(participant_id) or participant_id = (select auth.uid()));
create policy unavailable_insert on public.unavailable_periods for insert to authenticated
  with check (app.is_assigned(participant_id));
create policy unavailable_delete on public.unavailable_periods for delete to authenticated
  using (app.is_assigned(participant_id));
grant select, delete on public.unavailable_periods to authenticated;
grant insert (participant_id, period_date, start_time, end_time, reason) on public.unavailable_periods to authenticated;

-- ---------- participant-created activities ----------
create table public.personal_activities (
  id uuid primary key default gen_random_uuid(),
  participant_id uuid not null references public.profiles(id) on delete cascade,
  activity_date date not null,
  title text not null check (length(btrim(title)) between 1 and 80),
  start_time time not null,
  end_time time not null,
  icon_key text check (icon_key ~ '^[a-z_]{1,40}$'),
  pictogram_url text check (pictogram_url ~ '^https://static\.arasaac\.org/pictograms/[0-9]{1,7}/[0-9]{1,7}_[0-9]{3}\.png$'),
  status text not null default 'pending' check (status in ('pending', 'completed')),
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  check (end_time > start_time),
  check ((status = 'completed') = (completed_at is not null))
);
create index on public.personal_activities (participant_id, activity_date);
alter table public.personal_activities enable row level security;
create policy personal_read on public.personal_activities for select to authenticated
  using ((participant_id = (select auth.uid()) and app.is_participant()) or app.is_assigned(participant_id));
create policy personal_delete on public.personal_activities for delete to authenticated
  using (app.is_assigned(participant_id));
-- No insert/update grants: participants write only through the RPCs below.
grant select, delete on public.personal_activities to authenticated;

alter publication supabase_realtime add table public.personal_activities, public.unavailable_periods;

-- ---------- availability engine ----------
create function app.lock_planning_day(p_participant uuid, p_date date) returns void
language sql set search_path = '' as $$
  select pg_advisory_xact_lock(hashtextextended('planning:' || p_participant::text || ':' || p_date::text, 0)) $$;

-- Busy periods + window for one participant/day. Caller must already be authorised.
create function app.planning_day(p_participant uuid, p_date date) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_set public.planning_settings; v_busy jsonb := '[]'::jsonb; v_blocked text; r record; v_end time;
begin
  select * into v_set from public.planning_settings limit 1;
  select coalesce(u.reason, 'Staff have marked this day as not available.') into v_blocked
    from public.unavailable_periods u
    where u.participant_id = p_participant and u.period_date = p_date and u.start_time is null limit 1;
  if v_blocked is null then
    select 'An activity on this day has no time yet ("' || a.title || '"). Please ask staff.' into v_blocked
      from public.activities a join public.schedules s on s.id = a.schedule_id
      where s.participant_id = p_participant and s.schedule_date = p_date and a.start_time is null limit 1;
  end if;

  for r in
    select a.start_time, a.end_time, s.status,
           case when s.status = 'published' then a.title else 'Reserved by staff' end as title,
           (select min(b.start_time) from public.activities b where b.schedule_id = a.schedule_id
              and b.start_time > a.start_time) as next_start
    from public.activities a join public.schedules s on s.id = a.schedule_id
    where s.participant_id = p_participant and s.schedule_date = p_date and a.start_time is not null
  loop
    v_end := coalesce(r.end_time, least(coalesce(r.next_start, v_set.window_end), v_set.window_end));
    if v_end <= r.start_time then v_end := v_set.window_end; end if;
    v_busy := v_busy || jsonb_build_object('start', to_char(r.start_time, 'HH24:MI'), 'end', to_char(v_end, 'HH24:MI'),
      'kind', 'official', 'title', r.title, 'timeUnknown', r.end_time is null);
  end loop;
  for r in select start_time, end_time, title from public.personal_activities
           where participant_id = p_participant and activity_date = p_date loop
    v_busy := v_busy || jsonb_build_object('start', to_char(r.start_time, 'HH24:MI'), 'end', to_char(r.end_time, 'HH24:MI'),
      'kind', 'personal', 'title', r.title, 'timeUnknown', false);
  end loop;
  for r in select start_time, end_time, reason from public.unavailable_periods
           where participant_id = p_participant and period_date = p_date and start_time is not null loop
    v_busy := v_busy || jsonb_build_object('start', to_char(r.start_time, 'HH24:MI'), 'end', to_char(r.end_time, 'HH24:MI'),
      'kind', 'unavailable', 'title', coalesce(r.reason, 'Not available'), 'timeUnknown', false);
  end loop;

  return jsonb_build_object(
    'date', p_date,
    'windowStart', to_char(v_set.window_start, 'HH24:MI'),
    'windowEnd', to_char(v_set.window_end, 'HH24:MI'),
    'earliestStart', case when p_date = (now() at time zone 'Europe/Berlin')::date
                       then to_char(greatest(v_set.window_start, date_trunc('minute', (now() at time zone 'Europe/Berlin')::time)), 'HH24:MI')
                       else to_char(v_set.window_start, 'HH24:MI') end,
    'blocked', v_blocked is not null,
    'blockedReason', v_blocked,
    'busy', v_busy);
end $$;

-- Read model for the planner. Participant: own day. Staff: an assigned participant's day.
create function public.get_planning_day(p_date date, p_participant_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_pid uuid := coalesce(p_participant_id, auth.uid()); v_set public.planning_settings;
        v_today date := (now() at time zone 'Europe/Berlin')::date;
begin
  if not ((v_pid = auth.uid() and app.is_participant()) or app.is_assigned(v_pid)) then
    raise exception 'not_allowed' using errcode = '42501'; end if;
  select * into v_set from public.planning_settings limit 1;
  if p_date < v_today or p_date > v_today + v_set.max_days_ahead then
    raise exception 'date_out_of_range' using errcode = '22023'; end if;
  return app.planning_day(v_pid, p_date);
end $$;

-- The ONLY way a participant creates activities. All-or-nothing.
create function public.save_personal_free_time_plan(p_date date, p_activities jsonb)
returns setof public.personal_activities language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_set public.planning_settings; v_day jsonb; v_item jsonb; v_busy jsonb;
        v_today date := (now() at time zone 'Europe/Berlin')::date; v_s time; v_e time; v_title text;
        v_icon text; v_picto text; v_new jsonb := '[]'::jsonb; v_conflicts jsonb := '[]'::jsonb; i int := 0;
begin
  if v_uid is null or not app.is_participant() then raise exception 'not_allowed' using errcode = '42501'; end if;
  select * into v_set from public.planning_settings limit 1;
  if p_date < v_today or p_date > v_today + v_set.max_days_ahead then
    raise exception 'date_out_of_range' using errcode = '22023'; end if;
  if jsonb_typeof(p_activities) is distinct from 'array' or jsonb_array_length(p_activities) = 0
     or jsonb_array_length(p_activities) > v_set.max_items then
    raise exception 'invalid_activities' using errcode = '22023'; end if;

  perform app.lock_planning_day(v_uid, p_date);   -- serialise with other plans and staff saves
  v_day := app.planning_day(v_uid, p_date);       -- fresh state AFTER taking the lock
  if (v_day->>'blocked')::boolean then
    raise exception 'day_not_plannable' using errcode = '23514', detail = v_day->>'blockedReason'; end if;

  for v_item in select * from jsonb_array_elements(p_activities) loop
    v_title := btrim(coalesce(v_item->>'title', ''));
    begin
      v_s := nullif(v_item->>'startTime', '')::time;
      v_e := nullif(v_item->>'endTime', '')::time;
    exception when others then v_s := null; v_e := null;
    end;
    v_icon := nullif(v_item->>'iconKey', '');
    v_picto := nullif(v_item->>'pictogramUrl', '');
    if v_title = '' or length(v_title) > 80 then
      v_conflicts := v_conflicts || jsonb_build_object('index', i, 'reason', 'title');
    elsif v_s is null or v_e is null then
      v_conflicts := v_conflicts || jsonb_build_object('index', i, 'reason', 'time_required');
    elsif v_e <= v_s then
      v_conflicts := v_conflicts || jsonb_build_object('index', i, 'reason', 'end_before_start');
    elsif v_s < (v_day->>'earliestStart')::time or v_e > (v_day->>'windowEnd')::time then
      v_conflicts := v_conflicts || jsonb_build_object('index', i, 'reason', 'outside_window');
    elsif (v_icon is not null and v_icon !~ '^[a-z_]{1,40}$')
       or (v_picto is not null and v_picto !~ '^https://static\.arasaac\.org/pictograms/[0-9]{1,7}/[0-9]{1,7}_[0-9]{3}\.png$') then
      v_conflicts := v_conflicts || jsonb_build_object('index', i, 'reason', 'invalid_visual');
    else
      select b into v_busy from jsonb_array_elements(v_day->'busy' || v_new) b
        where v_s < (b->>'end')::time and (b->>'start')::time < v_e limit 1;
      if v_busy is not null then
        v_conflicts := v_conflicts || jsonb_build_object('index', i, 'reason', 'overlap',
          'kind', v_busy->>'kind', 'with', v_busy->>'title');
      else
        v_new := v_new || jsonb_build_object('start', to_char(v_s, 'HH24:MI'), 'end', to_char(v_e, 'HH24:MI'),
          'kind', 'draft', 'title', v_title);
      end if;
    end if;
    i := i + 1;
  end loop;

  if jsonb_array_length(v_conflicts) > 0 then
    raise exception 'plan_conflict' using errcode = '23514', detail = v_conflicts::text; end if;

  i := 0;
  for v_item in select * from jsonb_array_elements(p_activities) loop
    return query insert into public.personal_activities
        (participant_id, activity_date, title, start_time, end_time, icon_key, pictogram_url)
      values (v_uid, p_date, btrim(v_item->>'title'), (v_item->>'startTime')::time, (v_item->>'endTime')::time,
              nullif(v_item->>'iconKey', ''), nullif(v_item->>'pictogramUrl', ''))
      returning *;
    i := i + 1;
  end loop;
end $$;

create function public.complete_personal_activity(p_id uuid, p_done boolean default true)
returns public.personal_activities language plpgsql security definer set search_path = '' as $$
declare v_row public.personal_activities;
begin
  if not app.is_participant() then raise exception 'not_allowed' using errcode = '42501'; end if;
  update public.personal_activities
     set status = case when p_done then 'completed' else 'pending' end,
         completed_at = case when p_done then now() end
   where id = p_id and participant_id = auth.uid()
   returning * into v_row;
  if v_row.id is null then raise exception 'not_found' using errcode = 'PT404'; end if;
  return v_row;
end $$;

revoke execute on function app.lock_planning_day(uuid, date), app.planning_day(uuid, date) from public, anon, authenticated;
revoke execute on function public.get_planning_day(date, uuid), public.save_personal_free_time_plan(date, jsonb),
  public.complete_personal_activity(uuid, boolean) from public, anon;
grant execute on function public.get_planning_day(date, uuid), public.save_personal_free_time_plan(date, jsonb),
  public.complete_personal_activity(uuid, boolean) to authenticated;

-- ---------- save_schedule v5: same as v4 plus the shared planning lock ----------
create or replace function public.save_schedule(p_participant_id uuid, p_schedule_date date, p_activities jsonb,
                                                p_publish boolean default false, p_keep_untimed boolean default false)
returns public.schedules language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_sched public.schedules; v_item jsonb; v_step jsonb; v_act uuid;
        v_event text; v_kept uuid[] := '{}'; i int := 0; j int;
begin
  if not app.is_assigned(p_participant_id) then raise exception 'not_allowed' using errcode = '42501'; end if;
  perform app.lock_planning_day(p_participant_id, p_schedule_date);  -- serialises with participant planning
  if jsonb_typeof(p_activities) is distinct from 'array' or jsonb_array_length(p_activities) > 30 then
    raise exception 'invalid_activities' using errcode = '22023'; end if;
  insert into public.schedules (participant_id, schedule_date, created_by) values (p_participant_id, p_schedule_date, v_uid)
    on conflict (participant_id, schedule_date) do nothing;
  select * into v_sched from public.schedules where participant_id = p_participant_id and schedule_date = p_schedule_date for update;
  if v_sched.status = 'published' and not p_publish then
    raise exception 'schedule_not_draft' using errcode = '23514'; end if;

  for v_item in select * from jsonb_array_elements(p_activities) loop
    v_event := v_item->'meta'->>'eventId';
    v_act := null;
    if v_event is not null then
      select a.id into v_act from public.activities a
        where a.schedule_id = v_sched.id and a.id <> all(v_kept)
          and (a.meta->>'eventId' = v_event or (v_event like 'db-%' and a.id::text = substr(v_event, 4)))
        limit 1;
    end if;
    if v_act is null then
      insert into public.activities (schedule_id, title, description, start_time, end_time, sort_order, icon_key,
                                     category, pictogram_url, location, staff_name, meta, image_path)
      values (v_sched.id, v_item->>'title', v_item->>'description',
              nullif(v_item->>'startTime', '')::time, nullif(v_item->>'endTime', '')::time, i,
              coalesce(v_item->>'iconKey', v_item->>'pictogramKeyword'), v_item->>'category', nullif(v_item->>'pictogramUrl', ''),
              nullif(coalesce(v_item->>'location', v_item->>'locationName'), ''), nullif(v_item->>'staffName', ''),
              case when jsonb_typeof(v_item->'meta') = 'object' then v_item->'meta' end,
              nullif(v_item->>'imagePath', ''))
      returning id into v_act;
    else
      update public.activities set
        title = v_item->>'title', description = v_item->>'description',
        start_time = nullif(v_item->>'startTime', '')::time, end_time = nullif(v_item->>'endTime', '')::time,
        sort_order = i, icon_key = coalesce(v_item->>'iconKey', v_item->>'pictogramKeyword'),
        category = v_item->>'category', pictogram_url = nullif(v_item->>'pictogramUrl', ''),
        location = nullif(coalesce(v_item->>'location', v_item->>'locationName'), ''),
        staff_name = nullif(v_item->>'staffName', ''),
        meta = case when jsonb_typeof(v_item->'meta') = 'object' then v_item->'meta' end,
        image_path = case when v_item ? 'imagePath' then nullif(v_item->>'imagePath', '') else image_path end
      where id = v_act;
    end if;
    v_kept := v_kept || v_act;
    if v_item ? 'subSteps' then
      delete from public.activity_steps where activity_id = v_act;
      j := 0;
      for v_step in select * from jsonb_array_elements(coalesce(v_item->'subSteps', '[]'::jsonb)) loop
        insert into public.activity_steps (activity_id, title, sort_order, duration_min)
        values (v_act, v_step->>'title', j, nullif(v_step->>'durationMin', '')::int);
        j := j + 1;
      end loop;
    end if;
    i := i + 1;
  end loop;

  delete from public.activities
    where schedule_id = v_sched.id and id <> all(v_kept) and not (p_keep_untimed and start_time is null);

  if p_publish then
    if not exists (select 1 from public.activities where schedule_id = v_sched.id) then
      update public.schedules set status = 'draft', published_at = null where id = v_sched.id returning * into v_sched;
      return v_sched;
    end if;
    return public.publish_schedule(v_sched.id);
  end if;
  select * into v_sched from public.schedules where id = v_sched.id;
  return v_sched;
end $$;
