-- SECURITY FIX: the profiles_update_own policy (from the first migration
-- pass) lets a user update their own profile row, but never restricted
-- WHICH columns they could change -- including `role`. As written, any
-- authenticated field_rep could run
--   update profiles set role = 'admin' where id = auth.uid();
-- and grant themselves admin/manager access. Found while building the
-- admin-only user-creation dashboard, where it would have completely
-- undermined the "only an admin can access this" requirement.
--
-- Fix: a trigger that blocks a role change unless the actor is already
-- manager/admin. auth.uid() is null when running outside a normal
-- PostgREST/RLS session (direct SQL via the dashboard or service_role) --
-- that path is treated as trusted, since it already requires database
-- access no employee has.

create or replace function public.prevent_self_role_escalation()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if new.role <> old.role and auth.uid() is not null and not public.is_manager_or_admin() then
    raise exception 'Only a manager or admin can change a profile''s role.';
  end if;
  return new;
end;
$$;

create trigger profiles_prevent_self_role_escalation
  before update on public.profiles
  for each row execute function public.prevent_self_role_escalation();
