-- Store visits, geofence-validated against the store's zone.
--
-- TRUST MODEL (see PROJECT_NOTES.md): distance_from_store_meters and
-- is_within_geofence are ALWAYS recomputed server-side by the trigger
-- below, from the store's own stored lat/lng/radius, on every insert or
-- coordinate change. The client submits raw check-in coordinates and
-- nothing else about geofence status -- it cannot set is_within_geofence
-- itself. This stops the trivial "just send true" spoof.
--
-- What this does NOT defend against: GPS spoofing via a mock-location app
-- on a rooted/jailbroken or developer-unlocked device, which can feed the
-- OS location API fake coordinates before our code ever sees them. Real
-- defense against that needs device-integrity attestation (Play Integrity
-- API / DeviceCheck), which is out of scope for this MVP pass. Flagging
-- this explicitly rather than letting "geofenced" quietly imply "spoof-proof".

create table public.store_visits (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.profiles(id) on delete cascade,
  store_id uuid not null references public.stores(id) on delete cascade,
  visit_started_at timestamptz not null default now(),
  visit_ended_at timestamptz,
  check_in_latitude double precision not null,
  check_in_longitude double precision not null,
  check_in_accuracy_meters double precision,
  store_photo_url text,
  notes text,
  distance_from_store_meters double precision,
  is_within_geofence boolean,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index store_visits_employee_idx on public.store_visits (employee_id, visit_started_at desc);
create index store_visits_store_idx on public.store_visits (store_id, visit_started_at desc);

create trigger store_visits_set_updated_at
  before update on public.store_visits
  for each row execute function public.set_updated_at();

create or replace function public.compute_store_visit_geofence()
returns trigger
language plpgsql
as $$
declare
  v_lat double precision;
  v_lng double precision;
  v_radius integer;
begin
  select latitude, longitude, geofence_radius_meters
    into v_lat, v_lng, v_radius
    from public.stores
    where id = new.store_id;

  new.distance_from_store_meters := public.distance_meters(
    new.check_in_latitude, new.check_in_longitude, v_lat, v_lng
  );
  new.is_within_geofence := new.distance_from_store_meters <= v_radius;

  return new;
end;
$$;

create trigger store_visits_geofence_check
  before insert or update of check_in_latitude, check_in_longitude, store_id
  on public.store_visits
  for each row execute function public.compute_store_visit_geofence();

alter table public.store_visits enable row level security;
