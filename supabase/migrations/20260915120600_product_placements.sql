-- On Shelf Availability: product placement photos taken during a store
-- visit (main shelf, checkout/COC cashier display, secondary display).

create type public.placement_type as enum ('main_shelf', 'checkout_display', 'secondary_display');

create table public.product_placements (
  id uuid primary key default gen_random_uuid(),
  store_visit_id uuid not null references public.store_visits(id) on delete cascade,
  placement_type public.placement_type not null,
  photo_url text not null,
  notes text,
  created_at timestamptz not null default now()
);

create index product_placements_visit_idx on public.product_placements (store_visit_id);

alter table public.product_placements enable row level security;
