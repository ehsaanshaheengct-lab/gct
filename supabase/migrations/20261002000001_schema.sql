-- WASA Bhakkar Vehicle Service Challan & Payment System
-- 01: extensions, enums and tables

create extension if not exists pgcrypto with schema extensions;

create schema if not exists private;
revoke all on schema private from public;

-- ---------------------------------------------------------------- enums
create type public.user_role        as enum ('admin', 'operator', 'driver', 'officer');
create type public.vehicle_category as enum ('sewer', 'water', 'heavy_utility', 'small_utility');
create type public.pricing_unit     as enum ('per_trip', 'per_hour', 'per_day');
create type public.payment_policy   as enum ('pay_after_service', 'pay_before_dispatch');
create type public.vehicle_status   as enum ('available', 'on_job', 'maintenance');
create type public.challan_status   as enum ('generated', 'assigned', 'started', 'reached', 'done', 'cancelled');
create type public.payment_status   as enum ('unpaid', 'paid', 'expired');
create type public.request_channel  as enum ('call', 'sms', 'whatsapp', 'walk_in');
create type public.amount_source    as enum ('tariff', 'manual');

-- ---------------------------------------------------------------- tehsils & people
create table public.tehsils (
  id          uuid primary key default gen_random_uuid(),
  code        text not null unique check (code ~ '^[A-Z]{2,5}$'),
  name_en     text not null,
  name_ur     text not null,
  psid_code   smallint not null unique check (psid_code between 10 and 99),
  is_active   boolean not null default false,
  sort_order  int not null default 0,
  created_at  timestamptz not null default now()
);

