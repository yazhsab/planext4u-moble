# Planext4u Mobile

Current increment: vendor/rider onboarding correction forms, source-bound resubmission, scoped reviewer evidence access and portable privacy export are implemented. The Flutter workspace passes 573 tests and all 12 analyses on 597 unchanged inputs; final contract sync passes 95 API-client tests. All three matching-source Android development/debug APKs compile with verified package IDs and hashes. The canonical admin passes 137 tests and its production build; the real HTTPS/private-scan/regional/reviewer-grant/normal-Flutter journey passes 85 checks, and the persistent API suite passes 264. The earlier captured backend checkpoint passes a complete 27-target/131-migration gate; a later aggregate gate for reviewer access and the first order-work handoff is being rerun after a disposable test-fixture correction. Real provider/device evidence, full cross-owner erasure and release readiness remain open. iOS remains deferred.

Greenfield Flutter workspace for the Planext4u customer, vendor, and rider applications.

This repository is intentionally independent of the Lovable/Vercel proof-of-concept. No source code, generated code, dependencies, or assets will be copied from the legacy repository. The live application may be used only as a black-box behavioural and visual reference after access is authorised.

## Planned applications

- `apps/customer` - marketplace, services, food, Homes, classifieds, Socio, wallet, emergency assistance, and account features.
- `apps/vendor` - onboarding, KYC, catalog, service schedules, orders, inventory, promotions, analytics, settlements, and support.
- `apps/rider` - onboarding, availability, assignments, maps, delivery/service lifecycle, proof of delivery, attendance, and earnings.
- Shared packages - design system, API contracts, authentication, secure storage, media, maps, observability, localisation, and testing.

The administrator console is planned as a separately deployable web workspace under `planext4u-backend/admin-web` so the requested two-repository boundary is preserved. It can be extracted to a dedicated repository later without changing its API contracts.

## Current status

Latest local checkpoint (28 October 2026): Flutter and all three Android development/debug APKs pass on the final API 36 and secure-storage 11.2.0 source. The admin and 85-check local onboarding/reviewer journey pass. Phase 2 remains partial; Phase 3 has an ordering-to-supply foundation under test but is not accepted. iOS, configured provider/device and release evidence remain pending. The authoritative receipt index is in the adjacent backend workspace at `docs/completion/phase-2/STATUS.md`.

The product is under implementation and is not production-ready. Source code,
contracts and test scaffolds exist across the three roles and product verticals;
these do not establish complete user journeys or verified production operation.
Earlier repository milestone labels are separate from the current mobile-first
completion plan and must not be read as phase acceptance.

The authoritative mobile-first completion plan is
[`../MOBILE_FIRST_IMPLEMENTATION_PLAN_2026-10-24.md`](../MOBILE_FIRST_IMPLEMENTATION_PLAN_2026-10-24.md).
Its current Phase 2 remains partial. See
[the acceptance register](../planext4u-backend/docs/completion/phase-2/STATUS.md)
for verified implementation and remaining work. Phase 3 has not been accepted
or started under that plan.

The 27 October occupation/profile workspace passes 549 Flutter tests and all
12 analyses on 593 matching source inputs. All three Android development/debug
APKs compile. The current full backend gate/all 27 PostgreSQL targets and the actual
17-check admin-to-Flutter occupation journey also pass after Docker recovery.
Local provider assertions are synthetic; real provider/device, release and
remote deployment acceptance remain separate. Android, the Go backend and the canonical admin are the current target.
iOS is explicitly deferred. Do not infer feature completion or production
readiness from compilation, test counts or historical milestone descriptions.

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
- [Three-phase production-hardening exit review](docs/phase-3/PRODUCTION_HARDENING_EXIT_REVIEW.md)
- [Release and rollback runbook](docs/phase-3/RELEASE_AND_ROLLBACK_RUNBOOK.md)
- [Store and privacy checklist](docs/phase-3/STORE_PRIVACY_CHECKLIST.md)
- [Security and performance runbook](docs/phase-3/SECURITY_AND_PERFORMANCE_RUNBOOK.md)
- [Phase 4 executable backlog](docs/phase-4/PHASE_4_BACKLOG.md)
- [Phase 4 service-booking entry slice](docs/phase-4/SERVICE_BOOKING_ENTRY_SLICE.md)
- [Phase 4 exit review](docs/phase-4/PHASE_4_EXIT_REVIEW.md)
- [Phase 5 executable backlog](docs/phase-5/PHASE_5_BACKLOG.md)
- [Phase 5 Socio trust entry slice](docs/phase-5/SOCIO_TRUST_ENTRY_SLICE.md)
- [Phase 5 exit review](docs/phase-5/PHASE_5_EXIT_REVIEW.md)
- [Decision log](docs/phase-1/DECISION_LOG.md)
- [Feature catalogue](docs/FEATURE_CATALOGUE.md)
- [Design-system baseline](docs/DESIGN_SYSTEM_BASELINE.md)
- [Greenfield boundary ADR](docs/adr/0001-greenfield-boundary.md)
- [Backend platform](https://github.com/yazhsab/planext4u-backend)
