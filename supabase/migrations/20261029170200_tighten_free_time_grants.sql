-- Supabase's default privileges give anon/authenticated ALL (incl. TRUNCATE) on new tables.
-- RLS already blocked every unintended write, but grants must match the design:
-- participants write personal plans ONLY through save_personal_free_time_plan.
revoke all on public.personal_activities, public.unavailable_periods, public.planning_settings
  from anon, authenticated;

grant select, delete on public.personal_activities to authenticated;          -- delete: RLS = assigned staff
grant select, delete on public.unavailable_periods to authenticated;           -- delete: RLS = assigned staff
grant insert (participant_id, period_date, start_time, end_time, reason)
  on public.unavailable_periods to authenticated;                              -- insert: RLS = assigned staff
grant select on public.planning_settings to authenticated;
