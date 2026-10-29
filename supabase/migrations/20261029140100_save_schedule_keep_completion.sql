-- Re-saving a schedule replaces its activities. Keep participant completion for activities whose
-- UI event id (meta.eventId) survives the edit, so a staff change does not wipe progress.
create or replace function public.save_schedule(p_participant_id uuid, p_schedule_date date, p_activities jsonb, p_publish boolean default false)
returns public.schedules language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_sched public.schedules; v_item jsonb; v_step jsonb; v_act uuid; i int := 0; j int;
        v_done jsonb; v_done_at timestamptz;
begin
  if not app.is_assigned(p_participant_id) then raise exception 'not_allowed' using errcode = '42501'; end if;
  if jsonb_typeof(p_activities) is distinct from 'array' or jsonb_array_length(p_activities) > 30 then
    raise exception 'invalid_activities' using errcode = '22023'; end if;
  insert into public.schedules (participant_id, schedule_date, created_by) values (p_participant_id, p_schedule_date, v_uid)
    on conflict (participant_id, schedule_date) do nothing;
  select * into v_sched from public.schedules where participant_id = p_participant_id and schedule_date = p_schedule_date for update;
  if v_sched.status <> 'draft' then raise exception 'schedule_not_draft' using errcode = '23514'; end if;
  select coalesce(jsonb_object_agg(meta->>'eventId', completed_at), '{}'::jsonb) into v_done
    from public.activities where schedule_id = v_sched.id and status = 'completed' and meta ? 'eventId';
  delete from public.activities where schedule_id = v_sched.id;
  for v_item in select * from jsonb_array_elements(p_activities) loop
    v_done_at := (v_done->>(v_item->'meta'->>'eventId'))::timestamptz;
    insert into public.activities (schedule_id, title, description, start_time, end_time, sort_order, icon_key,
                                   category, pictogram_url, location, staff_name, meta, status, completed_at)
    values (v_sched.id, v_item->>'title', v_item->>'description',
            nullif(v_item->>'startTime', '')::time, nullif(v_item->>'endTime', '')::time, i,
            coalesce(v_item->>'iconKey', v_item->>'pictogramKeyword'), v_item->>'category', nullif(v_item->>'pictogramUrl', ''),
            nullif(coalesce(v_item->>'location', v_item->>'locationName'), ''), nullif(v_item->>'staffName', ''),
            case when jsonb_typeof(v_item->'meta') = 'object' then v_item->'meta' end,
            case when v_done_at is null then 'pending' else 'completed' end, v_done_at)
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
