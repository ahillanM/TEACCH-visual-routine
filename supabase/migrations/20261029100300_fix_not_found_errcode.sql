-- PostgREST maps PT404 to HTTP 404 (P0002 became a 500).
create or replace function public.complete_activity(p_activity_id uuid, p_done boolean default true)
returns public.activities language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_act public.activities; v_target text := case when p_done then 'completed' else 'pending' end;
begin
  if v_uid is null or not app.is_participant() then raise exception 'not_allowed' using errcode = '42501'; end if;
  select a.* into v_act from public.activities a join public.schedules s on s.id = a.schedule_id
    where a.id = p_activity_id and s.participant_id = v_uid and s.status = 'published' for update of a;
  if not found then raise exception 'not_found' using errcode = 'PT404'; end if;
  if v_act.status = v_target then return v_act; end if;
  update public.activities set status = v_target, completed_at = case when p_done then now() end
    where id = p_activity_id returning * into v_act;
  insert into public.activity_events (activity_id, actor_id, event_type)
    values (p_activity_id, v_uid, case when p_done then 'completed' else 'uncompleted' end);
  return v_act;
end $$;
create or replace function public.set_step_completed(p_step_id uuid, p_done boolean default true)
returns public.activity_steps language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_step public.activity_steps;
begin
  if v_uid is null or not app.is_participant() then raise exception 'not_allowed' using errcode = '42501'; end if;
  select st.* into v_step from public.activity_steps st
    join public.activities a on a.id = st.activity_id join public.schedules s on s.id = a.schedule_id
    where st.id = p_step_id and s.participant_id = v_uid and s.status = 'published' for update of st;
  if not found then raise exception 'not_found' using errcode = 'PT404'; end if;
  if v_step.is_completed = p_done then return v_step; end if;
  update public.activity_steps set is_completed = p_done, completed_at = case when p_done then now() end
    where id = p_step_id returning * into v_step;
  insert into public.activity_events (activity_id, actor_id, event_type, metadata)
    values (v_step.activity_id, v_uid, case when p_done then 'step_completed' else 'step_uncompleted' end,
            jsonb_build_object('step_id', p_step_id));
  return v_step;
end $$;
