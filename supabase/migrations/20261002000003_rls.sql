-- 03: grants and Row Level Security
-- Principle: the API roles get SELECT, and write access only where a role may write
-- directly (admin masters, driver GPS). Everything else is done through RPC functions.

revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
revoke all on all functions in schema public from anon, public;
alter default privileges in schema public revoke all on tables from anon, authenticated;
alter default privileges in schema public revoke execute on functions from anon, public;

grant usage on schema public to authenticated;
grant select on all tables in schema public to authenticated;
revoke select on public.challan_counters from authenticated;
grant execute on all functions in schema public to authenticated;

-- admin-maintained master tables
grant insert, update, delete on
  public.tehsils, public.profiles, public.drivers, public.vehicle_types, public.vehicles,
  public.vehicle_photos, public.vehicle_maintenance, public.areas, public.tariffs, public.settings
to authenticated;

-- driver GPS
grant insert, update on public.driver_locations to authenticated;

-- enable RLS everywhere
do $$
declare t text;
begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

-- ---------------------------------------------------------------- masters readable by every signed-in user
create policy "read" on public.tehsils       for select to authenticated using (true);
create policy "read" on public.vehicle_types for select to authenticated using (true);
create policy "read" on public.settings      for select to authenticated using (true);

create policy "admin write" on public.tehsils       for all to authenticated using (public.app_is_admin()) with check (public.app_is_admin());
create policy "admin write" on public.vehicle_types for all to authenticated using (public.app_is_admin()) with check (public.app_is_admin());
create policy "admin write" on public.settings      for all to authenticated using (public.app_is_admin()) with check (public.app_is_admin());

-- ---------------------------------------------------------------- tehsil-scoped masters
create policy "read own tehsil" on public.areas
  for select to authenticated using (public.app_can_see_tehsil(tehsil_id));
create policy "admin write" on public.areas
  for all to authenticated using (public.app_is_admin()) with check (public.app_is_admin());

create policy "read own tehsil" on public.tariffs
  for select to authenticated
  using (exists (select 1 from public.areas a where a.id = area_id and public.app_can_see_tehsil(a.tehsil_id)));
create policy "admin write" on public.tariffs
  for all to authenticated using (public.app_is_admin()) with check (public.app_is_admin());

create policy "read own tehsil" on public.vehicles
  for select to authenticated using (public.app_can_see_tehsil(tehsil_id));
create policy "admin write" on public.vehicles
  for all to authenticated using (public.app_is_admin()) with check (public.app_is_admin());

create policy "read own tehsil" on public.vehicle_photos
  for select to authenticated
  using (exists (select 1 from public.vehicles v where v.id = vehicle_id and public.app_can_see_tehsil(v.tehsil_id)));
create policy "admin write" on public.vehicle_photos
  for all to authenticated using (public.app_is_admin()) with check (public.app_is_admin());

create policy "staff read own tehsil" on public.vehicle_maintenance
  for select to authenticated
  using (public.app_is_staff()
         and exists (select 1 from public.vehicles v where v.id = vehicle_id and public.app_can_see_tehsil(v.tehsil_id)));
create policy "admin write" on public.vehicle_maintenance
  for all to authenticated using (public.app_is_admin()) with check (public.app_is_admin());

create policy "read own tehsil" on public.drivers
  for select to authenticated using (public.app_can_see_tehsil(tehsil_id));
create policy "admin write" on public.drivers
  for all to authenticated using (public.app_is_admin()) with check (public.app_is_admin());

-- ---------------------------------------------------------------- people
create policy "read self or tehsil staff" on public.profiles
  for select to authenticated
  using (id = auth.uid() or public.app_is_admin()
         or (public.app_is_staff() and tehsil_id = public.app_tehsil_id()));
create policy "admin write" on public.profiles
  for all to authenticated using (public.app_is_admin()) with check (public.app_is_admin());

create policy "staff read own tehsil" on public.customers
  for select to authenticated using (public.app_is_staff() and public.app_can_see_tehsil(tehsil_id));

-- ---------------------------------------------------------------- challans (no direct writes at all)
create policy "staff read own tehsil, driver reads own jobs" on public.challans
  for select to authenticated
  using ((public.app_is_staff() and public.app_can_see_tehsil(tehsil_id))
         or (driver_id is not null and driver_id = public.app_driver_id()));

-- visibility follows the challan (RLS on challans applies inside the subquery)
create policy "read if challan visible" on public.challan_events
  for select to authenticated using (exists (select 1 from public.challans c where c.id = challan_id));
create policy "read if challan visible" on public.payments
  for select to authenticated using (exists (select 1 from public.challans c where c.id = challan_id));

-- ---------------------------------------------------------------- driver GPS
create policy "staff read own tehsil" on public.driver_locations
  for select to authenticated
  using (driver_id = public.app_driver_id()
         or (public.app_is_staff()
             and exists (select 1 from public.drivers d where d.id = driver_id and public.app_can_see_tehsil(d.tehsil_id))));
create policy "driver writes own row" on public.driver_locations
  for insert to authenticated with check (driver_id = public.app_driver_id());
create policy "driver updates own row" on public.driver_locations
  for update to authenticated using (driver_id = public.app_driver_id()) with check (driver_id = public.app_driver_id());

-- ---------------------------------------------------------------- audit
create policy "admin read" on public.audit_log
  for select to authenticated using (public.app_is_admin());
