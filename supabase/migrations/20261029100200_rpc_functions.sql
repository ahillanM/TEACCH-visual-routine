-- Secure mutations. SECURITY DEFINER + empty search_path + caller checks inside; executable by authenticated only.
create function public.complete_activity(p_activity_id uuid, p_done boolean default true)
returns public.activities language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_act public.activities; v_target text := case when p_done then 'completed' else 'pending' end;
begin
  if v_uid is null or not app.is_participant() then raise exception 'not_allowed' using errcode = '42501'; end if;
  select a.* into v_act from public.activities a join public.schedules s on s.id = a.schedule_id
    where a.id = p_activity_id and s.participant_id = v_uid and s.status = 'published' for update of a;
  if not found then raise exception 'not_found' using errcode = 'P0002'; end if;
  if v_act.status = v_target then return v_act; end if;
  update public.activities set status = v_target, completed_at = case when p_done then now() end
    where id = p_activity_id returning * into v_act;
  insert into public.activity_events (activity_id, actor_id, event_type)
    values (p_activity_id, v_uid, case when p_done then 'completed' else 'uncompleted' end);
  return v_act;
end $$;

create function public.set_step_completed(p_step_id uuid, p_done boolean default true)
returns public.activity_steps language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_step public.activity_steps;
begin
  if v_uid is null or not app.is_participant() then raise exception 'not_allowed' using errcode = '42501'; end if;
  select st.* into v_step from public.activity_steps st
    join public.activities a on a.id = st.activity_id join public.schedules s on s.id = a.schedule_id
    where st.id = p_step_id and s.participant_id = v_uid and s.status = 'published' for update of st;
  if not found then raise exception 'not_found' using errcode = 'P0002'; end if;
  if v_step.is_completed = p_done then return v_step; end if;
  update public.activity_steps set is_completed = p_done, completed_at = case when p_done then now() end
    where id = p_step_id returning * into v_step;
  insert into public.activity_events (activity_id, actor_id, event_type, metadata)
    values (v_step.activity_id, v_uid, case when p_done then 'step_completed' else 'step_uncompleted' end,
            jsonb_build_object('step_id', p_step_id));
  return v_step;
end $$;

create function public.publish_schedule(p_schedule_id uuid)
returns public.schedules language plpgsql security definer set search_path = '' as $$
declare v_row public.schedules;
begin
  if not app.staff_manages_schedule(p_schedule_id) then raise exception 'not_allowed' using errcode = '42501'; end if;
  if not exists (select 1 from public.activities where schedule_id = p_schedule_id) then
    raise exception 'empty_schedule' using errcode = '23514'; end if;
  if exists (select 1 from public.activities a1 join public.activities a2
      on a1.schedule_id = a2.schedule_id and a1.id < a2.id
      where a1.schedule_id = p_schedule_id and a1.end_time is not null and a2.end_time is not null
        and a1.start_time < a2.end_time and a2.start_time < a1.end_time) then
    raise exception 'overlapping_activities' using errcode = '23514'; end if;
  update public.schedules set status = 'published', published_at = coalesce(published_at, now())
    where id = p_schedule_id returning * into v_row;
  return v_row;
end $$;

create function public.unpublish_schedule(p_schedule_id uuid)
returns public.schedules language plpgsql security definer set search_path = '' as $$
declare v_row public.schedules;
begin
  if not app.staff_manages_schedule(p_schedule_id) then raise exception 'not_allowed' using errcode = '42501'; end if;
  update public.schedules set status = 'draft', published_at = null where id = p_schedule_id returning * into v_row;
  return v_row;
end $$;