create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  full_name   text not null,
  username    text unique,
  phone       text,
  role        public.user_role not null,
  tehsil_id   uuid not null references public.tehsils (id),
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table public.drivers (
  id            uuid primary key default gen_random_uuid(),
  tehsil_id     uuid not null references public.tehsils (id),
  profile_id    uuid unique references public.profiles (id) on delete set null,
  full_name     text not null,
  full_name_ur  text,
  phone         text not null check (phone ~ '^03[0-9]{2}-[0-9]{7}$'),
  cnic          text check (cnic ~ '^[0-9]{5}-[0-9]{7}-[0-9]$'),
  licence_no    text,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- ---------------------------------------------------------------- vehicles
create table public.vehicle_types (
  id              uuid primary key default gen_random_uuid(),
  code            text not null unique check (code ~ '^[a-z_]+$'),
  name_en         text not null,
  name_ur         text not null,
  category        public.vehicle_category not null,
  pricing_unit    public.pricing_unit not null default 'per_trip',
  payment_policy  public.payment_policy not null default 'pay_after_service',
  icon_key        text not null,            -- packages/ui/assets/vehicles/<icon_key>.svg
  sort_order      int not null default 0,
  is_active       boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create table public.vehicles (
  id                 uuid primary key default gen_random_uuid(),
  tehsil_id          uuid not null references public.tehsils (id),
  reg_no             text not null unique,
  vehicle_type_id    uuid not null references public.vehicle_types (id),
  make_model         text,
  year               int check (year between 1970 and 2100),
  capacity           text,                  -- free text: '5,000 litres', '10 tons', '6 inch'
  colour             text,
  default_driver_id  uuid references public.drivers (id) on delete set null,
  tracker_device_id  text,
  notes              text,
  status             public.vehicle_status not null default 'available',
  status_reason      text,
  expected_back_on   date,
  is_active          boolean not null default true,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  constraint maintenance_needs_reason
    check (status <> 'maintenance' or coalesce(trim(status_reason), '') <> '')
);
create index on public.vehicles (tehsil_id, status);
create index on public.vehicles (vehicle_type_id);

create table public.vehicle_photos (
  id            uuid primary key default gen_random_uuid(),
  vehicle_id    uuid not null references public.vehicles (id) on delete cascade,
  storage_path  text not null,
  position      smallint not null check (position between 0 and 3),
  kind          text not null default 'front' check (kind in ('front', 'side', 'back', 'equipment')),
  created_at    timestamptz not null default now(),
  unique (vehicle_id, position) deferrable initially deferred
);

create table public.vehicle_maintenance (
  id           uuid primary key default gen_random_uuid(),
  vehicle_id   uuid not null references public.vehicles (id) on delete cascade,
  started_on   date not null default (now() at time zone 'Asia/Karachi')::date,
  ended_on     date,
  description  text not null,
  cost         numeric(12, 2) check (cost >= 0),
  created_by   uuid references public.profiles (id),
  created_at   timestamptz not null default now()
);
create index on public.vehicle_maintenance (vehicle_id);

-- ---------------------------------------------------------------- areas & tariff
create table public.areas (
  id          uuid primary key default gen_random_uuid(),
  tehsil_id   uuid not null references public.tehsils (id),
  name_en     text not null,
  name_ur     text not null,
  sort_order  int not null default 0,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  unique (tehsil_id, name_en)
);

create table public.tariffs (
  id               uuid primary key default gen_random_uuid(),
  area_id          uuid not null references public.areas (id),
  vehicle_type_id  uuid not null references public.vehicle_types (id),
  rate             numeric(12, 2) not null check (rate >= 0),
  pricing_unit     public.pricing_unit not null,
  effective_from   date not null default (now() at time zone 'Asia/Karachi')::date,
  is_active        boolean not null default true,
  is_placeholder   boolean not null default false,
  created_by       uuid references public.profiles (id),
  created_at       timestamptz not null default now()
);
-- exactly one active rate per area x vehicle type; old rows stay as history
create unique index tariffs_one_active on public.tariffs (area_id, vehicle_type_id) where is_active;

-- ---------------------------------------------------------------- customers & challans
create table public.customers (
  id          uuid primary key default gen_random_uuid(),
  tehsil_id   uuid not null references public.tehsils (id),
  phone       text not null check (phone ~ '^03[0-9]{2}-[0-9]{7}$'),
  name        text not null,
  address     text,
  area_id     uuid references public.areas (id),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (tehsil_id, phone)
);

create table public.challan_counters (
  tehsil_id  uuid not null references public.tehsils (id),
  year       int not null,
  last_seq   int not null default 0,
  primary key (tehsil_id, year)
);

create table public.challans (
  id               uuid primary key default gen_random_uuid(),
  tehsil_id        uuid not null references public.tehsils (id),
  challan_no       text not null unique,
  payment_ref      text not null unique check (payment_ref ~ '^[0-9]{18}$'),
  customer_id      uuid references public.customers (id),
  customer_name    text not null,
  customer_phone   text not null check (customer_phone ~ '^03[0-9]{2}-[0-9]{7}$'),
  address          text,
  area_id          uuid not null references public.areas (id),
  vehicle_type_id  uuid not null references public.vehicle_types (id),
  vehicle_id       uuid references public.vehicles (id),
  driver_id        uuid references public.drivers (id),
  quantity         numeric(8, 2) not null default 1 check (quantity > 0),
  pricing_unit     public.pricing_unit not null,
  tariff_id        uuid references public.tariffs (id),
  rate             numeric(12, 2) not null check (rate >= 0),
  amount           numeric(12, 2) not null check (amount >= 0),
  amount_source    public.amount_source not null default 'tariff',
  override_reason  text,
  request_channel  public.request_channel not null default 'call',
  due_date         date not null,
  status           public.challan_status not null default 'generated',
  payment_status   public.payment_status not null default 'unpaid',
  display_status   text generated always as (
    case
      when status = 'cancelled' then 'cancelled'
      when payment_status = 'paid' and status = 'done' then 'paid'
      when payment_status = 'expired' then 'expired'
      when status = 'generated' then 'generated'
      when status = 'assigned' then 'assigned'
      when status = 'started' then 'started'
      when status = 'reached' then 'reached'
      else 'done'
    end) stored,
  qr_signature     text not null,
  cancel_reason    text,
  notes            text,
  site_photo_path  text,
  site_lat         double precision,
  site_lng         double precision,
  created_by       uuid references public.profiles (id),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  assigned_at      timestamptz,
  started_at       timestamptz,
  reached_at       timestamptz,
  done_at          timestamptz,
  paid_at          timestamptz,
  cancelled_at     timestamptz,
  constraint manual_amount_needs_reason
    check (amount_source = 'tariff' or coalesce(trim(override_reason), '') <> ''),
  constraint cancel_needs_reason
    check (status <> 'cancelled' or coalesce(trim(cancel_reason), '') <> ''),
  constraint done_needs_photo
    check (status <> 'done' or site_photo_path is not null)
);
create index on public.challans (tehsil_id, created_at desc);
create index on public.challans (driver_id, status);
create index on public.challans (vehicle_id);
create index on public.challans (customer_phone);
create index on public.challans (status, payment_status);

create table public.challan_events (
  id           bigint generated always as identity primary key,
  challan_id   uuid not null references public.challans (id) on delete cascade,
  actor_id     uuid references public.profiles (id),
  actor_role   public.user_role,
  event_type   text not null check (event_type in
                 ('created', 'status', 'assigned', 'payment', 'cancelled', 'expired', 'amount_override', 'shared', 'printed')),
  from_status  text,
  to_status    text,
  lat          double precision,
  lng          double precision,
  note         text,
  created_at   timestamptz not null default now()
);
create index on public.challan_events (challan_id, created_at);

create table public.payments (
  id              uuid primary key default gen_random_uuid(),
  challan_id      uuid not null references public.challans (id),
  provider        text not null,              -- 'mock', '1bill', 'epay_punjab', ...
  transaction_id  text not null unique,
  amount          numeric(12, 2) not null check (amount >= 0),
  channel         text,                       -- 'mobile_wallet', 'internet_banking', 'atm', ...
  status          text not null check (status in ('success', 'failed')),
  paid_at         timestamptz not null default now(),
  raw             jsonb,
  created_at      timestamptz not null default now()
);
create index on public.payments (challan_id);

-- ---------------------------------------------------------------- misc
create table public.driver_locations (
  driver_id    uuid primary key references public.drivers (id) on delete cascade,
  lat          double precision not null,
  lng          double precision not null,
  accuracy     double precision,
  recorded_at  timestamptz not null default now()
);

create table public.settings (
  key         text primary key,
  value       jsonb not null,
  updated_at  timestamptz not null default now()
);

create table public.audit_log (
  id          bigint generated always as identity primary key,
  actor_id    uuid,
  table_name  text not null,
  record_id   text,
  action      text not null,                  -- INSERT / UPDATE / DELETE / RPC name
  old_data    jsonb,
  new_data    jsonb,
  created_at  timestamptz not null default now()
);
create index on public.audit_log (created_at desc);
create index on public.audit_log (table_name, record_id);

create table private.app_secrets (
  key    text primary key,
  value  text not null
);
insert into private.app_secrets (key, value)
values ('qr_hmac_key', encode(extensions.gen_random_bytes(32), 'hex'));
