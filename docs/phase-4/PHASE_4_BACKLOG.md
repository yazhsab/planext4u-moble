# Phase 4 mobile executable backlog

## Outcome

Deliver production-grade customer service and food journeys, vendor operations,
rider fulfilment, settlement visibility, messaging and offline recovery. Mobile
clients render server-owned availability, money, lifecycle and allowed actions;
they never infer capacity, entitlement, commission or payout truth.

| ID | Story | Acceptance evidence |
| --- | --- | --- |
| `MOB-P4-001` | Pin additive supply/service/food/fulfilment contracts and synthetic fixtures | Contract provenance and drift checks pass against an immutable backend commit |
| `MOB-P4-002` | Deliver customer service discovery, trust, live slots and expiring atomic hold | Narrow/large-text widget coverage and hold-conflict tests pass |
| `MOB-P4-003` | Deliver advance/full payment, recovery, booking activity, reschedule and cancellation | Server totals/actions/revisions are rendered; stale and expiry states are recoverable |
| `MOB-P4-004` | Deliver arrival/start OTP, completion evidence, customer confirmation, no-show and dispute | Sensitive code semantics and evidence/confirmation lifecycle tests pass |
| `MOB-P4-005` | Deliver vendor registration, OCR-assisted KYC, field visit, zones, profile and bank setup | Private-document, staged review and resume tests pass |
| `MOB-P4-006` | Deliver vendor catalog, inventory/schedules, product/service/food queues and promotions | Owned-resource, revision conflict and offline command tests pass |
| `MOB-P4-007` | Deliver customer food discovery, menu customisation, authoritative cart, cut-offs and order tracking | Pricing, option, reject/timeout and refund journeys pass |
| `MOB-P4-008` | Deliver rider onboarding, duty, atomic offer countdown, navigation and background location | Concurrent offer, permission, location TTL and battery gates pass |
| `MOB-P4-009` | Deliver rider offline lifecycle, POD, reassignment, attendance and earnings | Ordered recovery, photo/OTP/signature and ledger reconciliation tests pass |
| `MOB-P4-010` | Deliver vendor/rider chat, notifications and safe contact windows | Role, expiry, redaction, retry and deep-link tests pass |
| `MOB-P4-011` | Deliver vendor/rider settlement, analytics and support views | Calculation-version and payout-status fixture tests pass |
| `MOB-P4-012` | Complete device, performance, accessibility and resilience acceptance | `MOB-E2E-004` through `007`, 2 GB device and offline recovery gates pass |

## Entry slice

Implementation begins with `MOB-P4-001` through `MOB-P4-004`, paired with
backend stories `BE-P4-001` through `BE-P4-004`. The remaining stories stay
open until their backend contracts and role-specific journeys are accepted.
