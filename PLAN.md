# WASA Bhakkar: Vehicle Service Challan & Payment System (Demo)

This file covers the folder structure, the database design and the build phases.
Smaller choices are recorded in `DECISIONS.md`.

## 1. Folder structure

```
gct/
├── pubspec.yaml                 # Dart pub workspace (one `flutter pub get` for everything)
├── apps/
│   ├── office/                  # Flutter Windows desktop + Web: Admin, Operator, Officer (read-only)
│   │   └── lib/
│   │       ├── main.dart
│   │       ├── router.dart      # go_router + role-based redirects
│   │       ├── shell/           # nav rail + top bar
│   │       └── features/        # login, dashboard, vehicles, challans, new_challan,
│   │                            # masters, reports, map, audit, payment_simulator
│   └── driver/                  # Flutter Android app (Urdu-first)
│       └── lib/
│           ├── main.dart
│           ├── router.dart
│           └── features/        # login, jobs, job, qr, scan
├── packages/
│   ├── core/                    # pure Dart + Supabase: models, repositories, services, rules
│   │   └── lib/src/
│   │       ├── models/          # enums, Profile, Vehicle, Challan, Tariff, ...
│   │       ├── rules/           # tariff calc, status machine, numbering, QR codec/signing
│   │       ├── repositories/    # Supabase data access (RPC + select only)
│   │       ├── services/        # PaymentProvider, TrackerProvider, PdfService, ShareService
│   │       └── format/          # PKR, DD-MM-YYYY, Asia/Karachi, phone 03XX-XXXXXXX
│   └── ui/                      # theme, colours, shared widgets (VehicleCard, StatusChip,
│       ├── assets/vehicles/     #   BigTile, Loading/Empty/Error views), SVG vehicle drawings
│       └── fonts/               # Noto Naskh Arabic (Urdu UI + PDF)
├── supabase/
│   ├── config.toml
│   ├── migrations/              # schema, functions, RLS, storage, realtime
│   ├── seed.sql                 # demo data (users, vehicles, tariff, ~40 challans)
│   ├── functions/               # Edge Functions: payment-callback (mock bank), admin-users
│   └── tests/                   # local Supabase stand-in + SQL tests for RLS and rules
├── tool/                        # db_test.sh (runs migrations + seed + SQL tests on local Postgres)
├── README.md  DECISIONS.md  INTEGRATION.md  DEMO_SCRIPT.md  PLAN.md
```

## 2. Database

### Enums
| Enum | Values |
|---|---|
| `user_role` | admin, operator, driver, officer |
| `vehicle_category` | sewer, water, heavy_utility, small_utility |
| `pricing_unit` | per_trip, per_hour, per_day |
| `payment_policy` | pay_after_service, pay_before_dispatch |
| `vehicle_status` | available, on_job, maintenance |
| `challan_status` (the work) | generated, assigned, started, reached, done, cancelled |
| `payment_status` (the money) | unpaid, paid, expired |
| `request_channel` | call, sms, whatsapp, walk_in |
| `amount_source` | tariff, manual |

The spec's single flow `Generated → … → Done → Paid` is kept as **two columns**:
the work status and the payment status. That way "Pay before dispatch" works
(a challan can be Paid while still Generated). The screens show one combined
label, `display_status`: Cancelled, Expired, Paid (when work is Done and paid),
otherwise the work status.

