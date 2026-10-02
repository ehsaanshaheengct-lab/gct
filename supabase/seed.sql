-- WASA Bhakkar demo seed. All rates are PLACEHOLDERS for the demo.
-- Logins (password for all: Wasa@1234) are listed in README.md.

-- ---------------------------------------------------------------- tehsils & areas
insert into public.tehsils (code, name_en, name_ur, psid_code, is_active, sort_order) values
  ('BKR', 'Bhakkar',    'بھکر',      11, true,  1),
  ('DKN', 'Darya Khan', 'دریا خان',  12, false, 2),
  ('MNK', 'Mankera',    'منکیرہ',    13, false, 3),
  ('KLK', 'Kallur Kot', 'کلورکوٹ',   14, false, 4);

insert into public.areas (tehsil_id, name_en, name_ur, sort_order)
select t.id, a.name_en, a.name_ur, a.sort_order
from public.tehsils t,
     (values ('Al-Hadi', 'الہادی', 1), ('Happy Land', 'ہیپی لینڈ', 2), ('Shaikh Rao Pull', 'شیخ راؤ پل', 3))
       as a (name_en, name_ur, sort_order)
where t.code = 'BKR';

-- ---------------------------------------------------------------- settings
insert into public.settings (key, value) values
  ('due_days',     '3'),
  ('org_name_en',  '"Water and Sanitation Agency (WASA), Bhakkar"'),
  ('org_name_ur',  '"واسا بھکر"'),
  ('helpline',     '"0453-000000 (placeholder)"'),
  ('demo_mode',    'true');

-- ---------------------------------------------------------------- vehicle types
insert into public.vehicle_types (code, name_en, name_ur, category, pricing_unit, payment_policy, icon_key, sort_order) values
  ('sucker',    'Sewer Suction Unit (Sucker)', 'سیور سکشن یونٹ (سکر)', 'sewer',         'per_trip', 'pay_after_service',   'sucker',    1),
  ('jetting',   'Jetting Machine',             'جیٹنگ مشین',           'sewer',         'per_trip', 'pay_after_service',   'jetting',   2),
  ('desilting', 'Desilting Machine',           'ڈی سلٹنگ مشین',        'sewer',         'per_day',  'pay_after_service',   'desilting', 3),
  ('tanker',    'Water Bowser (Tanker)',       'واٹر باؤزر (ٹینکر)',   'water',         'per_trip', 'pay_after_service',   'tanker',    4),
  ('dumper',    'Dumper',                      'ڈمپر',                 'heavy_utility', 'per_trip', 'pay_after_service',   'dumper',    5),
  ('crane',     'Truck Crane',                 'ٹرک کرین',             'heavy_utility', 'per_hour', 'pay_before_dispatch', 'crane',     6),
  ('pump',      'Mobile Dewatering Pump',      'موبائل ڈی واٹرنگ پمپ', 'heavy_utility', 'per_hour', 'pay_after_service',   'pump',      7),
  ('rickshaw',  'Loader Rickshaw',             'لوڈر رکشہ',            'small_utility', 'per_trip', 'pay_after_service',   'rickshaw',  8);

-- ---------------------------------------------------------------- tariff (PLACEHOLDER rates)
-- Al-Hadi and Happy Land: base rate. Shaikh Rao Pull (farther): base + 20%, rounded to 100.
insert into public.tariffs (area_id, vehicle_type_id, rate, pricing_unit, effective_from, is_placeholder)
select a.id, vt.id,
       case when a.name_en = 'Shaikh Rao Pull' then round(r.base * 1.2 / 100) * 100 else r.base end,
       vt.pricing_unit, date '2026-01-01', true
from public.areas a
cross join public.vehicle_types vt
join (values ('sucker', 2000), ('jetting', 2500), ('desilting', 5000), ('tanker', 1500),
             ('dumper', 3000), ('crane', 4000), ('pump', 1500), ('rickshaw', 800)) as r (code, base)
  on r.code = vt.code;

-- ---------------------------------------------------------------- users (auth + profiles via trigger)
do $$
declare
  u record;
