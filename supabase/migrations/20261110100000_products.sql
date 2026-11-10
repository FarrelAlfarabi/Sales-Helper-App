-- Product master list. Reps tap a product instead of typing its name, so
-- sales and price reports stop splitting one product across several spellings.
-- Additive and idempotent. sales_reports and price_reports keep product_name
-- as text, so old rows and reports keep working.

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  brand text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
create unique index if not exists products_name_key on public.products (lower(name));

alter table public.products enable row level security;

drop policy if exists "products_select_authenticated" on public.products;
create policy "products_select_authenticated" on public.products
  for select using (auth.uid() is not null);

drop policy if exists "products_write_manager" on public.products;
create policy "products_write_manager" on public.products
  for all using (public.is_manager_or_admin()) with check (public.is_manager_or_admin());

-- Start the list from the product names reps already typed.
insert into public.products (name)
select distinct on (lower(trim(product_name))) trim(product_name)
  from (
    select product_name from public.sales_reports
    union all
    select product_name from public.price_reports
  ) p
 where trim(product_name) <> ''
on conflict do nothing;
