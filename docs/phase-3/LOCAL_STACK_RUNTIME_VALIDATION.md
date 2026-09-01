# Local stack runtime validation

Validation date: 2026-08-30
Device: Android Emulator `sdk_gphone64_arm64`, Android 16, API 36
Mobile environment: `development`
Backend: Go staging vertical-slice server on `127.0.0.1:18080`
Admin: Vite UI on `127.0.0.1:4173` with its documented fixture API on `127.0.0.1:4174`

## Outcome

The local Android integration slice is operational for the Customer, Vendor, and Rider applications. It is not evidence that the product is 100% production-ready: the run used the in-memory staging slice and development identities, while real payment, identity, onboarding, notification, telemetry, persistent infrastructure, iOS runtime, and physical-device background-location integrations still require production-like validation.

## Runtime evidence

| Surface | Result | Journeys exercised |
| --- | --- | --- |
| Backend | Pass for local slice | Health checks and `login -> location -> home -> catalog` staging smoke passed. Customer consent, cart, checkout quote, order creation, vendor supply, and rider fulfillment endpoints were exercised by the apps. |
| Admin | Pass for documented local fixture | Workspace/country context, role capabilities, Operations register, and Audit log rendered. Browser console had no warnings or errors. |
| Customer | Pass with provider limitation | Development sign-in, consent, manual Chennai `600001` location, home/catalog, add to cart, cart total, delivery quote, and order creation completed. Order creation returned HTTP 201. The app then displayed its recoverable payment-setup state because no real Razorpay configuration was supplied. |
| Vendor | Pass for local onboarding/operations | Development sign-in, initial onboarding, API-driven document/KYC/field/zone/bank approval, approved dashboard, catalogue, and empty orders state were exercised. |
| Rider | Pass for local duty/operations | Development sign-in, API-driven onboarding approval, Android location permission, duty start, active tracking state, offers/tasks, earnings/payouts, and duty end were exercised. |

Each mobile role used its own Android application package:

- `net.planext4u.customer.dev`
- `net.planext4u.vendor.dev`
- `net.planext4u.rider.dev`

## Defects found and corrected during runtime validation

1. Customer first-run consent failed because the local staging slice did not expose the consent evidence endpoints. The missing subject-scoped GET/PUT implementation and its journey test were added to the backend.
2. Checkout initialization synchronously notified a controller during a parent build, causing Flutter's `setState() or markNeedsBuild() called during build` failure. Checkout loading is now deferred until the first frame.
3. Empty checkout warnings and Vendor/Rider aggregate collections serialized as JSON `null`, while the generated mobile contract requires arrays. The backend now returns `[]`, with regression assertions.

## Automated gates rerun after the fixes

- Backend: `go test ./...` — passed.
- Admin: `npm test` — 29 tests passed; `npm run build` — passed.
- Mobile: `dart run melos run verify` — contract/token generation checks, format, 3 apps x 3 Android/iOS flavor validation, Phase 2/3 controls, security audit, CI validation, analysis of 11 packages, and all Flutter tests passed.
- Backend and mobile `git diff --check` — passed.

## Work still required before a production-ready claim

- Run the persistent production-like backend topology (database, cache, object storage, queues, and telemetry collector) instead of the in-memory staging slice. Docker was unavailable during this validation.
- Connect the Admin UI to the production Admin BFF; this local Admin run intentionally used its repository fixture API.
- Validate real Firebase/OTP and OAuth configuration for all roles.
- Validate Razorpay/payment webhooks, reconciliation, refunds, and COD policy against sandbox/production-like providers.
- Validate Vendor OCR/KYC/bank verification and Rider onboarding providers without privileged local seeding.
- Validate push delivery, deep links, background execution, and Rider background GPS on physical Android devices.
- Run the same role journeys on an iOS simulator and representative physical iOS devices.
- Execute release-candidate performance, security, accessibility, store-signing, migration, rollback, and observability drills in a production-like environment.