begin
  for u in select * from (values
    ('00000000-0000-4000-a000-000000000001'::uuid, 'admin',     'Muhammad Asif',   'admin',    '0301-1000001'),
    ('00000000-0000-4000-a000-000000000002'::uuid, 'operator1', 'Rabia Noor',      'operator', '0301-1000002'),
    ('00000000-0000-4000-a000-000000000003'::uuid, 'operator2', 'Imran Khalid',    'operator', '0301-1000003'),
    ('00000000-0000-4000-a000-000000000004'::uuid, 'officer',   'Tariq Mehmood',   'officer',  '0301-1000004'),
    ('00000000-0000-4000-a000-000000000011'::uuid, 'driver1',   'Ghulam Abbas',    'driver',   '0306-2000001'),
    ('00000000-0000-4000-a000-000000000012'::uuid, 'driver2',   'Muhammad Riaz',   'driver',   '0306-2000002'),
    ('00000000-0000-4000-a000-000000000013'::uuid, 'driver3',   'Allah Ditta',     'driver',   '0306-2000003'),
    ('00000000-0000-4000-a000-000000000014'::uuid, 'driver4',   'Zafar Iqbal',     'driver',   '0306-2000004'),
    ('00000000-0000-4000-a000-000000000015'::uuid, 'driver5',   'Nadeem Akhtar',   'driver',   '0306-2000005'),
    ('00000000-0000-4000-a000-000000000016'::uuid, 'driver6',   'Shahid Hussain',  'driver',   '0306-2000006')
  ) as t (id, username, full_name, role, phone)
  loop
    insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                            raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                            confirmation_token, email_change, email_change_token_new, recovery_token)
    values ('00000000-0000-0000-0000-000000000000', u.id, 'authenticated', 'authenticated',
            u.username || '@wasabhakkar.demo',
            extensions.crypt('Wasa@1234', extensions.gen_salt('bf')), now(),
            jsonb_build_object('provider', 'email', 'providers', jsonb_build_array('email'),
                               'role', u.role, 'tehsil', 'BKR', 'full_name', u.full_name,
                               'username', u.username, 'phone', u.phone),
            jsonb_build_object('full_name', u.full_name),
            now(), now(), '', '', '', '');
    insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
    values (gen_random_uuid(), u.id, u.id::text,
            jsonb_build_object('sub', u.id::text, 'email', u.username || '@wasabhakkar.demo', 'email_verified', true),
            'email', now(), now(), now());
  end loop;
end $$;

-- ---------------------------------------------------------------- drivers
insert into public.drivers (id, tehsil_id, profile_id, full_name, full_name_ur, phone, cnic, licence_no)
select d.id, t.id, d.profile_id, d.full_name, d.full_name_ur, d.phone, d.cnic, d.licence
from public.tehsils t,
  (values
    ('00000000-0000-4000-b000-000000000001'::uuid, '00000000-0000-4000-a000-000000000011'::uuid, 'Ghulam Abbas',   'غلام عباس',   '0306-2000001', '38101-1234561-1', 'BKR-HTV-1101'),
    ('00000000-0000-4000-b000-000000000002'::uuid, '00000000-0000-4000-a000-000000000012'::uuid, 'Muhammad Riaz',  'محمد ریاض',   '0306-2000002', '38101-1234562-3', 'BKR-HTV-1102'),
    ('00000000-0000-4000-b000-000000000003'::uuid, '00000000-0000-4000-a000-000000000013'::uuid, 'Allah Ditta',    'اللہ دتہ',    '0306-2000003', '38101-1234563-5', 'BKR-HTV-1103'),
    ('00000000-0000-4000-b000-000000000004'::uuid, '00000000-0000-4000-a000-000000000014'::uuid, 'Zafar Iqbal',    'ظفر اقبال',   '0306-2000004', '38101-1234564-7', 'BKR-HTV-1104'),
    ('00000000-0000-4000-b000-000000000005'::uuid, '00000000-0000-4000-a000-000000000015'::uuid, 'Nadeem Akhtar',  'ندیم اختر',   '0306-2000005', '38101-1234565-9', 'BKR-LTV-1105'),
    ('00000000-0000-4000-b000-000000000006'::uuid, '00000000-0000-4000-a000-000000000016'::uuid, 'Shahid Hussain', 'شاہد حسین',   '0306-2000006', '38101-1234566-1', 'BKR-LTV-1106')
  ) as d (id, profile_id, full_name, full_name_ur, phone, cnic, licence)
