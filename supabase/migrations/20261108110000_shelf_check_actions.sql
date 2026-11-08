-- Catatan aksi sales di Cek Rak: apa yang benar-benar dikerjakan sales di rak
-- (menata ulang produk, menaruh produk baru, memasang promo, dst).
--
-- Tabel TERPISAH dari shelf_checks supaya tidak mengubah tabel itu dan tidak
-- bentrok dengan migrasi ringkasan kunjungan harian. Satu catatan per cek rak.
-- Sales hanya bisa menulis catatan miliknya sendiri. Manajer/admin hanya baca.

create table public.shelf_check_actions (
  id uuid primary key default gen_random_uuid(),
  shelf_check_id uuid not null unique references public.shelf_checks(id) on delete cascade,
  employee_id uuid not null references public.profiles(id) on delete cascade,
  actions text[] not null default '{}',
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint shelf_check_actions_codes check (
    actions <@ array[
      'rearranged','filled_gap','placed_new_product','moved_better_position',
      'installed_promo','fixed_price_tag','secondary_display','removed_damaged',
      'negotiated_space','no_action'
    ]::text[]
  ),
  constraint shelf_check_actions_note_len check (note is null or char_length(note) <= 1000)
);
create index shelf_check_actions_employee_idx
  on public.shelf_check_actions (employee_id, created_at desc);

create trigger shelf_check_actions_updated_at
  before update on public.shelf_check_actions
  for each row execute function public.set_updated_at();

alter table public.shelf_check_actions enable row level security;

create policy "shelf_check_actions_select_own_or_manager" on public.shelf_check_actions
  for select using (employee_id = auth.uid() or public.is_manager_or_admin());

-- Insert/update hanya boleh jika cek rak itu milik sales yang sama.
create policy "shelf_check_actions_insert_own" on public.shelf_check_actions
  for insert with check (
    employee_id = auth.uid()
    and exists (select 1 from public.shelf_checks s
                where s.id = shelf_check_id and s.employee_id = auth.uid())
  );
create policy "shelf_check_actions_update_own" on public.shelf_check_actions
  for update using (employee_id = auth.uid())
  with check (
    employee_id = auth.uid()
    and exists (select 1 from public.shelf_checks s
                where s.id = shelf_check_id and s.employee_id = auth.uid())
  );
