-- Seed sanity + database rules (run as the owner, like the Supabase SQL editor)
-- Runs with psql (tool/db_test.sh), `supabase db query --linked -f`, or the Supabase SQL Editor.
-- Any failed check stops the script with an error; the last line shows "ok".

do $$
declare
  n int;
begin
  assert (select count(*) from public.tehsils) = 4, 'tehsils';
  assert (select count(*) from public.tehsils where is_active) = 1, 'only Bhakkar active';
  assert (select count(*) from public.areas) = 3, 'areas';
  assert (select count(*) from public.vehicle_types) = 8, 'vehicle types';
  assert (select count(*) from public.tariffs where is_active) = 24, 'tariff 3 areas x 8 types';
  assert (select count(*) from public.vehicles) = 12, 'vehicles';
  assert (select count(distinct vehicle_type_id) from public.vehicles) = 8, 'vehicles cover all types';
  assert (select count(*) from public.vehicles where status = 'maintenance') = 1, 'one in maintenance';
  assert (select count(*) from public.vehicles where status = 'on_job') = 3, 'three on job';
  assert (select status from public.vehicles where reg_no = 'BKR-1234') = 'available', 'demo sucker available';
  assert (select count(*) from public.profiles) = 10, 'profiles created by auth trigger';
  assert (select count(*) from public.profiles where role = 'driver') = 6, 'driver profiles';
  assert (select count(*) from public.drivers where profile_id is not null) = 6, 'drivers linked';
  assert (select count(*) from public.challans) = 40, '40 challans';
  assert (select count(distinct display_status) from public.challans) >= 6, 'mixed statuses';
  assert (select count(*) from public.challans c
          where (select count(*) from public.challans c2 where c2.customer_phone = c.customer_phone) > 1) > 0,
         'returning customers';
  assert (select count(*) from public.payments) = (select count(*) from public.challans where payment_status = 'paid'),
         'one payment per paid challan';
  assert (select count(*) from public.audit_log) > 0, 'audit log filled by triggers';

  -- numbering: WASA-BKR-YYYY-000001.. in time order, 18-digit reference
  assert not exists (select 1 from public.challans where challan_no !~ '^WASA-BKR-[0-9]{4}-[0-9]{6}$'), 'number format';
  assert not exists (select 1 from public.challans where payment_ref !~ '^4011[0-9]{14}$'), 'reference format';
  select count(*) into n from (
    select challan_no, lag(challan_no) over (order by created_at) as prev from public.challans) s
  where prev is not null and prev > challan_no and left(prev, 13) = left(challan_no, 13);
  assert n = 0, 'numbers follow creation time';
  assert public.format_challan_no('BKR', 2026, 7) = 'WASA-BKR-2026-000007', 'format_challan_no';

  -- QR signatures are valid
  assert not exists (select 1 from public.challans
                     where qr_signature <> private.sign_challan(challan_no, payment_ref, amount)), 'signatures';
  assert private.amount_text(2000) = '2000.00' and private.amount_text(1234.5) = '1234.50', 'amount text';

  -- tariff: amount = rate x quantity
  assert not exists (select 1 from public.challans where amount <> rate * quantity), 'amount = rate x qty';

  -- status machine
  assert public.challan_transition_allowed('generated', 'assigned');
  assert public.challan_transition_allowed('reached', 'done');
  assert not public.challan_transition_allowed('generated', 'done');
  assert not public.challan_transition_allowed('done', 'started');
  assert not public.challan_transition_allowed('cancelled', 'assigned');
end $$;

-- the no-cash guard holds even for the table owner
do $$
begin
  begin
    update public.challans set payment_status = 'paid' where payment_status = 'unpaid';
    raise exception 'FAIL: owner could mark paid';
  exception when raise_exception then
    if sqlerrm like 'FAIL%' then raise; end if;
  end;
  begin
    insert into public.payments (challan_id, provider, transaction_id, amount, status)
    select id, 'cash', 'X1', amount, 'success' from public.challans limit 1;
    raise exception 'FAIL: payment row inserted without provider';
  exception when raise_exception then
    if sqlerrm like 'FAIL%' then raise; end if;
  end;
  begin
    update public.challans set amount = 1 where status = 'generated';
    raise exception 'FAIL: amount changed';
  exception when raise_exception then
    if sqlerrm like 'FAIL%' then raise; end if;
  end;
  begin
    update public.challans set status = 'started' where status = 'done';
    raise exception 'FAIL: done -> started allowed';
  exception when raise_exception then
    if sqlerrm like 'FAIL%' then raise; end if;
  end;
  begin
    update public.challans set status = 'cancelled', cancel_reason = 'x'
    where payment_status = 'paid' and status = 'done';
    raise exception 'FAIL: done/paid cancelled';
  exception when raise_exception then
    if sqlerrm like 'FAIL%' then raise; end if;
  end;
end $$;

select 'seed and rules: ok' as result;