-- Atomically (re)writes a DRAFT schedule from JSON (shape of the AI proposal items). Optionally publishes.
create function public.save_schedule(p_participant_id uuid, p_schedule_date date, p_activities jsonb, p_publish boolean default false)
returns public.schedules language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_sched public.schedules; v_item jsonb; v_step jsonb; v_act uuid; i int := 0; j int;
begin
  if not app.is_assigned(p_participant_id) then raise exception 'not_allowed' using errcode = '42501'; end if;
  if jsonb_typeof(p_activities) is distinct from 'array' or jsonb_array_length(p_activities) > 30 then
    raise exception 'invalid_activities' using errcode = '22023'; end if;
  insert into public.schedules (participant_id, schedule_date, created_by) values (p_participant_id, p_schedule_date, v_uid)
    on conflict (participant_id, schedule_date) do nothing;
  select * into v_sched from public.schedules where participant_id = p_participant_id and schedule_date = p_schedule_date for update;
  if v_sched.status <> 'draft' then raise exception 'schedule_not_draft' using errcode = '23514'; end if;
  delete from public.activities where schedule_id = v_sched.id;
  for v_item in select * from jsonb_array_elements(p_activities) loop
    insert into public.activities (schedule_id, title, description, start_time, end_time, sort_order, icon_key,
                                   category, pictogram_url, location, staff_name)
    values (v_sched.id, v_item->>'title', v_item->>'description',
            nullif(v_item->>'startTime', '')::time, nullif(v_item->>'endTime', '')::time, i,
            coalesce(v_item->>'iconKey', v_item->>'pictogramKeyword'), v_item->>'category', v_item->>'pictogramUrl',
            nullif(coalesce(v_item->>'location', v_item->>'locationName'), ''), nullif(v_item->>'staffName', ''))
    returning id into v_act;
    j := 0;
    for v_step in select * from jsonb_array_elements(coalesce(v_item->'subSteps', '[]'::jsonb)) loop
      insert into public.activity_steps (activity_id, title, sort_order, duration_min)
      values (v_act, v_step->>'title', j, nullif(v_step->>'durationMin', '')::int);
      j := j + 1;
    end loop;
    i := i + 1;
  end loop;
  if p_publish then return public.publish_schedule(v_sched.id); end if;
  return v_sched;
end $$;

create function public.verify_attendance(p_activity_id uuid, p_status text)
returns public.attendance language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_row public.attendance;
begin
  if not app.staff_manages_activity(p_activity_id) then raise exception 'not_allowed' using errcode = '42501'; end if;
  insert into public.attendance (activity_id, verified_by, attendance_status) values (p_activity_id, v_uid, p_status)
    on conflict (activity_id) do update set attendance_status = excluded.attendance_status,
      verified_by = excluded.verified_by, verified_at = now()
    returning * into v_row;
  insert into public.activity_events (activity_id, actor_id, event_type, metadata)
    values (p_activity_id, v_uid, 'attendance_verified', jsonb_build_object('status', p_status));
  return v_row;
end $$;

create function public.resolve_support_request(p_request_id uuid)
returns public.support_requests language plpgsql security definer set search_path = '' as $$
declare v_row public.support_requests;
begin
  select * into v_row from public.support_requests where id = p_request_id;
  if not found or not app.is_assigned(v_row.participant_id) then raise exception 'not_allowed' using errcode = '42501'; end if;
  if v_row.status = 'resolved' then return v_row; end if;
  update public.support_requests set status = 'resolved', resolved_by = auth.uid(), resolved_at = now()
    where id = p_request_id returning * into v_row;
  return v_row;
end $$;

-- Per-day progress for one month, derived from activities/steps (RLS applies: SECURITY INVOKER).
create function public.monthly_progress(p_participant_id uuid, p_month date)
returns table (day date, activities_total int, activities_completed int, steps_total int, steps_completed int)
language sql stable security invoker set search_path = '' as $$
  select s.schedule_date, count(distinct a.id)::int, (count(distinct a.id) filter (where a.status = 'completed'))::int,
         count(st.id)::int, (count(st.id) filter (where st.is_completed))::int
  from public.schedules s join public.activities a on a.schedule_id = s.id
  left join public.activity_steps st on st.activity_id = a.id
  where s.participant_id = p_participant_id
    and s.schedule_date >= date_trunc('month', p_month)::date
    and s.schedule_date < (date_trunc('month', p_month) + interval '1 month')::date
  group by s.schedule_date order by s.schedule_date $$;

revoke execute on function public.complete_activity, public.set_step_completed, public.publish_schedule,
  public.unpublish_schedule, public.save_schedule, public.verify_attendance, public.resolve_support_request,
  public.monthly_progress from public, anon;
grant execute on function public.complete_activity, public.set_step_completed, public.publish_schedule,
  public.unpublish_schedule, public.save_schedule, public.verify_attendance, public.resolve_support_request,
  public.monthly_progress to authenticated;
