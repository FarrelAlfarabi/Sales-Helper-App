-- Leave requests (sick / permit / off day / leave), deferred from the
-- initial pass. SCOPE ASSUMPTION: simple pending -> approved/rejected
-- workflow, reviewed by any manager/admin (not a specific assigned
-- manager -- there's no manager-to-employee reporting-line concept in
-- this schema yet). An employee can cancel their own request only while
-- it's still pending. Leave requests do NOT block or interact with
-- clock-in/clock-out -- that's a separate policy decision not made here.

create type public.leave_type as enum ('sick', 'permit', 'off_day', 'leave');
create type public.leave_status as enum ('pending', 'approved', 'rejected');

create table public.leave_requests (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.profiles(id) on delete cascade,
  leave_type public.leave_type not null,
  start_date date not null,
  end_date date not null,
  reason text,
  status public.leave_status not null default 'pending',
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint end_after_start check (end_date >= start_date)
);

create index leave_requests_employee_idx on public.leave_requests (employee_id, start_date desc);

create trigger leave_requests_set_updated_at
  before update on public.leave_requests
  for each row execute function public.set_updated_at();

alter table public.leave_requests enable row level security;

create policy "leave_requests_select_own_or_manager" on public.leave_requests
  for select using (employee_id = auth.uid() or public.is_manager_or_admin());
create policy "leave_requests_insert_own" on public.leave_requests
  for insert with check (employee_id = auth.uid());
create policy "leave_requests_update_manager" on public.leave_requests
  for update using (public.is_manager_or_admin()) with check (public.is_manager_or_admin());
create policy "leave_requests_delete_own_pending" on public.leave_requests
  for delete using (employee_id = auth.uid() and status = 'pending');
