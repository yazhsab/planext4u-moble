# Phase 2 executable backlog

## Outcome

Deliver the shared Flutter foundation and a staging-ready customer vertical slice: login -> consent/location -> customer home -> catalog read. Vendor and rider applications must compile from the same workspace with their authenticated shells and role boundaries.

Target window: 2026-09-24 to 2026-11-04. Estimates are Fibonacci story points for one cross-functional mobile squad; sequencing is dependency-based rather than a calendar promise.

| ID | Story | Points | Depends on | Acceptance evidence |
| --- | --- | ---: | --- | --- |
| `MOB-P2-001` | Create Melos Flutter workspace with customer, vendor and rider apps plus shared packages | 8 | None | `BOOTSTRAP-001`; all apps build/test on Android and iOS CI |
| `MOB-P2-002` | Add dev/staging/prod flavours, typed environment configuration and secret boundaries | 5 | 001 | No embedded secrets; flavour IDs/deep links validated |
| `MOB-P2-003` | Implement generated tokens, themes and accessible shared widget catalogue | 13 | 001 | `A11Y-001`, `GOLDEN-001`; light/dark, 1.3 text and tablet goldens |
| `MOB-P2-004` | Implement generated API client, auth interceptors, retries, idempotency and error taxonomy | 13 | 001, backend contracts | Contract fixtures, cancellation/timeouts and redaction tests pass |
| `MOB-P2-005` | Implement secure identity/session package for OTP, email and OAuth role routing | 13 | 002, 004, backend identity | `AUTH-001`, `AUTH-002`; refresh/revoke/device/session-denial paths pass |
| `MOB-P2-006` | Implement bootstrap, remote config, update/maintenance gates, consent and localisation shell | 8 | 002, 003, 004 | Remote/offline defaults, EN/Tamil and consent audit fixtures pass |
| `MOB-P2-007` | Implement location education, permission, GPS/manual selection and serviceability shell | 8 | 003, 004, 006 | `LOCATION-001`; deny/retry/settings/manual/offline states pass |
| `MOB-P2-008` | Implement customer navigation, home composition and catalog-read vertical slice | 13 | 003-007, backend BFF/catalog | `MOB-E2E-001`, `CATALOG-READ-001`; all state variants and deep links pass |
| `MOB-P2-009` | Implement vendor and rider authenticated shells with permission-driven navigation | 8 | 003-006 | Role denial/navigation contract tests; placeholder features use explicit flags |
| `MOB-P2-010` | Add secure storage, encrypted cache, offline/stale policy and command queue foundation | 8 | 004-006 | Expiry, logout purge, corruption, offline/reconnect and no-PII-log tests pass |
| `MOB-P2-011` | Add analytics consent, crash reporting, structured logs and correlation propagation | 5 | 002, 004, 006 | `OBS-001`; opt-out and redaction tests pass in all flavours |
| `MOB-P2-012` | Establish CI quality gates, emulator integration tests and staging smoke workflow | 8 | 001-011 | Format/analyze/unit/widget/contract/golden/E2E gates run from clean checkout |

Total baseline: 120 points.

## Delivery slices

1. Foundation: `001-004`.
2. Trust and bootstrap: `005-007`, `010-011`.
3. Role shells and vertical slice: `008-009`.
4. Automated staging gate: `012`.

## Contract dependencies

- Identity/session/device/OpenID contracts before `MOB-P2-005` integration.
- Configuration/CMS/location/catalog BFF contracts before `MOB-P2-006` through `008` integration.
- Common error, pagination, idempotency and correlation standards before generated client freeze.
- Synthetic staging tenant and deterministic fixtures before `MOB-E2E-001`.

## Phase 2 exit criteria

- All three apps build automatically from a clean checkout for dev/staging/prod.
- Customer vertical slice deploys to staging and passes `MOB-E2E-001` without manual environment changes.
- Auth/session and role-denial suites pass; secrets and PII are absent from source/log fixtures.
- Approved golden/accessibility suites pass for phone/tablet, light/dark and English/Tamil fixtures.
- Requests emit correlation-aware, consent-respecting telemetry.
- Loading, empty, error, offline-stale and permission-denied states are implemented for the slice.
