-- RLS on every table + minimal column-level grants. Sensitive columns (status, completion, audit) have NO client write path.
alter table public.profiles enable row level security;
alter table public.staff_participants enable row level security;
alter table public.schedules enable row level security;
alter table public.activities enable row level security;
alter table public.activity_steps enable row level security;
alter table public.activity_events enable row level security;
alter table public.attendance enable row level security;
alter table public.support_requests enable row level security;
alter table public.schedule_changes enable row level security;

revoke all on all tables in schema public from anon, authenticated;
grant select on all tables in schema public to authenticated;
grant insert (participant_id, schedule_date, created_by) on public.schedules to authenticated;
grant update (schedule_date) on public.schedules to authenticated;
grant delete on public.schedules to authenticated;
grant insert (schedule_id, title, description, start_time, end_time, sort_order, icon_key, category, pictogram_url, location, staff_name)
  on public.activities to authenticated;
grant update (title, description, start_time, end_time, sort_order, icon_key, category, pictogram_url, location, staff_name)
  on public.activities to authenticated;
grant delete on public.activities to authenticated;
grant insert (activity_id, title, sort_order, duration_min) on public.activity_steps to authenticated;
grant update (title, sort_order, duration_min) on public.activity_steps to authenticated;
grant delete on public.activity_steps to authenticated;
grant insert (activity_id, request_type, note) on public.support_requests to authenticated;

create policy profiles_select on public.profiles for select to authenticated
  using (id = (select auth.uid()) or app.is_assigned(id));
create policy sp_select on public.staff_participants for select to authenticated
  using (staff_id = (select auth.uid()) or participant_id = (select auth.uid()));

create policy schedules_select on public.schedules for select to authenticated using (app.can_read_schedule(id));
create policy schedules_insert on public.schedules for insert to authenticated
  with check (app.is_assigned(participant_id) and created_by = (select auth.uid()));
create policy schedules_update on public.schedules for update to authenticated
  using (app.is_assigned(participant_id) and status = 'draft') with check (app.is_assigned(participant_id));
create policy schedules_delete on public.schedules for delete to authenticated
  using (app.is_assigned(participant_id) and status = 'draft');

create policy activities_select on public.activities for select to authenticated using (app.can_read_schedule(schedule_id));
create policy activities_insert on public.activities for insert to authenticated with check (app.staff_manages_schedule(schedule_id));
create policy activities_update on public.activities for update to authenticated
  using (app.staff_manages_schedule(schedule_id)) with check (app.staff_manages_schedule(schedule_id));
create policy activities_delete on public.activities for delete to authenticated using (app.staff_manages_schedule(schedule_id));

create policy steps_select on public.activity_steps for select to authenticated using (app.can_read_activity(activity_id));
create policy steps_insert on public.activity_steps for insert to authenticated with check (app.staff_manages_activity(activity_id));
create policy steps_update on public.activity_steps for update to authenticated
  using (app.staff_manages_activity(activity_id)) with check (app.staff_manages_activity(activity_id));
create policy steps_delete on public.activity_steps for delete to authenticated using (app.staff_manages_activity(activity_id));

create policy events_select on public.activity_events for select to authenticated using (app.can_read_activity(activity_id));
create policy attendance_select on public.attendance for select to authenticated using (app.can_read_activity(activity_id));

create policy requests_select on public.support_requests for select to authenticated
  using (participant_id = (select auth.uid()) or app.is_assigned(participant_id));
create policy requests_insert on public.support_requests for insert to authenticated
  with check (participant_id = (select auth.uid()) and app.is_participant()
              and (activity_id is null or app.can_read_activity(activity_id)));

create policy changes_select on public.schedule_changes for select to authenticated using (app.staff_manages_schedule(schedule_id));

-- Realtime: RLS still applies to change events.
alter publication supabase_realtime add table public.schedules, public.activities, public.activity_steps, public.support_requests;
