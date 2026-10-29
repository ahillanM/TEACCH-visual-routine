-- Fictional demo data. Idempotent. Run in the SQL editor (or execute_sql) AFTER the migrations.
-- First set the shared demo password for this session:
--   select set_config('app.demo_password', 'choose-a-password', false);
-- Never use real people or real data here.
do $$
declare
  pw text := current_setting('app.demo_password', true);
  u record; v_sched uuid; v_act uuid; d int; k int;
  lukas uuid := 'b0000000-0000-0000-0000-000000000001'; mia uuid := 'b0000000-0000-0000-0000-000000000002';
  jonas uuid := 'b0000000-0000-0000-0000-000000000003'; anna uuid := 'a0000000-0000-0000-0000-000000000001';
  ben uuid := 'a0000000-0000-0000-0000-000000000002';
begin
  if pw is null or length(pw) < 8 then raise exception 'set app.demo_password first (min 8 chars)'; end if;

  for u in select * from (values
    (anna,  'anna.weber.demo@example.com',   'Anna Weber (demo staff)',   'staff'),
    (ben,   'ben.schmidt.demo@example.com',  'Ben Schmidt (demo staff)',  'staff'),
    (lukas, 'lukas.demo@example.com',        'Lukas (demo participant)',  'participant'),
    (mia,   'mia.demo@example.com',          'Mia (demo participant)',    'participant'),
    (jonas, 'jonas.demo@example.com',        'Jonas (demo participant)',  'participant')) as t(id, email, name, role)
  loop
    insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
        raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
        confirmation_token, recovery_token, email_change, email_change_token_new)
    values ('00000000-0000-0000-0000-000000000000', u.id, 'authenticated', 'authenticated', u.email,
        extensions.crypt(pw, extensions.gen_salt('bf')), now(),
        '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', '')
    on conflict (id) do update set encrypted_password = excluded.encrypted_password;
    insert into auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
    values (gen_random_uuid(), u.id, jsonb_build_object('sub', u.id::text, 'email', u.email), 'email', u.id::text, now(), now(), now())
    on conflict do nothing;
    insert into public.profiles (id, display_name, role) values (u.id, u.name, u.role) on conflict (id) do nothing;
  end loop;

  -- Anna: Lukas + Mia. Ben: Mia + Jonas. (Anna has no access to Jonas; Ben none to Lukas.)
  insert into public.staff_participants (staff_id, participant_id) values
    (anna, lukas), (anna, mia), (ben, mia), (ben, jonas) on conflict do nothing;

  if exists (select 1 from public.schedules where participant_id in (lukas, mia, jonas)) then return; end if;

  -- Lukas today (published): some times intentionally missing
  insert into public.schedules (participant_id, schedule_date, status, created_by, published_at)
    values (lukas, current_date, 'published', anna, now()) returning id into v_sched;
  insert into public.activities (schedule_id, title, start_time, end_time, sort_order, icon_key, category, location) values
    (v_sched, 'Morning routine', '07:00', null, 0, 'bed', 'PERSONAL', null),
    (v_sched, 'Breakfast', '08:00', '08:30', 1, 'breakfast', 'BREAK', 'Dining hall'),
    (v_sched, 'Metal Workshop: Milling', '09:00', '11:00', 2, 'workshop', 'BBW_TRAINING', 'Workshop Hall B'),
    (v_sched, 'Lunch', null, null, 3, 'lunch', 'BREAK', 'Dining hall'),
    (v_sched, 'Study time', '17:00', '18:00', 4, 'book', 'RESIDENTIAL', 'Group St. Josef');
  insert into public.activity_steps (activity_id, title, sort_order, duration_min)
    select a.id, s.t, s.o, s.m from public.activities a join (values
      ('Morning routine','Get out of bed',0,null::int), ('Morning routine','Wash face',1,null), ('Morning routine','Brush teeth',2,null),
      ('Metal Workshop: Milling','Put on safety glasses',0,2), ('Metal Workshop: Milling','Clamp workpiece securely',1,15),
      ('Metal Workshop: Milling','Sweep workstation',2,10)) s(a,t,o,m) on a.title = s.a and a.schedule_id = v_sched;
  insert into public.support_requests (participant_id, activity_id, request_type, note)
    select lukas, id, 'more_time', 'I need a little more time with the clamp.' from public.activities
    where schedule_id = v_sched and title like 'Metal Workshop%';

  -- Lukas tomorrow (draft, invisible to him)
  insert into public.schedules (participant_id, schedule_date, status, created_by) values (lukas, current_date + 1, 'draft', anna) returning id into v_sched;
  insert into public.activities (schedule_id, title, start_time, sort_order, category) values
    (v_sched, 'Dentist appointment', '10:00', 0, 'PERSONAL'), (v_sched, 'Free time', null, 1, 'PERSONAL');

  -- Lukas history: previous 4 days, 3 activities each, mostly completed
  for d in 1..4 loop
    insert into public.schedules (participant_id, schedule_date, status, created_by, published_at)
      values (lukas, current_date - d, 'published', anna, now() - make_interval(days => d)) returning id into v_sched;
    insert into public.activities (schedule_id, title, start_time, end_time, sort_order, category) values
      (v_sched, 'Breakfast', '08:00', '08:30', 0, 'BREAK'), (v_sched, 'Training', '09:00', '12:00', 1, 'BBW_TRAINING'),
      (v_sched, 'Dinner', '18:00', '19:00', 2, 'RESIDENTIAL');
    k := 0;
    for v_act in select id from public.activities where schedule_id = v_sched order by sort_order loop
      if not (d = 3 and k = 2) then  -- one missed activity for realistic progress
        update public.activities set status = 'completed', completed_at = (current_date - d) + time '12:00' where id = v_act;
        insert into public.activity_events (activity_id, actor_id, event_type, created_at)
          values (v_act, lukas, 'completed', (current_date - d) + time '12:00');
        insert into public.attendance (activity_id, verified_by, attendance_status) values (v_act, anna, 'present');
      end if;
      k := k + 1;
    end loop;
  end loop;

  -- Mia and Jonas today (published)
  insert into public.schedules (participant_id, schedule_date, status, created_by, published_at)
    values (mia, current_date, 'published', anna, now()) returning id into v_sched;
  insert into public.activities (schedule_id, title, start_time, end_time, sort_order, category) values
    (v_sched, 'Garden work', '09:00', '11:30', 0, 'BBW_TRAINING'), (v_sched, 'Lunch', '12:00', '13:00', 1, 'BREAK'),
    (v_sched, 'Art group', null, null, 2, 'PERSONAL');
  insert into public.schedules (participant_id, schedule_date, status, created_by, published_at)
    values (jonas, current_date, 'published', ben, now()) returning id into v_sched;
  insert into public.activities (schedule_id, title, start_time, end_time, sort_order, category) values
    (v_sched, 'Kitchen training', '08:30', '11:00', 0, 'BBW_TRAINING'), (v_sched, 'Lunch', '12:00', '13:00', 1, 'BREAK'),
    (v_sched, 'Evening routine', '19:30', null, 2, 'RESIDENTIAL');
end $$;
