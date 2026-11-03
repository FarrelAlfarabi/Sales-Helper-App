-- Security stage 1: stop field reps from rewriting their own attendance and visit
-- records through the API, block deactivated staff, and tighten function access.
-- Idempotent: safe to run twice. Rollback: supabase/rollback/20261103120000_*.sql
-- Test: supabase/tests/20261103120000_*.sql

-- 1. Helper: is the caller a signed-in, active employee?
create or replace function public.is_active_employee()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select is_active from public.profiles where id = auth.uid()), false);
$$;

-- 2. Attendance: reps may only close their own open record, and only with "now".
create or replace function public.enforce_attendance_integrity()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  -- auth.uid() is null for the service role and the SQL editor: allow (admin corrections).
  if auth.uid() is null then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if not public.is_active_employee() then
      raise exception 'Akun tidak aktif.' using errcode = '42501';
    end if;
    new.clock_in_at := now();
    new.clock_out_at := null;
    new.clock_out_latitude := null;
    new.clock_out_longitude := null;
    new.clock_out_accuracy_meters := null;
    new.clock_out_selfie_url := null;
    return new;
  end if;

  -- UPDATE
  if not public.is_active_employee() then
    raise exception 'Akun tidak aktif.' using errcode = '42501';
  end if;
  if new.id is distinct from old.id
     or new.employee_id is distinct from old.employee_id
     or new.clock_in_at is distinct from old.clock_in_at
     or new.clock_in_latitude is distinct from old.clock_in_latitude
     or new.clock_in_longitude is distinct from old.clock_in_longitude
     or new.clock_in_accuracy_meters is distinct from old.clock_in_accuracy_meters
     or new.clock_in_selfie_url is distinct from old.clock_in_selfie_url
     or new.created_at is distinct from old.created_at then
    raise exception 'Data absen masuk tidak bisa diubah.' using errcode = '42501';
  end if;
  if old.clock_out_at is not null then
    if new.clock_out_at is distinct from old.clock_out_at
       or new.clock_out_latitude is distinct from old.clock_out_latitude
       or new.clock_out_longitude is distinct from old.clock_out_longitude
       or new.clock_out_accuracy_meters is distinct from old.clock_out_accuracy_meters
       or new.clock_out_selfie_url is distinct from old.clock_out_selfie_url then
      raise exception 'Absen pulang sudah tercatat dan tidak bisa diubah.' using errcode = '42501';
    end if;
  else
    new.clock_out_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists attendance_records_integrity on public.attendance_records;
create trigger attendance_records_integrity
  before insert or update on public.attendance_records
  for each row execute function public.enforce_attendance_integrity();

-- 3. Store visits: location, time, store and the inside-zone flag are fixed once saved.
create or replace function public.enforce_store_visit_integrity()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if auth.uid() is null then
    return new;
  end if;

  if not public.is_active_employee() then
    raise exception 'Akun tidak aktif.' using errcode = '42501';
  end if;

  if tg_op = 'INSERT' then
    new.visit_started_at := now();
    new.visit_ended_at := null;
    return new;
  end if;

  if new.id is distinct from old.id
     or new.employee_id is distinct from old.employee_id
     or new.store_id is distinct from old.store_id
     or new.visit_started_at is distinct from old.visit_started_at
     or new.check_in_latitude is distinct from old.check_in_latitude
     or new.check_in_longitude is distinct from old.check_in_longitude
     or new.check_in_accuracy_meters is distinct from old.check_in_accuracy_meters
     or new.store_photo_url is distinct from old.store_photo_url
     or new.distance_from_store_meters is distinct from old.distance_from_store_meters
     or new.is_within_geofence is distinct from old.is_within_geofence
     or new.created_at is distinct from old.created_at then
    raise exception 'Data kunjungan tidak bisa diubah.' using errcode = '42501';
  end if;
  return new;
end;
$$;

-- Name sorts after store_visits_geofence_check so the geofence flag is computed first on insert.
drop trigger if exists store_visits_integrity on public.store_visits;
create trigger store_visits_integrity
  before insert or update on public.store_visits
  for each row execute function public.enforce_store_visit_integrity();

-- 4. Profiles: nobody edits their own active flag or employee code (role is already guarded).
create or replace function public.prevent_self_role_escalation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null and not public.is_manager_or_admin() then
    if new.role <> old.role then
      raise exception 'Only a manager or admin can change a profile''s role.';
    end if;
    if new.is_active is distinct from old.is_active
       or new.employee_code is distinct from old.employee_code then
      raise exception 'Hanya manajer atau admin yang bisa mengubah status akun.';
    end if;
  end if;
  return new;
end;
$$;

-- 5. Other tables: block inserts from deactivated accounts.
create or replace function public.require_active_employee()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if auth.uid() is not null and not public.is_active_employee() then
    raise exception 'Akun tidak aktif.' using errcode = '42501';
  end if;
  return new;
end;
$$;

do $$
declare t text;
begin
  foreach t in array array['leave_requests','price_reports','sales_reports','shelf_checks','product_placements','ai_insights','ai_usage']
  loop
    execute format('drop trigger if exists %I on public.%I', t || '_require_active', t);
    execute format('create trigger %I before insert on public.%I for each row execute function public.require_active_employee()', t || '_require_active', t);
  end loop;
end $$;

-- 6. Function hygiene: fixed search_path, no anonymous execute, trigger-only functions not callable.
alter function public.set_updated_at() set search_path = public;
alter function public.distance_meters(double precision, double precision, double precision, double precision) set search_path = public;
alter function public.compute_store_visit_geofence() set search_path = public;

revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.prevent_self_role_escalation() from public, anon, authenticated;
revoke execute on function public.enforce_attendance_integrity() from public, anon, authenticated;
revoke execute on function public.enforce_store_visit_integrity() from public, anon, authenticated;
revoke execute on function public.require_active_employee() from public, anon, authenticated;
revoke execute on function public.compute_store_visit_geofence() from public, anon, authenticated;
revoke execute on function public.set_updated_at() from public, anon, authenticated;
revoke execute on function public.is_manager_or_admin() from public, anon;
revoke execute on function public.is_active_employee() from public, anon;
grant execute on function public.is_manager_or_admin() to authenticated;
grant execute on function public.is_active_employee() to authenticated;
