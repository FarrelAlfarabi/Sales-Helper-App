drop index if exists public.store_visits_restock_idx;
alter table public.store_visits
  drop column if exists restock_note,
  drop column if exists restock_requested;
