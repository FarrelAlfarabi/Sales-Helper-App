-- Moves the demo accounts' activity forward so the newest day is "today".
-- Run it on the morning of a demo (SQL editor, or ask Claude to run it).
--
-- Touches ONLY rows that belong to demo.*@zonein.app accounts. It deletes
-- nothing and can be run again any day: it shifts by the number of days
-- between the newest demo visit and today (Asia/Jakarta), so a second run on
-- the same day does nothing.
--
-- It does not create photos. Demo rows that have no photo file keep showing
-- "Foto tidak tersedia".
do $$
declare
  v_ids uuid[] := array(
    select id from auth.users where email like 'demo.%@zonein.app');
  v_today date := (now() at time zone 'Asia/Jakarta')::date;
  v_last date;
  v_days int;
  v_shift interval;
begin
  if coalesce(array_length(v_ids, 1), 0) = 0 then
    raise notice 'No demo accounts found. Nothing changed.';
    return;
  end if;

  select max((visit_started_at at time zone 'Asia/Jakarta')::date) into v_last
    from public.store_visits where employee_id = any(v_ids);
  if v_last is null then
    raise notice 'Demo accounts have no visits. Nothing changed.';
    return;
  end if;

  v_days := v_today - v_last;
  if v_days <= 0 then
    raise notice 'Demo data is already current (newest day %). Nothing changed.', v_last;
    return;
  end if;
  v_shift := make_interval(days => v_days);

  update public.attendance_records
     set clock_in_at = clock_in_at + v_shift,
         clock_out_at = clock_out_at + v_shift,
         created_at = created_at + v_shift
   where employee_id = any(v_ids);

  -- Records left open on earlier days look broken in the report: close them
  -- after 8 hours. Open records on the newest day stay open ("still at work").
  update public.attendance_records
     set clock_out_at = clock_in_at + interval '8 hours',
         clock_out_latitude = clock_in_latitude,
         clock_out_longitude = clock_in_longitude
   where employee_id = any(v_ids)
     and clock_out_at is null
     and (clock_in_at at time zone 'Asia/Jakarta')::date < v_today;

  update public.product_placements p
     set created_at = p.created_at + v_shift
    from public.store_visits v
   where v.id = p.store_visit_id and v.employee_id = any(v_ids);

  update public.store_visits
     set visit_started_at = visit_started_at + v_shift,
         visit_ended_at = visit_ended_at + v_shift,
         created_at = created_at + v_shift
   where employee_id = any(v_ids);

  update public.sales_reports
     set sale_date = sale_date + v_days, created_at = created_at + v_shift
   where employee_id = any(v_ids);

  update public.price_reports
     set created_at = created_at + v_shift
   where employee_id = any(v_ids);

  update public.shelf_check_actions
     set created_at = created_at + v_shift
   where employee_id = any(v_ids);

  update public.shelf_checks
     set created_at = created_at + v_shift
   where employee_id = any(v_ids);

  -- Run before the end of the day, some of "today" would be in the future.
  -- Pull those rows back to the last few hours, and treat a future clock-out
  -- as "still at work".
  update public.attendance_records
     set clock_out_at = null, clock_out_latitude = null, clock_out_longitude = null,
         clock_out_accuracy_meters = null, clock_out_selfie_url = null
   where employee_id = any(v_ids) and clock_out_at > now();
  update public.attendance_records
     set clock_in_at = now() - (random() * interval '3 hours') - interval '5 minutes'
   where employee_id = any(v_ids) and clock_in_at > now();
  update public.store_visits
     set visit_started_at = now() - (random() * interval '3 hours') - interval '5 minutes',
         visit_ended_at = null
   where employee_id = any(v_ids) and visit_started_at > now();
  update public.price_reports
     set created_at = now() - (random() * interval '3 hours')
   where employee_id = any(v_ids) and created_at > now();
  update public.sales_reports
     set created_at = now() - (random() * interval '3 hours')
   where employee_id = any(v_ids) and created_at > now();
  update public.shelf_checks
     set created_at = now() - (random() * interval '3 hours')
   where employee_id = any(v_ids) and created_at > now();
  update public.shelf_check_actions
     set created_at = now() - (random() * interval '2 hours')
   where employee_id = any(v_ids) and created_at > now();

  raise notice 'Demo data moved forward % day(s). Newest day is now %.', v_days, v_today;
end $$;
