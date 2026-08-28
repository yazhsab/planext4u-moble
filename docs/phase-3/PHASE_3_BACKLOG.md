# Phase 3 mobile executable backlog

## Outcome

Deliver the customer marketplace journey from search and production PDP through cart, checkout, payment recovery, orders and wallet, while preserving the POC feature inventory and approved Planext4u design system.

| ID | Story | Depends on | Acceptance evidence |
| --- | --- | --- | --- |
| `MOB-P3-001` | Implement search/discovery results, filters and complete loading/empty/error states | Phase 2 catalog, backend P3 contracts | Search widget/contract tests and accessibility checks pass |
| `MOB-P3-002` | Implement golden-aligned PDP with variants, seller trust, delivery, description/spec/review/Q&A tabs | 001 | 390 x 844 and 130% text golden/accessibility tests pass |
| `MOB-P3-003` | Implement server-authoritative persistent cart, quantity/remove, reprice and conflict recovery | 001-002, backend cart | No client money arithmetic; replay/conflict/offline tests pass |
| `MOB-P3-004` | Implement address, delivery scheduling, promotion and checkout review | 003 | Fee/tax/promotion and stale-price state tests pass |
| `MOB-P3-005` | Integrate Razorpay/Paystack/COD with pending/failure/retry recovery | 004 | Provider handoff and process-death recovery tests pass |
| `MOB-P3-006` | Implement order lifecycle, tracking, cancellation, return/refund, POD and ratings | 005 | State/deep-link/notification failure tests pass |
| `MOB-P3-007` | Implement wallet ledger, points/referrals/rewards, hybrid payment and expiry views | 005-006 | `MOB-E2E-003` ledger reconciliation passes |
| `MOB-P3-008` | Complete marketplace accessibility, localization, performance and release evidence | 001-007 | `MOB-E2E-002`, checkout >=97%, load and staging smoke gates pass |

All eight engineering stories are implemented. Their acceptance evidence and
remaining environment-owned release gates are recorded in
`PHASE_3_EXIT_REVIEW.md`.

## Entry slice

Implementation starts with `MOB-P3-001` through `MOB-P3-003`: search -> golden-aligned PDP -> server-authoritative cart/reprice. It traces to `P4U-MKT-001` through `P4U-MKT-003`; all money and allowed actions come from backend responses.

The completed slice is pinned to backend commit `e78941b`. Mobile CI validates
the exact catalog, commerce, transaction and notification OpenAPI snapshots plus the
authoritative cart, quote, payment, order and wallet fixtures before analysis
and tests.
