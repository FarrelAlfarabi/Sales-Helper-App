-- Restock requests captured per store visit, so managers can count them per salesman per day.
-- Idempotent. Rollback: supabase/rollback/20261108120000_visit_restock_request.sql
-- The integrity trigger on store_visits does not lock these columns, so a rep can set them
-- on their own visit through the existing "store_visits_update_own" policy.

alter table public.store_visits
  add column if not exists restock_requested boolean not null default false,
  add column if not exists restock_note text;

create index if not exists store_visits_restock_idx
  on public.store_visits (visit_started_at desc) where restock_requested;
