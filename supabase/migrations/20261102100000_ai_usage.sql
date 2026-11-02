-- Token usage per AI call, so managers can see a rough estimate of remaining API credit.
create table if not exists public.ai_usage (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  fn text not null,
  model text not null,
  input_tokens integer not null default 0,
  output_tokens integer not null default 0,
  cost_usd numeric(10,6) not null default 0
);
alter table public.ai_usage enable row level security;
create policy ai_usage_insert_own on public.ai_usage
  for insert to authenticated with check (user_id = auth.uid());
create policy ai_usage_select_managers on public.ai_usage
  for select to authenticated using (public.is_manager_or_admin());
