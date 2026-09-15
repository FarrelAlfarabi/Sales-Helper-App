-- Stores, each with a geofence center + radius.
--
-- SCOPE ASSUMPTION (see PROJECT_NOTES.md): geofence_radius_meters defaults
-- to 100m. That's a starting guess, not a measured value: a standalone
-- storefront with clear sky view typically gets 5-20m GPS accuracy in
-- urban Jakarta, but mall/indoor stores get much worse drift from
-- multipath off walls and structure -- 100m may be too tight for those and
-- needs a per-store override, which is why it's a column, not a constant.

create table public.stores (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  name text not null,
  address text,
  latitude double precision not null,
  longitude double precision not null,
  geofence_radius_meters integer not null default 100,
  is_active boolean not null default true,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger stores_set_updated_at
  before update on public.stores
  for each row execute function public.set_updated_at();

alter table public.stores enable row level security;
