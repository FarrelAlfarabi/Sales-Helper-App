-- SQL test for 20261103120000. Run after the migration. Everything is rolled back:
-- success ends with the exception 'TESTS PASSED'; any other error text is a failure.
-- Needs one existing field_rep profile (rep) and one admin profile.
do $$
declare
  v_rep uuid := (select id from public.profiles where role = 'field_rep' and is_active limit 1);
  v_admin uuid := (select id from public.profiles where role = 'admin' and is_active limit 1);
  v_store uuid;
  v_att uuid;
  v_visit uuid;
  v_flag boolean;
  v_ok boolean;
begin
  insert into public.stores(code, name, latitude, longitude, geofence_radius_meters)
    values ('TEST-SEC-1', 'TEST store', -6.2, 106.8, 100) returning id into v_store;

  -- act as the rep
  perform set_config('request.jwt.claims', json_build_object('sub', v_rep, 'role', 'authenticated')::text, true);
  set local role authenticated;

  -- insert tries to backdate clock-in: must be forced to now()
  insert into public.attendance_records(employee_id, clock_in_at, clock_in_latitude, clock_in_longitude, clock_in_selfie_url)
    values (v_rep, now() - interval '5 hours', -6.2, 106.8, 'test') returning id into v_att;
  assert (select clock_in_at from public.attendance_records where id = v_att) > now() - interval '1 minute',
    'FAIL: backdated clock-in was kept';

  -- editing clock-in columns must fail
  begin
    update public.attendance_records set clock_in_at = now() - interval '9 hours' where id = v_att;
    raise exception 'FAIL: rep edited clock_in_at';
  exception when insufficient_privilege then null; end;
  begin
    update public.attendance_records set clock_in_latitude = 0 where id = v_att;
    raise exception 'FAIL: rep edited clock_in_latitude';
  exception when insufficient_privilege then null; end;

  -- normal clock-out works and is stamped now()
  update public.attendance_records set clock_out_at = now() - interval '3 hours', clock_out_latitude = -6.2 where id = v_att;
  assert (select clock_out_at from public.attendance_records where id = v_att) > now() - interval '1 minute',
    'FAIL: clock_out_at not forced to now()';

  -- second clock-out edit must fail
  begin
    update public.attendance_records set clock_out_latitude = 1 where id = v_att;
    raise exception 'FAIL: rep edited a closed record';
  exception when insufficient_privilege then null; end;

  -- visit far from the store: flag must be false and cannot be flipped
  insert into public.store_visits(employee_id, store_id, check_in_latitude, check_in_longitude, is_within_geofence)
    values (v_rep, v_store, -6.5, 107.0, true) returning id, is_within_geofence into v_visit, v_flag;
  assert v_flag = false, 'FAIL: insert kept a forged inside-zone flag';
  begin
    update public.store_visits set is_within_geofence = true where id = v_visit;
    raise exception 'FAIL: rep flipped is_within_geofence';
  exception when insufficient_privilege then null; end;
  begin
    update public.store_visits set check_in_latitude = -6.2, check_in_longitude = 106.8 where id = v_visit;
    raise exception 'FAIL: rep moved the check-in point';
  exception when insufficient_privilege then null; end;
  update public.store_visits set notes = 'ok', visit_ended_at = now() where id = v_visit;

  -- rep cannot reactivate themselves
  reset role;
  perform set_config('request.jwt.claims', '', true);
  update public.profiles set is_active = false where id = v_rep;
  perform set_config('request.jwt.claims', json_build_object('sub', v_rep, 'role', 'authenticated')::text, true);
  set local role authenticated;
  begin
    update public.profiles set is_active = true where id = v_rep;
    raise exception 'FAIL: deactivated rep reactivated self';
  exception when others then
    if sqlerrm like 'FAIL%' then raise; end if;
  end;
  -- deactivated rep cannot clock in
  begin
    insert into public.attendance_records(employee_id, clock_in_latitude, clock_in_longitude, clock_in_selfie_url) values (v_rep, 0, 0, 'test');
    raise exception 'FAIL: deactivated rep clocked in';
  exception when insufficient_privilege then null; end;

  -- anonymous cannot run helpers
  reset role;
  set local role anon;
  begin
    perform public.is_manager_or_admin();
    raise exception 'FAIL: anon can execute is_manager_or_admin';
  exception when insufficient_privilege then null; end;

  reset role;
  raise exception 'TESTS PASSED';
end $$;
