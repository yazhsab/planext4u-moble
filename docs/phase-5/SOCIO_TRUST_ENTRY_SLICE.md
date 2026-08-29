# Phase 5 Socio and trust entry slice

The Flutter entry slice consumes the backend Socio contract without duplicating
ranking or privacy rules. It provides feed pagination, a post composer, visible
moderation state, reactions, saves and nested discussion while treating every
server-provided revision and allowed action as authoritative.

Deep links are limited to `/app/social` and `/app/social/posts/{safe-id}`.
Pending or removed content is never cached as public feed content. Failed
mutations refresh server state and explain the conflict instead of preserving an
incorrect optimistic count.

## Implemented baseline

- Social OpenAPI and feed fixtures are pinned to backend commit
  `30fca1520c6c77c6d40e346c2153b015750eba14` with SHA-256 provenance and drift
  validation.
- The customer runtime exposes Socio only to authenticated sessions and supports
  `/app/social` plus safe post deep links.
- Feed, compose, reaction, save, comment and report controllers use idempotent
  commands and `If-Match` revisions. A 409 reloads server truth.
- Published, pending-review, removed, sponsored, verified and private states are
  explicit in the accessible Flutter UI.
- `MOB-E2E-008` exercises ranked feed, revisioned engagement, comments,
  moderation reporting and pending-review visibility on the Android CI device.

This entry slice has now been extended through the Phase 5 exit gate. Profile
relationships, media/reels/stories, messaging, Homes, classifieds, emergency
and responsive governance evidence are summarized in
[the Phase 5 exit review](PHASE_5_EXIT_REVIEW.md).