where t.code = 'BKR';

-- ---------------------------------------------------------------- vehicles (12, all 8 types)
insert into public.vehicles (tehsil_id, reg_no, vehicle_type_id, make_model, year, capacity, colour,
                             default_driver_id, tracker_device_id, status, status_reason, expected_back_on, notes)
select t.id, v.reg_no, vt.id, v.make_model, v.year, v.capacity, v.colour, v.driver_id, v.tracker,
       v.status::public.vehicle_status, v.reason,
       case when v.status = 'maintenance' then public.karachi_today() + 3 end, v.notes
from public.tehsils t
cross join (values
  ('BKR-1234', 'sucker',    'Hino 300 / Sewer Sucker',     2019, '6,000 litres',  'Blue/White', '00000000-0000-4000-b000-000000000001'::uuid, 'TRK-0001', 'available',   null,                 null),
  ('BKR-2741', 'sucker',    'Isuzu NPR / Sewer Sucker',    2021, '8,000 litres',  'Blue/White', '00000000-0000-4000-b000-000000000002'::uuid, 'TRK-0002', 'available',   null,                 null),
  ('BKR-3310', 'jetting',   'Isuzu NKR / Jetting Unit',    2020, '4,000 litres',  'Blue/White', '00000000-0000-4000-b000-000000000003'::uuid, 'TRK-0003', 'available',   null,                 null),
  ('BKR-4588', 'desilting', 'Hino / Desilting Bucket',     2018, '3 cubic metres', 'Yellow',    null,                                         null,       'available',   null,                 'Needs 2 helpers on site'),
  ('BKR-5102', 'tanker',    'Hino 500 / Water Bowser',     2017, '10,000 litres', 'Blue',       '00000000-0000-4000-b000-000000000005'::uuid, 'TRK-0005', 'available',   null,                 null),
  ('BKR-5103', 'tanker',    'Hino 500 / Water Bowser',     2017, '10,000 litres', 'Blue',       '00000000-0000-4000-b000-000000000006'::uuid, 'TRK-0006', 'available',   null,                 null),
  ('BKR-6620', 'tanker',    'Master / Water Bowser',       2015, '6,000 litres',  'Blue',       null,                                         null,       'maintenance', 'Pump seal leaking',  null),
  ('BKR-7015', 'dumper',    'Hino FM / Dumper',            2016, '10 tons',       'Yellow',     '00000000-0000-4000-b000-000000000004'::uuid, 'TRK-0008', 'available',   null,                 null),
  ('BKR-7016', 'dumper',    'Isuzu FVR / Dumper',          2019, '8 tons',        'Yellow',     null,                                         null,       'available',   null,                 null),
  ('BKR-8190', 'crane',     'Hino / 10-ton Truck Crane',   2014, '10 tons lift',  'Orange',     null,                                         null,       'available',   null,                 'Operator licence required'),
  ('BKR-9050', 'pump',      'Trailer-mounted Diesel Pump', 2022, '6 inch, 300 m³/h', 'Green',   null,                                         null,       'available',   null,                 null),
  ('BKR-9921', 'rickshaw',  'Sazgar / Loader Rickshaw',    2023, '1 ton',         'Blue',       null,                                         null,       'available',   null,                 null)
) as v (reg_no, type_code, make_model, year, capacity, colour, driver_id, tracker, status, reason, notes)
join public.vehicle_types vt on vt.code = v.type_code
where t.code = 'BKR';

insert into public.vehicle_maintenance (vehicle_id, started_on, ended_on, description, cost)
select v.id, public.karachi_today() + m.start_off, case when m.end_off is not null then public.karachi_today() + m.end_off end,
       m.descr, m.cost
from public.vehicles v
join (values
  ('BKR-6620', -1,   null, 'Pump seal leaking: sent to workshop',      null::numeric),
  ('BKR-6620', -40,  -38,  'Tyre replacement (2 rear tyres)',          38000),
  ('BKR-2741', -25,  -24,  'Vacuum pump service',                      12500),
  ('BKR-7015', -60,  -57,  'Hydraulic cylinder repair',                45000),
  ('BKR-1234', -15,  -15,  'Oil and filter change',                    6500)
) as m (reg_no, start_off, end_off, descr, cost) on m.reg_no = v.reg_no;

