-- Row Level Security policies. All tables had RLS enabled with no
-- policies in their own migrations (fail-closed by default); this
-- migration is what actually opens access up.

-- security definer so this can read profiles.role without itself being
-- blocked by the RLS policy it's used inside of (avoids recursion).
create or replace function public.is_manager_or_admin()
returns boolean
language sql stable
security definer set search_path = public
as $$
  select coalesce((select role in ('manager', 'admin') from public.profiles where id = auth.uid()), false);
$$;

-- profiles: everyone can see their own row; managers/admins see everyone.
create policy "profiles_select_own_or_manager" on public.profiles
  for select using (id = auth.uid() or public.is_manager_or_admin());
create policy "profiles_update_own" on public.profiles
  for update using (id = auth.uid());

-- stores: any authenticated employee can read (they need to see their
-- assigned stores); only managers/admins can create or edit stores.
create policy "stores_select_authenticated" on public.stores
  for select using (auth.uid() is not null);
create policy "stores_write_manager" on public.stores
  for all using (public.is_manager_or_admin()) with check (public.is_manager_or_admin());

-- store_assignments: employees see their own assignments; managers see all.
create policy "store_assignments_select_own_or_manager" on public.store_assignments
  for select using (employee_id = auth.uid() or public.is_manager_or_admin());
create policy "store_assignments_write_manager" on public.store_assignments
  for all using (public.is_manager_or_admin()) with check (public.is_manager_or_admin());

-- attendance_records: employees insert/read their own; managers read all.
create policy "attendance_select_own_or_manager" on public.attendance_records
  for select using (employee_id = auth.uid() or public.is_manager_or_admin());
create policy "attendance_insert_own" on public.attendance_records
  for insert with check (employee_id = auth.uid());
create policy "attendance_update_own" on public.attendance_records
  for update using (employee_id = auth.uid());

-- store_visits: same pattern as attendance.
create policy "store_visits_select_own_or_manager" on public.store_visits
  for select using (employee_id = auth.uid() or public.is_manager_or_admin());
create policy "store_visits_insert_own" on public.store_visits
  for insert with check (employee_id = auth.uid());
create policy "store_visits_update_own" on public.store_visits
  for update using (employee_id = auth.uid());

-- product_placements: access follows the parent store_visit's ownership.
create policy "product_placements_select_own_or_manager" on public.product_placements
  for select using (
    exists (
      select 1 from public.store_visits sv
      where sv.id = store_visit_id
        and (sv.employee_id = auth.uid() or public.is_manager_or_admin())
    )
  );
create policy "product_placements_insert_own" on public.product_placements
  for insert with check (
    exists (
      select 1 from public.store_visits sv
      where sv.id = store_visit_id and sv.employee_id = auth.uid()
    )
  );
