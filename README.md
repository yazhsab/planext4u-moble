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

Phase 1 product archaeology and target definition is complete. The approved Phase 2 backlog establishes the Flutter foundation and first staging vertical slice.

Phase 2 implementation has started with one Dart workspace containing the three
role-specific Flutter applications and shared configuration, core, and design
system packages. The foundation is intentionally greenfield and does not import
the Lovable proof-of-concept source.

## Local development

Prerequisites: Flutter 3.41.4 or newer on the stable channel and Dart 3.11.1 or
newer.

```sh
dart pub get
dart run melos bootstrap
dart run melos run verify
```

Run an application from its directory. Typed compile-time configuration defaults
to a local development API and rejects insecure HTTP URLs outside development.

```sh
cd apps/customer
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=http://localhost:8080
```

Use `apps/vendor` or `apps/rider` for the other role-specific applications.

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
- [Decision log](docs/phase-1/DECISION_LOG.md)
- [Feature catalogue](docs/FEATURE_CATALOGUE.md)
- [Design-system baseline](docs/DESIGN_SYSTEM_BASELINE.md)
- [Greenfield boundary ADR](docs/adr/0001-greenfield-boundary.md)
- [Backend platform](https://github.com/yazhsab/planext4u-backend)
