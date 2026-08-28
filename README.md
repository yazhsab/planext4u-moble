# Planext4u Mobile

Greenfield Flutter workspace for the Planext4u customer, vendor, and rider applications.

This repository is intentionally independent of the Lovable/Vercel proof-of-concept. No source code, generated code, dependencies, or assets will be copied from the legacy repository. The live application may be used only as a black-box behavioural and visual reference after access is authorised.

## Planned applications

- `apps/customer` - marketplace, services, food, Homes, classifieds, Socio, wallet, emergency assistance, and account features.
- `apps/vendor` - onboarding, KYC, catalog, service schedules, orders, inventory, promotions, analytics, settlements, and support.
- `apps/rider` - onboarding, availability, assignments, maps, delivery/service lifecycle, proof of delivery, attendance, and earnings.
- Shared packages - design system, API contracts, authentication, secure storage, media, maps, observability, localisation, and testing.

The administrator console is planned as a separately deployable web workspace under `planext4u-backend/admin-web` so the requested two-repository boundary is preserved. It can be extracted to a dedicated repository later without changing its API contracts.

## Current status

Phase 1 product archaeology, Phase 2 platform engineering and Phase 3 customer
commerce are complete. Phase 4 implementation has started with the customer
service-booking entry slice. The Phase 3 customer-commerce source covers FTUX and
location, discovery, PDP/reviews/Q&A, server-authoritative cart and checkout,
native Razorpay/Paystack/COD handoff and recovery, orders/returns/ratings,
wallet/referrals/refills/rewards, and FCM device registration/deep links against
backend commit `e78941b`. Service discovery, live slot holds, booking payment,
rescheduling, cancellation, start OTP, completion evidence, disputes and booking
activity are pinned to backend commit
`bf0b8b1cf01e559dccca030e237459e882dc0331`. Cloud staging and live provider
credentials remain controlled deployment gates, not client-side configuration.

The workspace contains the three role-specific Flutter applications and shared
configuration, core, identity, secure storage, experience, API, observability
and design-system packages. It remains greenfield and does not import the
Lovable proof-of-concept source.

## Local development

Prerequisites: Flutter 3.41.4 or newer on the stable channel and Dart 3.11.1 or
newer. The iOS deployment target is 15.0 because the Phase 3 Firebase and
Paystack native SDKs require it.

```sh
dart pub get
dart run melos bootstrap
dart run melos run verify
```

Run an application from its directory. Typed compile-time configuration defaults
to a local development API and rejects insecure HTTP URLs outside development.
The native flavor and public `APP_ENV` must match.

```sh
cd apps/customer
flutter run \
  --flavor development \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=http://localhost:8080
```

Use `apps/vendor` or `apps/rider` for the other role-specific applications.
See the [flavor and identity matrix](docs/phase-2/FLAVOR_MATRIX.md) for all
development, staging and production identifiers, links and build commands.

- [Six-phase delivery plan](docs/PROGRAM_PLAN.md)
- [Phase 1 discovery status](docs/phase-1/DISCOVERY_STATUS.md)
- [Requirements traceability](docs/phase-1/REQUIREMENTS_TRACEABILITY.md)
- [Screen and flow inventory](docs/phase-1/SCREEN_AND_FLOW_INVENTORY.md)
- [Role and permission matrix](docs/phase-1/ROLE_PERMISSION_MATRIX.md)
- [POC audit runbook](docs/phase-1/POC_AUDIT_RUNBOOK.md)
- [Authenticated POC findings](docs/phase-1/AUTHENTICATED_POC_FINDINGS.md)
- [Golden screen specifications](docs/phase-1/GOLDEN_SCREEN_SPECIFICATIONS.md)
- [Test strategy](docs/phase-1/TEST_STRATEGY.md)
- [Deferred validation register](docs/phase-1/DEFERRED_VALIDATION_REGISTER.md)
- [Phase 2 executable backlog](docs/phase-1/PHASE_2_BACKLOG.md)
- [Phase 1 exit review](docs/phase-1/PHASE_1_EXIT_REVIEW.md)
- [Phase 3 exit review](docs/phase-3/PHASE_3_EXIT_REVIEW.md)
- [Phase 4 executable backlog](docs/phase-4/PHASE_4_BACKLOG.md)
- [Phase 4 service-booking entry slice](docs/phase-4/SERVICE_BOOKING_ENTRY_SLICE.md)
- [Decision log](docs/phase-1/DECISION_LOG.md)
- [Feature catalogue](docs/FEATURE_CATALOGUE.md)
- [Design-system baseline](docs/DESIGN_SYSTEM_BASELINE.md)
- [Greenfield boundary ADR](docs/adr/0001-greenfield-boundary.md)
- [Backend platform](https://github.com/yazhsab/planext4u-backend)
