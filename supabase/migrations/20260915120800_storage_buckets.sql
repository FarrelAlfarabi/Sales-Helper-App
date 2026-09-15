-- Private storage buckets for selfies and store/OSA photos. All private
-- (public = false): access goes through signed URLs, never a public path.
-- Convention: object path is "{employee_id}/{filename}" so storage RLS can
-- key off the first path segment.
--
-- RETENTION: no auto-deletion policy exists yet. Selfies + GPS-tagged
-- photos accumulate indefinitely under this migration -- that's a real
-- data-privacy question (employee biometrics-adjacent data, Indonesia's
-- UU PDP), not a decision to make silently. Flagged in PROJECT_NOTES.md
-- for a human call on retention period.

insert into storage.buckets (id, name, public)
values
  ('attendance-selfies', 'attendance-selfies', false),
  ('store-visit-photos', 'store-visit-photos', false),
  ('osa-photos', 'osa-photos', false)
on conflict (id) do nothing;

create policy "selfies_insert_own_folder" on storage.objects
  for insert with check (
    bucket_id = 'attendance-selfies'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy "selfies_select_own_or_manager" on storage.objects
  for select using (
    bucket_id = 'attendance-selfies'
    and ((storage.foldername(name))[1] = auth.uid()::text or public.is_manager_or_admin())
  );

create policy "store_visit_photos_insert_own_folder" on storage.objects
  for insert with check (
    bucket_id = 'store-visit-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy "store_visit_photos_select_own_or_manager" on storage.objects
  for select using (
    bucket_id = 'store-visit-photos'
    and ((storage.foldername(name))[1] = auth.uid()::text or public.is_manager_or_admin())
  );

create policy "osa_photos_insert_own_folder" on storage.objects
  for insert with check (
    bucket_id = 'osa-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy "osa_photos_select_own_or_manager" on storage.objects
  for select using (
    bucket_id = 'osa-photos'
    and ((storage.foldername(name))[1] = auth.uid()::text or public.is_manager_or_admin())
  );
