-- Custom task photos: private Storage bucket + activities.image_path (object path only).
--
-- Path format (no names, unguessable): participants/{participant_id}/{random_uuid}.{jpg|png|webp}
-- * Assigned staff upload / read / delete; the participant reads only their own folder.
-- * No UPDATE policy: objects can never be overwritten (replace = upload new + repoint + delete old).
-- * An object still referenced by any activity cannot be deleted.
-- * image_path must point to an existing object in the schedule participant's folder.
-- icon_key / pictogram_url are unchanged and stay the fallback.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('task-images', 'task-images', false, 2097152, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Participant id encoded in a task-image path, or null if the path is not well-formed.
create function app.task_image_participant(p_name text) returns uuid
language sql immutable set search_path = '' as $$
  select case when p_name ~ '^participants/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|png|webp)$'
    then split_part(p_name, '/', 2)::uuid end $$;

-- ---------- activities.image_path ----------
alter table public.activities
  add column image_path text check (image_path is null or app.task_image_participant(image_path) is not null);

-- True while any activity (draft or published, any staff) still uses the image.
create function app.task_image_in_use(p_name text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.activities where image_path = p_name) $$;

revoke execute on function app.task_image_participant(text), app.task_image_in_use(text) from public, anon;
grant execute on function app.task_image_participant(text), app.task_image_in_use(text) to authenticated;

create function app.check_activity_image() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.image_path is null then return new; end if;
  if app.task_image_participant(new.image_path) is distinct from
     (select s.participant_id from public.schedules s where s.id = new.schedule_id) then
    raise exception 'image_wrong_participant' using errcode = '23514';
  end if;
  if not exists (select 1 from storage.objects o where o.bucket_id = 'task-images' and o.name = new.image_path) then
    raise exception 'image_not_found' using errcode = '23514';
  end if;
  return new;
end $$;
create trigger trg_activities_image before insert or update of image_path on public.activities
  for each row execute function app.check_activity_image();

-- Staff may also set/clear the photo with a direct activity update (RLS: assigned staff only).
grant insert (image_path), update (image_path) on public.activities to authenticated;

-- ---------- Storage RLS (bucket task-images) ----------
create policy task_images_read on storage.objects for select to authenticated using (
  bucket_id = 'task-images' and (
    app.is_assigned(app.task_image_participant(name))
    or (app.task_image_participant(name) = (select auth.uid()) and app.is_participant())));

create policy task_images_upload on storage.objects for insert to authenticated with check (
  bucket_id = 'task-images' and app.is_assigned(app.task_image_participant(name)));

create policy task_images_delete on storage.objects for delete to authenticated using (
  bucket_id = 'task-images' and app.is_assigned(app.task_image_participant(name))
  and not app.task_image_in_use(name));

-- ---------- save_schedule v4: imagePath ----------
-- Same as v3, plus "imagePath" per item. Like "subSteps", an item WITHOUT the key keeps the
-- current photo (planner sync and AI drafts never drop it); "imagePath": null removes it.
create or replace function public.save_schedule(p_participant_id uuid, p_schedule_date date, p_activities jsonb,
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
