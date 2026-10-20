# Decisions

Choices made while building, so they can be reviewed or reversed later.

## Data model
1. **Two status columns instead of one.** `status` tracks the work (Generated → Assigned → Started → Reached → Done, or Cancelled) and `payment_status` tracks the money (Unpaid / Paid / Expired). With one column, "Pay before dispatch" would be impossible (a challan must be Paid *before* it is Assigned) and a Done challan would lose its "Paid" flag. Lists show one label, `display_status`: Paid (Done + paid), Expired, Cancelled, or the work status.
2. **Expired** = unpaid after the due date. It is a payment state: the job may still be done, and a late payment is still accepted (it is logged with its date). Cancelled challans never expire.
3. **Paid challans cannot be cancelled.** Refunds are outside this system.
4. **Amounts are frozen.** After creation, the challan number, reference, rate, quantity and amount cannot be changed, even by Admin. To fix a mistake, cancel the challan (with a reason) and issue a new one. This keeps the QR signature valid.
5. **Tariff history:** editing a rate deactivates the old row and inserts a new one, so there is exactly one active rate per area × vehicle type. Each challan stores `tariff_id`, `rate` and `pricing_unit` as used. Trips are whole numbers; hours and days go in steps of 0.5. The amount is rate × quantity.
6. **Payment reference (simulated PSID):** `40` + tehsil code (2 digits) + year + 6-digit sequence + 4 random digits = 18 digits. It is unique because the sequence is.
7. **QR signature:** the first 32 hex characters (128 bits) of HMAC-SHA256 over `challan_no|payment_ref|amount`, with a random key created in the migration and stored in `private.app_secrets`. That schema is not exposed through the API. The short signature keeps the QR small enough to scan off a cheap printout.
8. **Drivers vs users:** `drivers` is its own table linked to a login (`profile_id`), so a driver can exist before (or without) an app account.
9. **Settings are global** (one row per key). Per-tehsil overrides can be added later without changing the apps.

## Security
10. **No direct writes to challans or payments, for any role.** The API roles have SELECT only. All changes go through security-definer RPCs, which check the role, the tehsil and the status rules. A trigger also blocks any change to Paid unless it comes from the payment callback (a transaction-local `app.payment_callback` flag set only inside that function). This holds even for the table owner.
11. **Role and tehsil come from `raw_app_meta_data`**, which only the service key can set, and never from user-editable metadata. Public sign-up is disabled: Admin creates accounts.
12. **Usernames instead of e-mails:** staff type `operator1`; the apps add `@wasabhakkar.demo` (configurable with `LOGIN_DOMAIN`).
13. **Officer** is read-only for everything in their tehsil. **Drivers** see only challans assigned to them and no customer list.
14. **Storage:** `vehicle-photos` is a public-read bucket, because photos appear on printed challans and WhatsApp shares. `site-photos` is private.
15. Apps use the Supabase **publishable key** (the legacy anon key also works). No service key is ever in an app.

## Demo choices
16. **Truck Crane is seeded as "Pay before dispatch"** so the rule can be shown. Every other type is "Pay after service".
17. **Shaikh Rao Pull rates are base + 20%** (placeholder for distance). All seeded rates are marked `is_placeholder`.
18. **Demo password** for every seeded account is `Wasa@1234`. Change it before any real use.
19. The seed numbers challans in time order. Today's challans are spread between midnight and the time the seed runs.

## Tech
20. **Dart pub workspace:** one `flutter pub get` at the root resolves all four packages.
21. **Riverpod 3 + go_router 18.** Routing decisions are pure functions (`officeRedirect`, `driverRedirect`), so they are unit-tested without a server.
22. **Urdu font:** Noto Naskh Arabic is bundled (packages/ui/fonts) as a fallback font. Latin text uses the platform font and Urdu glyphs use Naskh. Naskh was chosen over Nastaliq because it is clearer at small sizes, works on low-end phones, and works in the `pdf` package.
23. **`flutter_svg` added** (not in the original list) to draw the vehicle illustrations and the logo placeholder.
24. Office app defaults to English, driver app to Urdu. The choice is remembered on the device.
25. **Testing without Docker:** this build environment could not pull Supabase images, so `tool/db_test.sh` runs the real migrations and seed on plain PostgreSQL, with a small stand-in for the Supabase `auth`/`storage` schemas (`supabase/tests/shim.sql`).

## Phase 2: vehicles and masters
26. **Vehicle status:** On Job is never set by hand; it follows challans (Phase 3). Operators and Admin switch between Available and Maintenance with `set_vehicle_status()`. Maintenance needs a reason, and an optional expected-back date that is not in the past. A vehicle on an active challan cannot be switched. Going into Maintenance opens a maintenance log entry; coming back closes it. "Days in maintenance" is counted from these entries.
27. **Photos:** up to 4 per vehicle, max 8 MB, JPG/PNG/WebP. Positions are kept as 0..n-1, the first is the main photo, and deleting a photo closes the gap. Admin sets each photo's kind (front/side/back/equipment) and drags to reorder. Without a photo, the type's drawing is shown.
28. **Tariff edits** go through `set_tariff_rate()`: the new rate becomes active at once and the old row is kept, inactive. "Effective from" is recorded for the records; future-dated rates are not scheduled automatically.
29. **Masters are deactivated, not deleted** (no delete buttons), so old challans and history keep their references. A new vehicle type shows "not set" in the tariff grid until Admin enters its rates.
30. **Linking a driver to an app login** is done on the Users screen (Phase 6/7), which needs the Admin Edge Function. Seeded drivers are already linked.
31. **Board layout:** cards size to their content in equal-width columns, so different fonts (Windows, Urdu) never cut text. Latin text inside Urdu lines, and Urdu inside English lines, is direction-isolated so numbers and brackets render correctly.
32. **Local Supabase-lite** (`tool/local_supabase/`) runs the real Supabase Auth and PostgREST binaries without Docker, for end-to-end tests here. It has no Realtime; the apps still work and only lose live auto-refresh.
33. The Supabase Dart client sorts **descending** by default, so every `.order()` call states `ascending:` explicitly.
