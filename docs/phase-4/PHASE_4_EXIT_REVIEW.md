# Phase 4 mobile exit review

## Decision

**Accepted — 28 August 2026.** Stories `MOB-P4-001` through `MOB-P4-012` are
implemented across the customer, vendor and rider Flutter applications. The
apps consume server-owned availability, money, lifecycle and allowed actions;
they do not infer capacity, entitlement, commission or payout truth.

## Delivered scope

| Area | Acceptance evidence | Result |
| --- | --- | --- |
| Contract authority | Supply, service, food and fulfilment OpenAPI snapshots and fixtures are pinned to immutable backend commit `f616ee6a1f5216db5bbb90100c161e96d177243a`; drift validation passes | Pass |
| Customer service | Trust/geo discovery, live slots, atomic expiring holds, payment recovery, activity, reschedule/cancel, arrival/start OTP, completion evidence, confirmation, no-show and dispute | Pass |
| Customer food | Restaurant/menu discovery, option constraints, server-authoritative cart totals, cut-offs, payment, restaurant queue, dispatch, tracking and refund state | Pass |
| Vendor | Secure role runtime, registration, private KYC references, field visit, zones, bank setup, catalog, inventory, revision-safe schedules, product/service/food queues, promotions, dashboard and settlement | Pass |
| Rider | Secure role runtime, KYC, duty, atomic offer countdown, navigation handoff, on-duty background location, encrypted ordered offline recovery, pickup, POD OTP/photo/signature, reassignment, attendance, earnings and payout | Pass |
| Communication | Expiring/redacted order chat, role-scoped push token registration/rotation, safe deep-link validation and authenticated unregister | Pass |
| Native boundaries | Android foreground/background location and notification permissions; iOS location background mode, APNS entitlement and associated domains; three environment flavors | Pass |
| Accessibility/resilience | Narrow viewport and 130% text coverage, offline states, conflict recovery, token/provider failure isolation and encrypted persistence | Pass |

## Verification record

The final workspace gate completed successfully:

```sh
dart run melos run verify
```

This drift-checked generated contracts and design tokens, validated all three
apps across three environments, checked the CI definition, formatted and
analyzed all 11 workspace packages, and passed all unit, widget, accessibility
and golden tests.

All three production flavors built successfully as Android debug APKs and iOS
simulator applications. `MOB-E2E-001` through `MOB-E2E-007` then passed on a
fresh API 36 Pixel 6 emulator constrained to 2 GB (`MemTotal: 2021944 kB`):

- customer: five controlled journeys passed;
- vendor: onboarding through first settlement passed;
- rider: duty, offer, offline recovery, POD and earnings passed.

Backend verification also passed `make verify` and `make admin-verify`, including
Go race/build gates, Phase 4 controlled journeys/load tests and the secure admin
console test/build/browser suites.

## Exit boundary

Phase 4 source and local acceptance are complete. Store signing, production
Firebase/APNS projects, maps/navigation provider keys, payment-provider secrets
and deployment infrastructure are environment provisioning inputs and are not
embedded in source control.
