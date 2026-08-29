# Phase 5 mobile executable backlog

## Outcome

Deliver safe engagement, local verticals and governance experiences across the
Flutter applications. Clients render server-owned privacy, moderation, ranking,
contact, expiry, entitlement and emergency state and never infer publication or
access rights.

| ID | Story | Acceptance evidence |
| --- | --- | --- |
| `MOB-P5-001` | Pin additive Socio, moderation, Homes, classifieds and emergency contracts/fixtures | Provenance and drift checks pass against immutable backend commits |
| `MOB-P5-002` | Deliver social profile, privacy, follow/request, block and mute journeys | Private-account and cross-role widget/controller suites pass |
| `MOB-P5-003` | Deliver ranked feed, posts, media, sponsored labels and product stickers | Pagination, moderation-state, ranking-version and narrow-screen tests pass |
| `MOB-P5-004` | Deliver reactions, comments/replies, mentions, hashtags, saves and collections | Idempotency/conflict, nesting, optimistic rollback and accessibility tests pass |
| `MOB-P5-005` | Deliver stories/highlights and reels with lifecycle-aware media | Expiry, playback recovery, reporting and memory tests pass |
| `MOB-P5-006` | Deliver DMs, requests, voice notes, presence and call signalling | Mutual-follow, block, retry, permission and call-state tests pass |
| `MOB-P5-007` | Deliver Homes search/map, detail, estimates, owner flows, visits, plans and upgrades | Geo, KYC, estimate-version, inquiry and purchase recovery tests pass |
| `MOB-P5-008` | Deliver classifieds wizard, browse/detail, safe contact, expiry/repost, reports and upgrades | Draft recovery, moderation, masking, WhatsApp consent and expiry tests pass |
| `MOB-P5-009` | Deliver emergency consent, request, live responder map, communication and escalation | Permission, offline, stale-location and SLA state tests pass |
| `MOB-P5-010` | Deliver moderation/reporting, privacy and retention controls | Report, block/mute, takedown and account-export/deletion tests pass |
| `MOB-P5-011` | Complete governance/admin responsive experiences needed outside desktop | RBAC, MFA, masking and audit evidence pass |
| `MOB-P5-012` | Complete parity, media/realtime soak, device, accessibility and resilience acceptance | `MOB-E2E-008` onward and P0/P1 parity register pass |

## Entry slice

Implementation starts with `MOB-P5-001` through `MOB-P5-004`, paired with
backend stories `BE-P5-001` through `BE-P5-004`. The slice includes a real
customer feed/create/engage UI and explicit private, blocked, pending-review,
offline and stale-revision states.

## Completion

All stories `MOB-P5-001` through `MOB-P5-012` are implemented. Contract drift,
controller, widget, accessibility, deep-link and application quality evidence is
recorded in the [Phase 5 exit review](PHASE_5_EXIT_REVIEW.md).
