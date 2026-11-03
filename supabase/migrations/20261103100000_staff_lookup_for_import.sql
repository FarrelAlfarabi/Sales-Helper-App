-- Lets managers/admins match CSV rows to employees by email. Emails live in
-- auth.users, which the app cannot read, so this security-definer function
-- exposes only id, email, name and role, and only to managers/admins.
create or replace function public.list_staff_for_import()
returns table (id uuid, email text, full_name text, role public.employee_role)
language sql
stable
security definer
set search_path = public, auth
as $$
  select u.id, u.email::text, p.full_name, p.role
  from auth.users u
  join public.profiles p on p.id = u.id
  where public.is_manager_or_admin() and coalesce(p.is_active, true)
$$;
revoke all on function public.list_staff_for_import() from public, anon;
grant execute on function public.list_staff_for_import() to authenticated;
