-- Which employees are assigned to visit which stores.

create table public.store_assignments (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.profiles(id) on delete cascade,
  store_id uuid not null references public.stores(id) on delete cascade,
  is_active boolean not null default true,
  assigned_at timestamptz not null default now(),
  assigned_by uuid references public.profiles(id),
  unique (employee_id, store_id)
);

alter table public.store_assignments enable row level security;
