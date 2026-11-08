-- Laporan Eksekusi Kampanye: sales memotret materi kampanye di toko
-- (poster depan toko, poster dekat produk, QR di kasir, dst). Manajer
-- melihatnya di Galeri Foto dengan filter kampanye, bulan, dan salesman.
-- NOT YET APPLIED to the live project.

create table public.campaigns (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  -- Nama slot foto yang wajib diisi untuk kampanye ini, urut tampil.
  photo_slots text[] not null default array[
    'Poster di depan toko',
    'Poster dekat produk',
    'QR di kasir'
  ],
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint campaigns_slots_not_empty check (cardinality(photo_slots) between 1 and 6)
);
alter table public.campaigns enable row level security;
create policy "campaigns_select_authenticated" on public.campaigns
  for select using (auth.uid() is not null);
create policy "campaigns_manage_manager" on public.campaigns
  for all using (public.is_manager_or_admin()) with check (public.is_manager_or_admin());

create table public.execution_reports (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.profiles(id) on delete cascade,
  store_id uuid not null references public.stores(id) on delete cascade,
  campaign_id uuid not null references public.campaigns(id) on delete restrict,
  -- Selalu tanggal 1 bulan laporan.
  report_month date not null check (extract(day from report_month) = 1),
  created_at timestamptz not null default now(),
  -- Satu laporan per toko per kampanye per bulan, supaya hitungan
  -- "jumlah toko" di papan peringkat tidak ganda.
  unique (store_id, campaign_id, report_month)
);
create index execution_reports_month_idx on public.execution_reports (report_month desc, campaign_id);
create index execution_reports_employee_idx on public.execution_reports (employee_id, created_at desc);
alter table public.execution_reports enable row level security;
create policy "execution_reports_select_own_or_manager" on public.execution_reports
  for select using (employee_id = auth.uid() or public.is_manager_or_admin());
create policy "execution_reports_insert_own" on public.execution_reports
  for insert with check (employee_id = auth.uid());

create table public.execution_photos (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.execution_reports(id) on delete cascade,
  slot_label text not null,
  photo_path text not null,   -- bucket execution-photos, {employee_id}/...
  created_at timestamptz not null default now()
);
create index execution_photos_report_idx on public.execution_photos (report_id);
alter table public.execution_photos enable row level security;
create policy "execution_photos_select_own_or_manager" on public.execution_photos
  for select using (
    exists (
      select 1 from public.execution_reports r
      where r.id = report_id and (r.employee_id = auth.uid() or public.is_manager_or_admin())
    )
  );
create policy "execution_photos_insert_own" on public.execution_photos
  for insert with check (
    exists (
      select 1 from public.execution_reports r
      where r.id = report_id and r.employee_id = auth.uid()
    )
  );

insert into storage.buckets (id, name, public)
values ('execution-photos', 'execution-photos', false)
on conflict (id) do nothing;

create policy "execution_photos_insert_own_folder" on storage.objects
  for insert with check (
    bucket_id = 'execution-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy "execution_photos_select_own_or_manager" on storage.objects
  for select using (
    bucket_id = 'execution-photos'
    and ((storage.foldername(name))[1] = auth.uid()::text or public.is_manager_or_admin())
  );
