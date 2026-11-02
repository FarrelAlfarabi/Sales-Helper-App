-- Shelf Check (photo of an aisle -> AI restock flags), sales entries, and
-- stored AI insights. NOT YET APPLIED to the live project.

create table public.shelf_checks (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.profiles(id) on delete cascade,
  store_id uuid not null references public.stores(id) on delete cascade,
  store_visit_id uuid references public.store_visits(id) on delete set null,
  photo_path text not null,                -- osa-photos bucket, {employee_id}/...
  summary text,
  analysis jsonb not null default '{}'::jsonb,
  model text,
  created_at timestamptz not null default now()
);
create index shelf_checks_store_idx on public.shelf_checks (store_id, created_at desc);
create index shelf_checks_employee_idx on public.shelf_checks (employee_id, created_at desc);
alter table public.shelf_checks enable row level security;
create policy "shelf_checks_select_own_or_manager" on public.shelf_checks
  for select using (employee_id = auth.uid() or public.is_manager_or_admin());
create policy "shelf_checks_insert_own" on public.shelf_checks
  for insert with check (employee_id = auth.uid());

create table public.sales_reports (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.profiles(id) on delete cascade,
  store_id uuid not null references public.stores(id) on delete cascade,
  product_name text not null,
  units_sold integer not null check (units_sold >= 0),
  sale_date date not null default current_date,
  created_at timestamptz not null default now()
);
create index sales_reports_store_idx on public.sales_reports (store_id, sale_date desc);
alter table public.sales_reports enable row level security;
create policy "sales_reports_select_own_or_manager" on public.sales_reports
  for select using (employee_id = auth.uid() or public.is_manager_or_admin());
create policy "sales_reports_insert_own" on public.sales_reports
  for insert with check (employee_id = auth.uid());

create table public.ai_insights (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references public.profiles(id) on delete cascade,
  period_days integer not null,
  insight jsonb not null,
  data_summary jsonb,
  model text,
  created_at timestamptz not null default now()
);
alter table public.ai_insights enable row level security;
create policy "ai_insights_select_manager" on public.ai_insights
  for select using (public.is_manager_or_admin());
create policy "ai_insights_insert_manager" on public.ai_insights
  for insert with check (created_by = auth.uid() and public.is_manager_or_admin());