-- ---------------------------------------------------------------- customers (returning callers)
insert into public.customers (tehsil_id, phone, name, address, area_id)
select t.id, c.phone, c.name, c.address, a.id
from public.tehsils t
cross join (values
  ('0301-6123456', 'Muhammad Akram',   'House 12, Street 3, near Jamia Masjid',      'Al-Hadi'),
  ('0333-7012345', 'Shazia Parveen',   'Plot 45, Block B',                           'Happy Land'),
  ('0345-6789012', 'Haji Bashir Ahmad','Near the bridge, Kot Road',                  'Shaikh Rao Pull'),
  ('0300-9876543', 'Naveed Anjum',     'Street 7, opposite Govt. Girls School',      'Al-Hadi'),
  ('0312-3456789', 'Rukhsana Bibi',    'Gali 2, near the park',                      'Happy Land'),
  ('0346-1122334', 'Malik Javed',      'Malik House, Jhang Road',                    'Shaikh Rao Pull'),
  ('0302-5566778', 'Abdul Ghafoor',    'Al-Hadi Chowk, shop 4',                      'Al-Hadi'),
  ('0321-8899001', 'Sajida Khanum',    'House 88, Block C',                          'Happy Land'),
  ('0333-2233445', 'Faisal Mehmood',   'Street 1, near the water tank',              'Al-Hadi'),
  ('0300-6677889', 'Iqbal Hussain',    'Near the Pull, Darbar Road',                 'Shaikh Rao Pull'),
  ('0345-9988776', 'Nasreen Akhtar',   'Gali 6',                                     'Happy Land'),
  ('0301-4455667', 'Ch. Riaz Ahmad',   'Riaz Market, Main Bazar',                    'Al-Hadi'),
  ('0313-7788990', 'Kashif Ali',       'Behind the petrol pump',                     'Shaikh Rao Pull'),
  ('0331-2211334', 'Zubaida Begum',    'House 5, Street 9',                          'Al-Hadi'),
  ('0342-6655443', 'Anwar ul Haq',     'Corner house, Block A',                      'Happy Land')
) as c (phone, name, address, area_name)
join public.areas a on a.name_en = c.area_name and a.tehsil_id = t.id
where t.code = 'BKR';

-- ---------------------------------------------------------------- ~40 challans over the last 7 days
do $$
declare
  v_tehsil    uuid := (select id from public.tehsils where code = 'BKR');
  v_ops       uuid[] := array['00000000-0000-4000-a000-000000000002'::uuid, '00000000-0000-4000-a000-000000000003'::uuid];
  v_types     text[] := array['sucker', 'tanker', 'sucker', 'dumper', 'tanker', 'jetting', 'rickshaw',
                              'sucker', 'pump', 'tanker', 'desilting', 'crane'];
  v_channels  public.request_channel[] := array['call', 'whatsapp', 'call', 'sms', 'call', 'walk_in']::public.request_channel[];
  v_pay_ch    text[] := array['JazzCash', 'Easypaisa', 'Internet Banking', 'ATM', 'Bank Branch (PSID)'];
  -- today's challans are fixed so the vehicle board is consistent
  -- (i, type, reg_no, status, paid)
  v_today     text[][] := array[
                  ['sucker',   '',          'generated', 'n'],
                  ['crane',    '',          'generated', 'n'],
                  ['tanker',   'BKR-5103',  'assigned',  'n'],
                  ['sucker',   'BKR-2741',  'started',   'n'],
                  ['dumper',   'BKR-7015',  'reached',   'n'],
                  ['jetting',  'BKR-3310',  'done',      'n'],
                  ['tanker',   'BKR-5102',  'done',      'y'],
                  ['rickshaw', 'BKR-9921',  'done',      'y']];
  i           int;
  v_days_ago  int;
  v_cust      public.customers;
  v_type      public.vehicle_types;
  v_vehicle   public.vehicles;
  v_driver    uuid;
  v_tariff    public.tariffs;
  v_qty       numeric;
  v_status    public.challan_status;
  v_paid      boolean;
  v_created   timestamptz;
  v_t         timestamptz[];       -- assigned, started, reached, done, paid
  v_midnight  timestamptz := (public.karachi_today()::timestamp) at time zone 'Asia/Karachi';
  v_id        uuid;
  v_op        uuid;
  v_due       date;
  v_pstatus   public.payment_status;
  v_lat       double precision;
  v_lng       double precision;
  v_ch        public.challans;
  k           int;
  v_steps     public.challan_status[] := array['assigned', 'started', 'reached', 'done']::public.challan_status[];
  v_order     int[];
