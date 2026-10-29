-- save_schedule v3: update a day IN PLACE instead of delete + re-insert.
--
-- Problems fixed (found in the data audit 2026-10-29):
-- * Re-saving deleted every activity, which cascade-deleted sub-steps, attendance and
--   completion history, plus activities the planner UI cannot show (no start time).
-- * Republishing needed unpublish + save: not atomic, and the activity edits were made
--   while the day was a draft, so schedule_changes never recorded them.
--
-- Now: items are matched to existing activities by meta.eventId (or "db-<activity id>" for
-- rows created outside the planner). Matched rows are UPDATEd, so status, sub-steps,
-- attendance and events survive; new items are inserted; unmatched rows are deleted, except
-- untimed ones when p_keep_untimed. Sub-steps are replaced only when an item carries a
-- "subSteps" key. A published day can be saved with p_publish = true in one transaction,
-- and the audit trigger logs each changed activity. Overlaps abort the whole call.
drop function public.save_schedule(uuid, date, jsonb, boolean);

create function public.save_schedule(p_participant_id uuid, p_schedule_date date, p_activities jsonb,
                                     p_publish boolean default false, p_keep_untimed boolean default false)
returns public.schedules language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_sched public.schedules; v_item jsonb; v_step jsonb; v_act uuid;
        v_event text; v_kept uuid[] := '{}'; i int := 0; j int;
begin
  if not app.is_assigned(p_participant_id) then raise exception 'not_allowed' using errcode = '42501'; end if;
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
                                     category, pictogram_url, location, staff_name, meta)
      values (v_sched.id, v_item->>'title', v_item->>'description',
              nullif(v_item->>'startTime', '')::time, nullif(v_item->>'endTime', '')::time, i,
              coalesce(v_item->>'iconKey', v_item->>'pictogramKeyword'), v_item->>'category', nullif(v_item->>'pictogramUrl', ''),
              nullif(coalesce(v_item->>'location', v_item->>'locationName'), ''), nullif(v_item->>'staffName', ''),
              case when jsonb_typeof(v_item->'meta') = 'object' then v_item->'meta' end)
      returning id into v_act;
    else
      update public.activities set
        title = v_item->>'title', description = v_item->>'description',
        start_time = nullif(v_item->>'startTime', '')::time, end_time = nullif(v_item->>'endTime', '')::time,
        sort_order = i, icon_key = coalesce(v_item->>'iconKey', v_item->>'pictogramKeyword'),
        category = v_item->>'category', pictogram_url = nullif(v_item->>'pictogramUrl', ''),
        location = nullif(coalesce(v_item->>'location', v_item->>'locationName'), ''),
        staff_name = nullif(v_item->>'staffName', ''),
        meta = case when jsonb_typeof(v_item->'meta') = 'object' then v_item->'meta' end
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
      -- Nothing left: hide the day from the participant instead of publishing an empty one.
      update public.schedules set status = 'draft', published_at = null where id = v_sched.id returning * into v_sched;
      return v_sched;
    end if;
    return public.publish_schedule(v_sched.id);  -- raises on overlaps -> whole call rolls back
  end if;
  select * into v_sched from public.schedules where id = v_sched.id;
  return v_sched;
end $$;

revoke all on function public.save_schedule(uuid, date, jsonb, boolean, boolean) from public, anon;
grant execute on function public.save_schedule(uuid, date, jsonb, boolean, boolean) to authenticated;