### Tables (all in `public` unless noted)
| Table | Key columns |
|---|---|
| `tehsils` | code (BKR), name_en/ur, psid_code, is_active |
| `profiles` | id = auth.users.id, full_name, username, phone, role, tehsil_id, is_active |
| `drivers` | tehsil_id, profile_id (app login), full_name/ur, phone, cnic, licence_no, is_active |
| `vehicle_types` | code, name_en/ur, category, pricing_unit, payment_policy, icon_key, sort_order, is_active |
| `vehicles` | tehsil_id, reg_no, vehicle_type_id, make_model, year, capacity, colour, default_driver_id, tracker_device_id, notes, status, status_reason, expected_back_on, is_active |
| `vehicle_photos` | vehicle_id, storage_path, position 0–3 (0 = main), kind (front/side/back/equipment) |
| `vehicle_maintenance` | vehicle_id, started_on, ended_on, description, cost |
| `areas` | tehsil_id, name_en/ur, sort_order, is_active |
| `tariffs` | area_id, vehicle_type_id, rate, pricing_unit, effective_from, is_active, is_placeholder (one active row per area × type; old rows kept as history) |
| `customers` | tehsil_id, phone (unique per tehsil), name, address, area_id |
| `challans` | challan_no, payment_ref (18 digits), customer fields, area, vehicle type, vehicle, driver, quantity, tariff_id, rate, amount, amount_source, override_reason, request_channel, due_date, status, payment_status, display_status, qr_signature, cancel_reason, site photo + GPS, timestamps, created_by |
| `challan_events` | challan_id, actor_id, actor_role, event_type, from_status → to_status, lat/lng, note |
| `payments` | challan_id, provider, transaction_id, amount, channel, status, paid_at, raw |
| `driver_locations` | driver_id (last position), lat, lng, accuracy, recorded_at |
| `settings` | key → value (jsonb): due_days, org names, helpline |
| `audit_log` | actor_id, table_name, record_id, action, old_data, new_data |
| `challan_counters` | tehsil_id, year, last_seq (numbering) |
| `private.app_secrets` | the QR HMAC key (not reachable through the API) |

### Rules in the database
- **Numbering:** `WASA-<tehsil>-<YYYY>-<000001>`, from an atomic per-tehsil per-year counter (Karachi time).
- **Payment reference:** `40` + tehsil psid_code (2) + year (4) + sequence (6) + 4 random digits = 18 digits.
- **QR:** `WASA1|<challan_no>|<payment_ref>|<amount>|<sig>`. `sig` = the first 32 hex characters of HMAC-SHA256(`no|ref|amount`) with the server-only key. `verify_challan_qr()` returns Genuine / Not genuine and the payment status.
- **No cash:** nobody has INSERT/UPDATE on `challans` or `payments`. All changes go through RPCs. A guard trigger also rejects any payment-status change unless it comes from the payment-callback function.
- **Pay before dispatch:** `assign_challan()` refuses unless the challan is Paid when the vehicle type's policy is pay-before.
- **Vehicle status:** On Job when a challan is assigned, Available again on Done or Cancel; Maintenance only through `set_vehicle_status()` (needs a reason).
- **Audit:** triggers write every insert/update/delete on business tables to `audit_log`.

### Row Level Security (on every table)
Helper functions: `app_role()`, `app_tehsil_id()`, `app_is_admin()`, `app_is_staff()`, `app_driver_id()`.

| Table | SELECT | INSERT/UPDATE/DELETE |
|---|---|---|
| tehsils, vehicle_types, settings | any signed-in user | admin |
| areas, tariffs | admin; others in their own tehsil | admin |
| vehicles, vehicle_photos, vehicle_maintenance, drivers | admin; others in their own tehsil | admin (operators change vehicle status through an RPC) |
| profiles | self; admin; staff in the same tehsil | admin |
| customers | admin; operator/officer in their own tehsil | via RPC only |
| challans | admin; operator/officer in their own tehsil; driver: only challans assigned to him | via RPC only |
| challan_events, payments | if the user can see the challan | via RPC only |
| driver_locations | admin; staff in the same tehsil | the driver, own row only |
| audit_log | admin | triggers only |
| challan_counters, private.* | nobody | functions only |

Storage: the `vehicle-photos` bucket (public read, admin write) and the `site-photos` bucket (private; a driver can upload only under a challan assigned to him; staff in the tehsil can read).

## 3. Phases (each is checked before the next starts)
1. **Scaffold:** monorepo, theme, Supabase schema + RLS + seed, auth with role-based routing.
   *Check:* migrations + seed + RLS tests pass on Postgres; `flutter analyze` and `flutter test` pass; office web build succeeds.
2. **Vehicles and masters:** vehicle types, vehicles with photos (Storage), Vehicle Board + VehicleCard, drivers, areas, tariff grid.
3. **Challan:** the 3-tap flow, numbering, QR/HMAC, PDF, WhatsApp share.
4. **Driver app:** jobs, Start/Reached/Done, photo + GPS, realtime, QR verify.
5. **Payment:** mock provider, Payment Simulator, no-cash enforcement, pay-before-dispatch rule.
6. **Office views:** dashboard, reports, exports, audit log, map placeholder.
7. **Polish:** Urdu labels, tests, README, DEMO_SCRIPT.md, DECISIONS.md, INTEGRATION.md.
