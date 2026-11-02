-- Pricing: per-store shelf price check submitted by field reps.
-- NOT YET APPLIED to the live project. Apply before using the Pricing screen.

create table public.price_reports (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.profiles(id) on delete cascade,
  store_id uuid not null references public.stores(id) on delete cascade,
  product_name text not null,
  price_idr integer not null check (price_idr >= 0),
  is_promo boolean not null default false,
  notes text,
  created_at timestamptz not null default now()
);

create index price_reports_employee_idx on public.price_reports (employee_id, created_at desc);
create index price_reports_store_idx on public.price_reports (store_id, created_at desc);

alter table public.price_reports enable row level security;

create policy "price_reports_select_own_or_manager" on public.price_reports
  for select using (employee_id = auth.uid() or public.is_manager_or_admin());
create policy "price_reports_insert_own" on public.price_reports
  for insert with check (employee_id = auth.uid());
