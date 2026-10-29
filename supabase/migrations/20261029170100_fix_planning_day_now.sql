-- Fix: date_trunc() on a time value yields an interval; truncate the timestamp first.
create or replace function app.planning_day(p_participant uuid, p_date date) returns jsonb
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
                       then to_char(greatest(v_set.window_start, date_trunc('minute', now() at time zone 'Europe/Berlin')::time), 'HH24:MI')
                       else to_char(v_set.window_start, 'HH24:MI') end,
    'blocked', v_blocked is not null,
    'blockedReason', v_blocked,
    'busy', v_busy);
end $$;
