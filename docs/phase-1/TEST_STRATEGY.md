# Mobile and journey test strategy

## Quality model

The three Flutter applications share a test pyramid and release evidence model. Server-owned rules are verified through generated contracts and integration environments; clients never duplicate money, points, stock, settlement or lifecycle truth.

| Layer | Required evidence | Merge/release gate |
| --- | --- | --- |
| Static | `dart format`, `flutter analyze`, dependency/license/secret scanning | Every pull request |
| Unit | Domain adapters, state reducers, validators, formatting, cache and retry policy | Changed packages >= 80% line coverage; critical policy branches 100% |
| Widget | Every design-system component and state in light/dark and text scale 1.0/1.3 | Golden and semantics tests pass |
| Contract | Generated clients against OpenAPI examples and backward-compatibility fixtures | No breaking change; error/idempotency cases pass |
| Integration | Auth/session, storage, offline cache, deep links, notifications and analytics consent | Dev and staging flavours pass |
| Journey | Customer, vendor and rider happy/error paths against controlled staging records | Named Phase acceptance suites pass |
| Non-functional | Startup/render/memory, accessibility, localisation, network degradation, security and privacy | Budgets in `PROGRAM_PLAN.md` pass |

## Device and viewport matrix

- Android: API 26 low-memory 2 GB reference device, current-2, current.
- iOS: oldest supported major, current-1, current.
- Phone widths: 360, 390 and 430 logical pixels.
- Tablet widths: 768 and 1024 logical pixels.
- Themes: light, dark and system.
- Text: 100%, 130% and one 200% accessibility smoke suite.
- Locales: English on every suite; Tamil long-string and Hindi smoke suites in Phase 2; all nine locales before production.
- Networks: offline, 400 ms latency/2% loss, slow 3G and normal Wi-Fi.

## Named journey suites

| ID | Journey | Minimum Phase |
| --- | --- | --- |
| `MOB-E2E-001` | Fresh install -> consent -> login -> location -> home -> catalog read | Phase 2 |
| `MOB-E2E-002` | Product search -> PDP -> cart -> checkout -> payment recovery -> order | Phase 3 |
| `MOB-E2E-003` | Wallet earn/redeem/expiry/reversal with server ledger reconciliation | Phase 3 |
| `MOB-E2E-004` | Service slot lock -> payment -> reschedule -> start/completion evidence | Phase 4 |
| `MOB-E2E-005` | Food cart -> restaurant queue -> dispatch -> tracking -> chat expiry | Phase 4 |
| `MOB-E2E-006` | Vendor onboarding -> approval -> catalog -> first settlement | Phase 4 |
| `MOB-E2E-007` | Rider duty -> concurrent offer -> offline recovery -> POD -> earnings | Phase 4 |
| `MOB-E2E-008` | Socio post/reel/story -> engagement -> DM -> report/moderation | Phase 5 |
| `MOB-E2E-009` | Homes/classified listing -> moderation -> inquiry/report -> expiry | Phase 5 |
| `MOB-E2E-010` | Emergency request -> consent -> assignment -> escalation -> closure | Phase 5 after release gate |

## Phase 2 acceptance suites

- `BOOTSTRAP-001`: all three apps start with dev/staging/prod configuration and no embedded secret.
- `AUTH-001`: OTP/email/OAuth sessions refresh, revoke and route only to authorised roles.
- `AUTH-002`: offline/expired/revoked sessions show deterministic recovery without data leakage.
- `LOCATION-001`: deny, retry, manual selection and settings return paths are usable with semantics.
- `CATALOG-READ-001`: home/catalog renders contract fixtures, loading, empty, error, stale and offline states.
- `OBS-001`: every request carries correlation/device/app metadata and redacts credentials/PII.
- `A11Y-001`: priority screens pass semantics, contrast, focus order and 130% text tests.
- `GOLDEN-001`: approved golden references pass phone/tablet light/dark comparison thresholds.

## Test data and privacy

- Automated suites use synthetic tenants, users, vendors, riders, products and ledgers.
- Production data is never copied into local, CI or preview environments.
- Test identities are labelled, rate-limited and deleted by an automated retention job.
- Payment providers use official sandbox modes; webhook fixtures are signed and replayable.
- Screenshots, logs and crash reports redact secrets, phones, email addresses, precise location, KYC and payment identifiers.

## Defect policy

- P0/P1 defects block release and require regression tests.
- POC defects are not reproduced unless a signed product decision explicitly adopts the behaviour.
- Flaky-test quarantine requires owner, issue, expiry within seven days and a non-flaky release gate.
- Golden changes require an intentional design-token/component approval, never blind baseline replacement.
