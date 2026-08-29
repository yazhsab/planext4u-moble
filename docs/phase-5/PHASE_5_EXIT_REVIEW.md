# Phase 5 mobile exit review

## Decision

Phase 5 implementation is complete. The greenfield Flutter customer application
consumes server-owned privacy, publication, entitlement, contact, expiry and
emergency state from backend commit
`cdfc28dbaecad124500f93bd63a50a1865bf781e`.

## Delivered customer experiences

- Socio profile/private-state display, follow requests, mute/unmute,
  block/unblock, ranked feed, post composition, media references, moderation
  states, sponsored labels, reactions, saves, collections, nested discussion,
  mentions, hashtags and reporting.
- Stories, reels and highlights with quarantine/scan lifecycle messaging;
  message requests/acceptance, DMs, voice-note media handoff, presence updates,
  audio/video call creation and WebRTC signalling/end states.
- Homes browse/search, buy/rent filters, approximate map coordinates, detail,
  versioned estimates, inquiry, visit request, owner KYC draft, publish and
  featured-plan actions.
- Classified browse/search, four-step posting, safety-scanned media guidance,
  masked contact, explicit phone/WhatsApp consent, reporting, expiry/repost and
  featured-plan actions.
- Emergency disclaimer, explicit live-location consent, assistance request,
  status/SLA/escalation display, stale-location handling, location revocation and
  requester/responder communications.
- Safe deep links for `/app/community`, `/app/homes`, `/app/classifieds` and
  `/app/emergency`, plus authenticated runtime wiring and feature-flag gating.
- Profile privacy controls for redacted account data export and explicit account
  deletion scheduling with a 30-day recovery period.

## Contract and privacy posture

Social, local-vertical, emergency and governance OpenAPI snapshots plus Home,
classified, emergency and governance fixtures are pinned with SHA-256 provenance.
Contact values remain masked until explicit consent. Precise emergency location
is not inferred by the client and the UI exposes immediate revocation. Media
publication and relationship/call permissions are rendered only from
server-provided state and allowed actions.

## Acceptance evidence

| Gate | Evidence |
| --- | --- |
| Contract drift | `generate_contracts.dart --check` validates immutable source commit and all Phase 5 hashes |
| Controllers | Phase 5 tests cover authoritative load/mutations, KYC draft/publication, expiry/repost, media quarantine and call signalling |
| Widgets | Four-tab Community Hub, Socio profile/actions, messaging, Homes, classifieds and emergency journeys have widget coverage |
| Responsive/accessibility | Narrow Android viewport, increased text scale, semantics, tap-target and contrast checks remain in the suite |
| Deep links | Authenticated route parsing covers Socio post and all Community destinations |
| Full workspace | `dart run melos run verify` passes formatting, flavor/CI validation, analysis and every Dart/Flutter test |

## Deployment gates

Store signing, real push/payment/media/WebRTC credentials, legal emergency
approval, regional responder readiness, real-device permission rehearsal and
environment-scale soak remain release-environment approvals. They are kept out
of source control and do not represent missing Phase 5 implementation.
