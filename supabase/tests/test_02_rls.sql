-- Row Level Security: each role sees and changes only what it should.
-- Runs with psql (tool/db_test.sh), `supabase db query --linked -f`, or the Supabase SQL Editor.
-- Any failed check stops the script with an error; the last line shows "ok".

-- helper: run the rest of the transaction as a given user
create or replace function pg_temp.login(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

-- expects the statement to fail with a permission / RLS error
create or replace function pg_temp.denied(p_sql text) returns boolean language plpgsql as $$
begin
  execute p_sql;
  return false;
exception when insufficient_privilege or raise_exception then
  return true;
end $$;

-- ---------------------------------------------------------------- anon sees nothing
begin;
set local role anon;
do $$ begin
  assert pg_temp.denied('select 1 from public.challans'), 'anon must not read challans';
  assert pg_temp.denied('select 1 from public.vehicles'), 'anon must not read vehicles';
  assert pg_temp.denied('select public.verify_challan_qr(''x'')'), 'anon must not verify';
end $$;
rollback;

-- ---------------------------------------------------------------- driver1
begin;
do $$ begin perform pg_temp.login('00000000-0000-4000-a000-000000000011'); end $$;
do $$
declare
  v_drv uuid := '00000000-0000-4000-b000-000000000001';
begin
  assert public.app_role() = 'driver', 'role';
  assert public.app_driver_id() = v_drv, 'driver id';
  assert (select count(*) from public.challans) > 0, 'driver sees own jobs';
  assert not exists (select 1 from public.challans where driver_id is distinct from v_drv), 'only own jobs';
  assert (select count(*) from public.customers) = 0, 'no customer list';
  assert (select count(*) from public.audit_log) = 0, 'no audit log';
  assert (select count(*) from public.vehicle_maintenance) = 0, 'no maintenance records';
  assert (select count(*) from public.vehicles) = 12, 'sees tehsil vehicles';
  assert pg_temp.denied('update public.challans set status = ''done'''), 'cannot update challans';
  assert pg_temp.denied('update public.challans set payment_status = ''paid'''), 'cannot mark paid';
  assert pg_temp.denied('insert into public.payments (challan_id, provider, transaction_id, amount, status)
                         select id, ''cash'', ''c1'', amount, ''success'' from public.challans limit 1'), 'cannot add payment';
  assert pg_temp.denied('insert into public.areas (tehsil_id, name_en, name_ur)
                         select id, ''X'', ''X'' from public.tehsils limit 1'), 'cannot add area';
  -- profile self-escalation does nothing
  update public.profiles set role = 'admin' where id = auth.uid();
  assert public.app_role() = 'driver', 'cannot become admin';
  -- own GPS row only
  update public.driver_locations set lat = 31.7 where driver_id = v_drv;
  update public.driver_locations set lat = 1 where driver_id <> v_drv;
  assert (select count(*) from public.driver_locations where lat = 1) = 0, 'cannot move other drivers';
  assert pg_temp.denied('insert into public.driver_locations (driver_id, lat, lng)
                         values (''00000000-0000-4000-b000-000000000002'', 1, 1)'), 'cannot insert other GPS';
end $$;
rollback;

-- ---------------------------------------------------------------- operator1
begin;
do $$ begin perform pg_temp.login('00000000-0000-4000-a000-000000000002'); end $$;
do $$ begin
  assert public.app_role() = 'operator';
  assert (select count(*) from public.challans) = 40, 'operator sees tehsil challans';
  assert (select count(*) from public.customers) = 15, 'operator sees customers';
  assert (select count(*) from public.audit_log) = 0, 'no audit log for operator';
  assert pg_temp.denied('update public.challans set payment_status = ''paid'''), 'operator cannot mark paid';
  assert pg_temp.denied('delete from public.challans'), 'operator cannot delete challans';
  assert pg_temp.denied('insert into public.vehicles (tehsil_id, reg_no, vehicle_type_id)
                         select tehsil_id, ''BKR-0000'', vehicle_type_id from public.vehicles limit 1'), 'operator cannot add vehicle';
  update public.tariffs set rate = 1;
  assert not exists (select 1 from public.tariffs where rate = 1), 'operator cannot change tariff';
end $$;
rollback;

-- ---------------------------------------------------------------- officer (read-only)
begin;
do $$ begin perform pg_temp.login('00000000-0000-4000-a000-000000000004'); end $$;
do $$ begin
  assert public.app_role() = 'officer';
  assert (select count(*) from public.challans) = 40, 'officer reads challans';
  update public.vehicles set status = 'available';
  assert (select count(*) from public.vehicles where status = 'maintenance') = 1, 'officer cannot change vehicles';
  assert pg_temp.denied('insert into public.settings (key, value) values (''x'', ''1'')'), 'officer cannot change settings';
end $$;
rollback;

-- ---------------------------------------------------------------- admin
begin;
do $$ begin perform pg_temp.login('00000000-0000-4000-a000-000000000001'); end $$;
do $$ begin
  assert public.app_is_admin();
  assert (select count(*) from public.audit_log) > 0, 'admin reads audit';
  insert into public.areas (tehsil_id, name_en, name_ur)
    select id, 'Test Area', 'ٹیسٹ' from public.tehsils where code = 'BKR';
  assert pg_temp.denied('update public.challans set payment_status = ''paid'''), 'even admin cannot mark paid';
end $$;
rollback;

-- ---------------------------------------------------------------- tehsil isolation
begin;
update public.tehsils set is_active = true where code = 'DKN';
insert into auth.users (id, email, raw_app_meta_data)
values ('00000000-0000-4000-a000-0000000000d1', 'op.dkn@wasabhakkar.demo',
        '{"role":"operator","tehsil":"DKN","full_name":"DK Operator"}');
do $$ begin perform pg_temp.login('00000000-0000-4000-a000-0000000000d1'); end $$;
do $$ begin
  assert (select t.code from public.tehsils t where t.id = public.app_tehsil_id()) = 'DKN';
  assert (select count(*) from public.challans) = 0, 'other tehsil: no Bhakkar challans';
  assert (select count(*) from public.vehicles) = 0, 'other tehsil: no Bhakkar vehicles';
  assert (select count(*) from public.areas) = 0, 'other tehsil: no Bhakkar areas';
end $$;
rollback;

-- ---------------------------------------------------------------- QR verification
begin;
do $$ begin perform pg_temp.login('00000000-0000-4000-a000-000000000016'); end $$;
do $$
declare
  c public.challans;
  r jsonb;
  good text;
begin
  set local role postgres;
  select * into c from public.challans where payment_status = 'paid' limit 1;
  good := format('WASA1|%s|%s|%s|%s', c.challan_no, c.payment_ref, private.amount_text(c.amount), c.qr_signature);
  set local role authenticated;
  r := public.verify_challan_qr(good);
  assert (r ->> 'genuine')::boolean, 'genuine QR: ' || r::text;
  assert r ->> 'payment_status' = 'paid', 'shows paid';
  r := public.verify_challan_qr(format('WASA1|%s|%s|%s|%s', c.challan_no, c.payment_ref, '1.00', c.qr_signature));
  assert not (r ->> 'genuine')::boolean and r ->> 'reason' = 'bad_signature', 'tampered amount';
  r := public.verify_challan_qr('hello');
  assert r ->> 'reason' = 'not_a_wasa_challan', 'garbage';
  r := public.verify_challan_qr('WASA1|a|b|notanumber|d');
  assert r ->> 'reason' = 'not_a_wasa_challan', 'bad amount';
end $$;
rollback;

select 'row level security: ok' as result;