begin
  perform setseed(0.42);
  perform set_config('app.payment_callback', 'on', true);   -- seed only: allowed to write paid rows

  -- insert in time order so challan numbers follow the clock
  select array_agg(n order by created) into v_order from (
    select n, case when n <= 8 then v_midnight + (now() - v_midnight) * (0.15 + (8 - n) * 0.1)
                   else v_midnight - make_interval(days => ((n - 9) % 6) + 1) + interval '8 hours'
                        + make_interval(mins => (n * 37) % 540) end as created
    from generate_series(1, 40) n) p;

  foreach i in array v_order loop
    v_days_ago := case when i <= 8 then 0 else ((i - 9) % 6) + 1 end;
    select * into v_cust from public.customers order by phone offset ((i * 7) % 15) limit 1;
    v_op := v_ops[1 + (i % 2)];

    if i <= 8 then
      select * into v_type from public.vehicle_types where code = v_today[i][1];
      v_status := v_today[i][3]::public.challan_status;
      v_paid := v_today[i][4] = 'y';
      select * into v_vehicle from public.vehicles where reg_no = nullif(v_today[i][2], '');
      if i = 1 then  -- the waiting sucker request is for Happy Land
        select * into v_cust from public.customers where phone = '0333-7012345';
      end if;
      -- spread today's challans between midnight and now
      v_created := v_midnight + (now() - v_midnight) * (0.15 + (8 - i) * 0.1);
    else
      select * into v_type from public.vehicle_types where code = v_types[1 + (i % 12)];
      select * into v_vehicle from public.vehicles
        where vehicle_type_id = v_type.id and (status <> 'maintenance' or v_days_ago >= 2)
        order by reg_no offset (i % (select count(*) from public.vehicles
                                     where vehicle_type_id = v_type.id and (status <> 'maintenance' or v_days_ago >= 2)))
        limit 1;
      v_status := case when i % 11 = 0 then 'cancelled' else 'done' end;
      v_paid := v_status = 'done' and i % 4 <> 0;
      v_created := v_midnight - make_interval(days => v_days_ago) + interval '8 hours'
                   + make_interval(mins => (i * 37) % 540);
    end if;

    v_driver := coalesce(v_vehicle.default_driver_id,
                         (select id from public.drivers order by full_name offset (i % 6) limit 1));
    if v_vehicle.id is null then v_driver := null; end if;

    select * into v_tariff from public.tariffs
      where area_id = v_cust.area_id and vehicle_type_id = v_type.id and is_active;
    v_qty := case v_tariff.pricing_unit when 'per_hour' then 2 + (i % 3) when 'per_day' then 1
                                        else case when i % 9 = 0 then 2 else 1 end end;
    v_due := (v_created at time zone 'Asia/Karachi')::date + 3;

    v_t := array[v_created + interval '8 minutes', v_created + interval '25 minutes',
                 v_created + interval '55 minutes', v_created + make_interval(mins => 100 + (i * 13) % 80),
                 v_created + make_interval(hours => 3 + (i % 20))];
    for k in 1..5 loop
      v_t[k] := least(v_t[k], now() - make_interval(mins => 6 - k));
    end loop;

    v_pstatus := case when v_paid then 'paid'
                      when v_status <> 'cancelled' and v_due < public.karachi_today() then 'expired'
                      else 'unpaid' end;
    v_lat := 31.6270 + ((i * 17) % 40 - 20) / 2000.0;
    v_lng := 71.0650 + ((i * 29) % 40 - 20) / 2000.0;
    v_id := gen_random_uuid();

    insert into public.challans (
      id, tehsil_id, customer_id, customer_name, customer_phone, address, area_id, vehicle_type_id,
      vehicle_id, driver_id, quantity, pricing_unit, tariff_id, rate, amount, amount_source, request_channel,
      due_date, status, payment_status, cancel_reason, site_photo_path, site_lat, site_lng,
      created_by, created_at, updated_at, assigned_at, started_at, reached_at, done_at, paid_at, cancelled_at)
    values (
      v_id, v_tehsil, v_cust.id, v_cust.name, v_cust.phone, v_cust.address, v_cust.area_id, v_type.id,
      case when v_status = 'generated' or (v_status = 'cancelled') then null else v_vehicle.id end,
      case when v_status = 'generated' or (v_status = 'cancelled') then null else v_driver end,
      v_qty, v_tariff.pricing_unit, v_tariff.id, v_tariff.rate, v_tariff.rate * v_qty, 'tariff',
      v_channels[1 + (i % 6)], v_due, v_status, v_pstatus,
      case when v_status = 'cancelled' then 'Customer cancelled on phone' end,
      case when v_status = 'done' then v_id || '/site.jpg' end,
      case when v_status = 'done' then v_lat end,
      case when v_status = 'done' then v_lng end,
      v_op, v_created, v_created,
      case when v_status not in ('generated', 'cancelled') then v_t[1] end,
      case when v_status in ('started', 'reached', 'done') then v_t[2] end,
      case when v_status in ('reached', 'done') then v_t[3] end,
      case when v_status = 'done' then v_t[4] end,
      case when v_paid then v_t[5] end,
      case when v_status = 'cancelled' then v_created + interval '20 minutes' end)
    returning * into v_ch;

    -- timeline
    insert into public.challan_events (challan_id, actor_id, actor_role, event_type, to_status, note, created_at)
    values (v_id, v_op, 'operator', 'created', 'generated', 'Request by ' || v_ch.request_channel, v_created);

    if v_status = 'cancelled' then
      insert into public.challan_events (challan_id, actor_id, actor_role, event_type, from_status, to_status, note, created_at)
      values (v_id, v_op, 'operator', 'cancelled', 'generated', 'cancelled', v_ch.cancel_reason, v_ch.cancelled_at);
    elsif v_status <> 'generated' then
      insert into public.challan_events (challan_id, actor_id, actor_role, event_type, from_status, to_status, note, created_at)
      values (v_id, v_op, 'operator', 'assigned', 'generated', 'assigned', v_vehicle.reg_no, v_t[1]);
      for k in 2..4 loop
        exit when array_position(v_steps, v_status) < k;
        insert into public.challan_events (challan_id, actor_id, actor_role, event_type, from_status, to_status,
                                           lat, lng, created_at)
        values (v_id, (select profile_id from public.drivers where id = v_driver), 'driver', 'status',
                v_steps[k - 1]::text, v_steps[k]::text, v_lat + 0.0003 * k, v_lng - 0.0002 * k, v_t[k]);
      end loop;
    end if;

    if v_paid then
      insert into public.payments (challan_id, provider, transaction_id, amount, channel, status, paid_at, raw)
      values (v_id, 'mock', 'MOCK-' || upper(substr(md5(v_id::text), 1, 12)), v_ch.amount,
              v_pay_ch[1 + (i % 5)], 'success', v_t[5], jsonb_build_object('seed', true));
      insert into public.challan_events (challan_id, actor_role, event_type, from_status, to_status, note, created_at)
      values (v_id, null, 'payment', 'unpaid', 'paid', 'Paid via ' || v_pay_ch[1 + (i % 5)], v_t[5]);
    elsif v_pstatus = 'expired' then
      insert into public.challan_events (challan_id, event_type, from_status, to_status, note, created_at)
      values (v_id, 'expired', 'unpaid', 'expired', 'Unpaid after due date', (v_due + 1)::timestamp at time zone 'Asia/Karachi');
    end if;
  end loop;

  -- vehicles on an active job are On Job
  update public.vehicles v set status = 'on_job'
  where exists (select 1 from public.challans c where c.vehicle_id = v.id and c.status in ('assigned', 'started', 'reached'));
end $$;

-- ---------------------------------------------------------------- last known driver positions (map placeholder)
insert into public.driver_locations (driver_id, lat, lng, accuracy, recorded_at)
select d.id, 31.6270 + (row_number() over (order by d.full_name) - 3) * 0.004,
       71.0650 + (row_number() over (order by d.full_name) % 3 - 1) * 0.005, 15, now() - interval '10 minutes'
from public.drivers d;
