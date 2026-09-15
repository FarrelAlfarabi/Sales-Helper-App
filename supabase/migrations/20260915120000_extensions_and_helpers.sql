-- Extensions and shared helper functions used by later migrations.

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Great-circle (haversine) distance in meters between two lat/lng points.
-- Used server-side for geofence checks so a client can never just submit
-- "I'm inside the zone" -- see store_visits migration and PROJECT_NOTES.md.
create or replace function public.distance_meters(
  lat1 double precision, lng1 double precision,
  lat2 double precision, lng2 double precision
) returns double precision
language sql
immutable
as $$
  select 6371000 * acos(
    least(1.0, greatest(-1.0,
      cos(radians(lat1)) * cos(radians(lat2)) * cos(radians(lng2) - radians(lng1))
      + sin(radians(lat1)) * sin(radians(lat2))
    ))
  );
$$;
