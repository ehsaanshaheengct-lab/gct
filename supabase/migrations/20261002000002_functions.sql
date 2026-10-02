-- 02: helper functions, numbering, QR signing, guards, audit

-- ---------------------------------------------------------------- who am I (used by RLS)
create or replace function public.app_role()
returns public.user_role language sql stable security definer set search_path = '' as $$
  select p.role from public.profiles p where p.id = auth.uid() and p.is_active
$$;

create or replace function public.app_tehsil_id()
returns uuid language sql stable security definer set search_path = '' as $$
  select p.tehsil_id from public.profiles p where p.id = auth.uid() and p.is_active
$$;

create or replace function public.app_is_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(public.app_role() = 'admin', false)
$$;

-- admin, operator or officer (office staff)
create or replace function public.app_is_staff()
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(public.app_role() in ('admin', 'operator', 'officer'), false)
$$;

-- the drivers.id linked to the signed-in user (null for non-drivers)
create or replace function public.app_driver_id()
returns uuid language sql stable security definer set search_path = '' as $$
  select d.id
  from public.drivers d
  join public.profiles p on p.id = d.profile_id
  where p.id = auth.uid() and p.is_active and d.is_active and p.role = 'driver'
$$;

-- true when the row's tehsil is visible to the current user
create or replace function public.app_can_see_tehsil(t uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.app_is_admin() or t = public.app_tehsil_id()
$$;

-- ---------------------------------------------------------------- new auth user -> profile
-- Role and tehsil come from raw_app_meta_data (only settable with the service key),
-- never from user-editable metadata.
create or replace function private.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_role   public.user_role;
  v_tehsil uuid;
begin
  if new.raw_app_meta_data ? 'role' then
    v_role := (new.raw_app_meta_data ->> 'role')::public.user_role;
    select id into v_tehsil from public.tehsils
      where code = coalesce(new.raw_app_meta_data ->> 'tehsil', 'BKR');
    insert into public.profiles (id, full_name, username, phone, role, tehsil_id)
    values (
      new.id,
      coalesce(new.raw_app_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'full_name', new.email),
      coalesce(new.raw_app_meta_data ->> 'username', split_part(new.email, '@', 1)),
      new.raw_app_meta_data ->> 'phone',
      v_role,
      v_tehsil)
    on conflict (id) do nothing;
  end if;
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- ---------------------------------------------------------------- updated_at
create or replace function private.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

do $$
declare t text;
begin
  foreach t in array array['profiles', 'drivers', 'vehicle_types', 'vehicles', 'customers', 'challans'] loop
    execute format('create trigger touch_updated_at before update on public.%I
                    for each row execute function private.touch_updated_at()', t);
  end loop;
end $$;

-- ---------------------------------------------------------------- dates
create or replace function public.karachi_today()
returns date language sql stable as $$
  select (now() at time zone 'Asia/Karachi')::date
$$;

-- ---------------------------------------------------------------- QR signing
-- canonical amount text: two decimals, no separators (same as Dart toStringAsFixed(2))
create or replace function private.amount_text(a numeric)
returns text language sql immutable as $$
  select to_char(round(a, 2), 'FM999999999990.00')
$$;

create or replace function private.sign_challan(p_no text, p_ref text, p_amount numeric)
returns text language sql stable security definer set search_path = '' as $$
  select left(encode(extensions.hmac(
           p_no || '|' || p_ref || '|' || private.amount_text(p_amount),
           (select value from private.app_secrets where key = 'qr_hmac_key'),
           'sha256'), 'hex'), 32)
$$;

-- ---------------------------------------------------------------- challan number + reference
create or replace function private.next_challan_seq(p_tehsil uuid, p_year int)
returns int language sql security definer set search_path = '' as $$
  insert into public.challan_counters as c (tehsil_id, year, last_seq)
  values (p_tehsil, p_year, 1)
  on conflict (tehsil_id, year) do update set last_seq = c.last_seq + 1
  returning last_seq
$$;

create or replace function public.format_challan_no(p_tehsil_code text, p_year int, p_seq int)
returns text language sql immutable as $$
  select 'WASA-' || p_tehsil_code || '-' || p_year || '-' || lpad(p_seq::text, 6, '0')
$$;

-- before insert: fill challan_no, payment_ref, qr_signature
create or replace function private.challan_before_insert()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_code  text;
  v_psid  smallint;
  v_year  int;
  v_seq   int;
begin
  select code, psid_code into v_code, v_psid from public.tehsils where id = new.tehsil_id;
  v_year := extract(year from (new.created_at at time zone 'Asia/Karachi'))::int;
  if new.challan_no is null then
    v_seq := private.next_challan_seq(new.tehsil_id, v_year);
    new.challan_no := public.format_challan_no(v_code, v_year, v_seq);
    new.payment_ref := '40' || lpad(v_psid::text, 2, '0') || v_year::text || lpad(v_seq::text, 6, '0')
                       || lpad(floor(random() * 10000)::int::text, 4, '0');
  end if;
  new.qr_signature := private.sign_challan(new.challan_no, new.payment_ref, new.amount);
  if new.payment_status = 'paid' and coalesce(current_setting('app.payment_callback', true), '') <> 'on' then
    raise exception 'A challan can only be marked Paid by the payment provider.' using errcode = 'P0001';
  end if;
  return new;
end $$;

create trigger challan_before_insert
  before insert on public.challans
  for each row execute function private.challan_before_insert();

-- ---------------------------------------------------------------- status machine
create or replace function public.challan_transition_allowed(p_from public.challan_status, p_to public.challan_status)
returns boolean language sql immutable as $$
  select case p_from
    when 'generated' then p_to in ('assigned', 'cancelled')
    when 'assigned'  then p_to in ('assigned', 'started', 'cancelled')   -- assigned -> assigned = reassign
    when 'started'   then p_to in ('reached', 'cancelled')
    when 'reached'   then p_to in ('done', 'cancelled')
    else false                                                           -- done, cancelled are final
  end
$$;

-- before update: the no-cash guard and immutable fields
create or replace function private.challan_guard()
returns trigger language plpgsql as $$
begin
  if new.challan_no <> old.challan_no or new.payment_ref <> old.payment_ref
     or new.amount <> old.amount or new.rate <> old.rate or new.quantity <> old.quantity
     or new.tehsil_id <> old.tehsil_id then
    raise exception 'Challan number, reference and amount cannot be changed. Cancel and issue a new challan.'
      using errcode = 'P0001';
  end if;

  if new.payment_status is distinct from old.payment_status then
    if new.payment_status = 'paid' and coalesce(current_setting('app.payment_callback', true), '') <> 'on' then
      raise exception 'A challan can only be marked Paid by the payment provider.' using errcode = 'P0001';
    end if;
    if old.payment_status = 'paid' then
      raise exception 'A paid challan cannot be changed back.' using errcode = 'P0001';
    end if;
  end if;

  if new.status is distinct from old.status
     and not public.challan_transition_allowed(old.status, new.status) then
    raise exception 'Status cannot change from % to %.', old.status, new.status using errcode = 'P0001';
  end if;

  if new.status = 'cancelled' and old.status <> 'cancelled' and new.payment_status = 'paid' then
    raise exception 'A paid challan cannot be cancelled.' using errcode = 'P0001';
  end if;

  new.qr_signature := old.qr_signature;
  return new;
end $$;

create trigger challan_guard
  before update on public.challans
  for each row execute function private.challan_guard();

-- payments rows only from the payment callback
create or replace function private.payment_guard()
returns trigger language plpgsql as $$
begin
  if coalesce(current_setting('app.payment_callback', true), '') <> 'on' then
    raise exception 'Payments can only be recorded by the payment provider.' using errcode = 'P0001';
  end if;
  return new;
end $$;

create trigger payment_guard
  before insert or update on public.payments
  for each row execute function private.payment_guard();

-- ---------------------------------------------------------------- QR verification
-- payload: WASA1|<challan_no>|<payment_ref>|<amount>|<sig>
create or replace function public.verify_challan_qr(p_payload text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  parts text[];
  c     public.challans;
begin
  if auth.uid() is null then
    raise exception 'Sign in first.' using errcode = '42501';
  end if;
  parts := string_to_array(trim(p_payload), '|');
  if array_length(parts, 1) <> 5 or parts[1] <> 'WASA1' then
    return jsonb_build_object('genuine', false, 'reason', 'not_a_wasa_challan');
  end if;
  if parts[5] is distinct from private.sign_challan(parts[2], parts[3], parts[4]::numeric) then
    return jsonb_build_object('genuine', false, 'reason', 'bad_signature', 'challan_no', parts[2]);
  end if;
  select * into c from public.challans where challan_no = parts[2];
  if not found or c.payment_ref <> parts[3] or c.amount <> parts[4]::numeric then
    return jsonb_build_object('genuine', false, 'reason', 'unknown_challan', 'challan_no', parts[2]);
  end if;
  return jsonb_build_object(
    'genuine', true,
    'challan_no', c.challan_no,
    'payment_ref', c.payment_ref,
    'amount', c.amount,
    'status', c.status,
    'payment_status', c.payment_status,
    'display_status', c.display_status,
    'paid_at', c.paid_at,
    'due_date', c.due_date,
    'customer_name', c.customer_name,
    'area', (select a.name_en from public.areas a where a.id = c.area_id),
    'vehicle_type', (select t.name_en from public.vehicle_types t where t.id = c.vehicle_type_id));
exception when invalid_text_representation then
  return jsonb_build_object('genuine', false, 'reason', 'not_a_wasa_challan');
end $$;

-- ---------------------------------------------------------------- audit log
create or replace function private.audit_row()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_old jsonb := case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) end;
  v_new jsonb := case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) end;
begin
  if tg_op = 'UPDATE' and v_old - 'updated_at' = v_new - 'updated_at' then
    return new;  -- nothing really changed
  end if;
  insert into public.audit_log (actor_id, table_name, record_id, action, old_data, new_data)
  values (auth.uid(), tg_table_name, coalesce(v_new ->> 'id', v_old ->> 'id', v_new ->> 'key', v_old ->> 'key'),
          tg_op, v_old, v_new);
  return coalesce(new, old);
end $$;

do $$
declare t text;
begin
  foreach t in array array['tehsils', 'profiles', 'drivers', 'vehicle_types', 'vehicles', 'vehicle_photos',
                           'vehicle_maintenance', 'areas', 'tariffs', 'challans', 'payments', 'settings'] loop
    execute format('create trigger audit after insert or update or delete on public.%I
                    for each row execute function private.audit_row()', t);
  end loop;
end $$;
