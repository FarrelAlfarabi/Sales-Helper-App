-- Clock in / clock out attendance. Per the reference deck, attendance is
-- selfie + location capture with NO geofence validation (that only applies
-- to store visits, see store_visits migration) -- an employee can clock in
-- from anywhere, the location is a record, not a gate.
--
-- SCOPE ASSUMPTION: clock_in_accuracy_meters (device-reported horizontal
-- accuracy) is stored but not enforced as a hard cutoff. A hard "reject if
-- accuracy worse than Xm" would make the app unusable indoors/in malls
-- where accuracy is routinely poor. Instead we keep the raw number so
-- managers reviewing reports can see low-confidence submissions
-- themselves. Revisit if abuse shows up in practice.
--
-- OUT OF SCOPE for this migration: sick leave / permit / off-day / leave
-- request types shown in the reference deck's Attendance menu. Only
-- clock-in/clock-out is modeled here; leave-request workflow is a
-- deliberately deferred feature, not an oversight.

create table public.attendance_records (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.profiles(id) on delete cascade,
  clock_in_at timestamptz not null default now(),
  clock_in_latitude double precision not null,
  clock_in_longitude double precision not null,
  clock_in_accuracy_meters double precision,
  clock_in_selfie_url text not null,
  clock_out_at timestamptz,
  clock_out_latitude double precision,
  clock_out_longitude double precision,
  clock_out_accuracy_meters double precision,
  clock_out_selfie_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint clock_out_after_clock_in check (clock_out_at is null or clock_out_at >= clock_in_at)
);

create index attendance_records_employee_idx on public.attendance_records (employee_id, clock_in_at desc);

create trigger attendance_records_set_updated_at
  before update on public.attendance_records
  for each row execute function public.set_updated_at();

alter table public.attendance_records enable row level security;
