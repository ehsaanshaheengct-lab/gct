-- Phase 2: vehicle status, tariff history, photo order, vehicle stats.
-- Runs with psql (tool/db_test.sh), `supabase db query --linked -f`, or the Supabase SQL Editor.

create or replace function pg_temp.login(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

create or replace function pg_temp.fails(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return null;
exception when others then
  return sqlerrm;
end $$;

-- ---------------------------------------------------------------- operator changes vehicle status
begin;
do $$ begin perform pg_temp.login('00000000-0000-4000-a000-000000000002'); end $$;  -- operator1
do $$
declare
  v_id   uuid := (select id from public.vehicles where reg_no = 'BKR-7016');
  v_busy uuid := (select id from public.vehicles where reg_no = 'BKR-2741');  -- on a job
  e      text;
begin
  e := pg_temp.fails(format('select public.set_vehicle_status(%L, ''maintenance'', ''  '')', v_id));
  assert e like 'Write the reason%', 'reason required: ' || coalesce(e, 'no error');

  perform public.set_vehicle_status(v_id, 'maintenance', 'Brake repair', public.karachi_today() + 2);
  assert (select status from public.vehicles where id = v_id) = 'maintenance', 'now in maintenance';
  assert (select count(*) from public.vehicle_maintenance where vehicle_id = v_id and ended_on is null) = 1,
         'open maintenance entry created';

  perform public.set_vehicle_status(v_id, 'available');
  assert (select status from public.vehicles where id = v_id) = 'available', 'back to available';
  assert (select status_reason from public.vehicles where id = v_id) is null, 'reason cleared';
  assert not exists (select 1 from public.vehicle_maintenance where vehicle_id = v_id and ended_on is null),
         'maintenance entry closed';

  e := pg_temp.fails(format('select public.set_vehicle_status(%L, ''maintenance'', ''x'')', v_busy));
  assert e like 'This vehicle is on a job%', 'busy vehicle: ' || coalesce(e, 'no error');
  e := pg_temp.fails(format('select public.set_vehicle_status(%L, ''on_job'')', v_id));
  assert e like 'On Job is set automatically%', 'on_job manual: ' || coalesce(e, 'no error');

  e := pg_temp.fails(format('select public.set_tariff_rate(a.id, t.id, 1) from public.areas a, public.vehicle_types t limit 1'));
  assert e like 'You do not have permission%', 'operator cannot edit tariff: ' || coalesce(e, 'no error');
end $$;
rollback;

-- ---------------------------------------------------------------- officer and driver cannot change status
begin;
do $$ begin perform pg_temp.login('00000000-0000-4000-a000-000000000004'); end $$;  -- officer
do $$ begin
  assert pg_temp.fails(format('select public.set_vehicle_status(%L, ''maintenance'', ''x'')',
         (select id from public.vehicles where reg_no = 'BKR-7016'))) like 'You do not have permission%', 'officer';
  assert (select count(*) from public.vehicle_stats) = 12, 'officer reads vehicle stats';
end $$;
rollback;

begin;
do $$ begin perform pg_temp.login('00000000-0000-4000-a000-000000000011'); end $$;  -- driver1
do $$ begin
  assert pg_temp.fails(format('select public.set_vehicle_status(%L, ''maintenance'', ''x'')',
         (select id from public.vehicles where reg_no = 'BKR-1234'))) like 'You do not have permission%', 'driver';
end $$;
rollback;

-- ---------------------------------------------------------------- admin edits the tariff; history is kept
begin;
do $$ begin perform pg_temp.login('00000000-0000-4000-a000-000000000001'); end $$;  -- admin
do $$
declare
  v_area uuid := (select id from public.areas where name_en = 'Happy Land');
  v_type uuid := (select id from public.vehicle_types where code = 'sucker');
  t      public.tariffs;
begin
  t := public.set_tariff_rate(v_area, v_type, 2200);
  assert t.rate = 2200 and t.is_active and not t.is_placeholder and t.pricing_unit = 'per_trip', 'new rate';
  assert (select count(*) from public.tariffs where area_id = v_area and vehicle_type_id = v_type) = 2, 'history kept';
  assert (select count(*) from public.tariffs where area_id = v_area and vehicle_type_id = v_type and is_active) = 1,
         'one active';
  -- old challans keep the old rate
  assert exists (select 1 from public.challans c join public.tariffs tt on tt.id = c.tariff_id
                 where not tt.is_active and c.rate = 2000), 'challans keep their rate';
  assert pg_temp.fails(format('select public.set_tariff_rate(%L, %L, -5)', v_area, v_type)) like 'Enter a rate%', 'negative';
end $$;
rollback;

-- ---------------------------------------------------------------- photo order
begin;
insert into public.vehicle_photos (vehicle_id, storage_path, position, kind)
select v.id, v.id || '/' || k || '.jpg', o - 1, k
from public.vehicles v, unnest(array['front', 'side', 'back']) with ordinality as x (k, o)
where v.reg_no = 'BKR-1234';
do $$ begin perform pg_temp.login('00000000-0000-4000-a000-000000000001'); end $$;
do $$
declare
  v_id  uuid := (select id from public.vehicles where reg_no = 'BKR-1234');
  ids   uuid[] := array(select id from public.vehicle_photos where vehicle_id = v_id order by position desc);
begin
  perform public.reorder_vehicle_photos(v_id, ids);
  assert (select kind from public.vehicle_photos where vehicle_id = v_id and position = 0) = 'back', 'back is now main';
  assert pg_temp.fails(format('select public.reorder_vehicle_photos(%L, %L::uuid[])', v_id, ids[1:2]::text))
         like 'The photo list is out of date%', 'stale list';
end $$;
rollback;

-- ---------------------------------------------------------------- stats
do $$ begin
  assert (select sum(trips) from public.vehicle_stats) = (select count(*) from public.challans where status = 'done'), 'trips';
  assert (select days_in_maintenance from public.vehicle_stats s join public.vehicles v on v.id = s.vehicle_id
          where v.reg_no = 'BKR-6620') >= 2, 'maintenance days';
end $$;

select 'vehicles and masters: ok' as result;
