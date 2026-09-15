-- Employee profiles, 1:1 with auth.users. Real Supabase Auth from day one:
-- every row here is created only via the auth.users trigger below, tied to
-- a real authenticated session. There is no separate "fake verification"
-- path -- see PROJECT_NOTES.md for why that matters here versus the prior
-- project.

create type public.employee_role as enum ('field_rep', 'manager', 'admin');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  employee_code text unique,
  full_name text not null,
  role public.employee_role not null default 'field_rep',
  phone text,
  avatar_url text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- Employee accounts are provisioned by an admin (Supabase dashboard or
-- Admin API), not public self-signup -- a field-force roster shouldn't let
-- anyone register as "an employee". This trigger just mirrors whatever
-- auth.users row exists into profiles.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', new.email),
    coalesce((new.raw_user_meta_data->>'role')::public.employee_role, 'field_rep')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;
