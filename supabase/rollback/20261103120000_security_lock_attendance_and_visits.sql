-- Rollback for 20261103120000_security_lock_attendance_and_visits.sql
drop trigger if exists attendance_records_integrity on public.attendance_records;
drop trigger if exists store_visits_integrity on public.store_visits;
do $$
declare t text;
begin
  foreach t in array array['leave_requests','price_reports','sales_reports','shelf_checks','product_placements','ai_insights','ai_usage']
  loop
    execute format('drop trigger if exists %I on public.%I', t || '_require_active', t);
  end loop;
end $$;
drop function if exists public.enforce_attendance_integrity();
drop function if exists public.enforce_store_visit_integrity();
drop function if exists public.require_active_employee();
drop function if exists public.is_active_employee();
-- restore the original role-only guard
create or replace function public.prevent_self_role_escalation()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.role <> old.role and auth.uid() is not null and not public.is_manager_or_admin() then
    raise exception 'Only a manager or admin can change a profile''s role.';
  end if;
  return new;
end;
$$;
-- restore previous grants (everyone could execute) and search_path
grant execute on function public.handle_new_user() to public, anon, authenticated;
grant execute on function public.prevent_self_role_escalation() to public, anon, authenticated;
grant execute on function public.compute_store_visit_geofence() to public, anon, authenticated;
grant execute on function public.set_updated_at() to public, anon, authenticated;
grant execute on function public.is_manager_or_admin() to public, anon, authenticated;
alter function public.set_updated_at() reset search_path;
alter function public.distance_meters(double precision, double precision, double precision, double precision) reset search_path;
alter function public.compute_store_visit_geofence() reset search_path;
