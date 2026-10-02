-- 04: Storage buckets/policies and Realtime

insert into storage.buckets (id, name, public)
values ('vehicle-photos', 'vehicle-photos', true),   -- public read: shown on cards and printed challans
       ('site-photos', 'site-photos', false)         -- private: job proof photos from drivers
on conflict (id) do nothing;

-- vehicle photos: path <vehicle_id>/<file>; admin writes
create policy "vehicle photos: read" on storage.objects
  for select to authenticated using (bucket_id = 'vehicle-photos');
create policy "vehicle photos: admin insert" on storage.objects
  for insert to authenticated with check (bucket_id = 'vehicle-photos' and public.app_is_admin());
create policy "vehicle photos: admin update" on storage.objects
  for update to authenticated using (bucket_id = 'vehicle-photos' and public.app_is_admin());
create policy "vehicle photos: admin delete" on storage.objects
  for delete to authenticated using (bucket_id = 'vehicle-photos' and public.app_is_admin());

-- site photos: path <challan_id>/<file>; the assigned driver uploads, anyone who can see the challan reads
create policy "site photos: read if challan visible" on storage.objects
  for select to authenticated
  using (bucket_id = 'site-photos'
         and exists (select 1 from public.challans c where c.id::text = (storage.foldername(name))[1]));
create policy "site photos: assigned driver uploads" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'site-photos'
              and exists (select 1 from public.challans c
                          where c.id::text = (storage.foldername(name))[1]
                            and c.driver_id = public.app_driver_id()
                            and c.status in ('started', 'reached')));

-- Realtime: changes are delivered subject to the RLS policies above
alter publication supabase_realtime add table
  public.challans, public.challan_events, public.vehicles, public.payments, public.driver_locations;
