# Planext4u three-phase mobile implementation plan

## Purpose

This plan converts the approved Planext4u requirements, the current greenfield
Flutter workspace, the supplied UI references, and the behavioural review of
InAllCart into a production-oriented mobile delivery programme.

InAllCart is a reference for user journeys and interaction ideas only. Its
source, API clients, data models, authentication, payment code, Firebase
configuration, storage code and visual assets must not be copied into this
workspace. All implementation remains contract-first and follows
`docs/adr/0001-greenfield-boundary.md`.

## Starting position

The repository contains customer, vendor and rider Flutter applications plus
shared packages for configuration, API access, identity, secure storage,
experience, design, observability and core utilities. Phase 1 through Phase 5
source acceptance is documented, while live cloud infrastructure, real provider
credentials, production signing, regional operations and environment-scale
validation remain release gates.

For planning purposes, the current evidence-based baseline is:

| Measure | Baseline |
| --- | ---: |
| Requirements and architecture artefacts | approximately 85% |
| Source-visible functional product coverage | approximately 58% |
| Production readiness | approximately 35% |
| Production release approval | not granted |

Percentages are programme indicators, not a substitute for the exit criteria
below. Completion is earned by executable evidence against versioned contracts.

## Programme rules

1. Server responses remain authoritative for money, stock, eligibility,
   permissions, publication, settlement and state transitions.
2. Mobile mutations use idempotency keys and never receive generic automatic
   retries unless the operation contract explicitly permits them.
3. Tokens, payment secrets, raw KYC documents and private contact data never use
   ordinary preferences, logs or analytics payloads.
4. Dynamic UI configuration may control presentation and ordering, but cannot
   grant capabilities that the authenticated API has not allowed.
5. Every delivered journey includes loading, empty, error, offline, stale-data,
   permission-denied and large-text states where applicable.
6. Definition of done includes formatting, static analysis, unit/widget tests,
   contract drift checks, accessibility evidence and role-denial coverage.
7. Template-derived behaviour is re-specified as acceptance criteria before new
   Planext4u code is written.

## Phase 1 — Experience parity and configurable discovery

**Indicative duration:** 6–8 weeks
**Primary outcome:** The customer, vendor and rider shells present the approved
information architecture and consistent responsive behaviour while continuing
to consume Planext4u-owned contracts.

### Customer application

- Align the persistent customer navigation with the approved five destinations:
  Home, Socio, Categories, Account and Cart.
- Add an accessible module launcher for Shop, Socio, Services, Homes and
  Classifieds; retain explicit routes to Food, order activity and Emergency.
- Make server-configured home sections deterministic: enabled filtering,
  priority ordering, stable duplicate handling and safe omission of unknown
  section kinds.
- Add section-title resolution through the Planext4u localisation catalogue;
  server keys must never be rendered as raw internal identifiers.
- Expand the dynamic home composition contract for hero campaigns, trust
  benefits, categories, bestsellers, recommendations, service discovery and
  contextual help without embedding campaign content in the binary.
- Standardise cards, horizontal rails, image placeholders, favourite actions,
  availability messaging and cart affordances in the shared design system.
- Preserve current offline/stale projection handling and pull-to-refresh.

### Vendor application

- Standardise dashboard, catalog, order, booking, promotion and settlement
  destinations using the same shell and state-panel conventions.
- Break large forms into resumable steps with server revision checks.
- Add explicit draft/sync/conflict states for catalog and schedule changes.

### Rider application

- Standardise duty, offer, active job, navigation, proof-of-delivery and earnings
  destinations.
- Surface background-location permission, service and offline-queue states in a
  user-actionable way.
- Ensure delivery completion always presents the server-required OTP/photo/
  signature evidence contract.

### Shared engineering

- Add reusable responsive rail/card/section components without importing
  InAllCart widgets or assets.
- Complete semantic labels, focus order, 48dp targets, 130–200% text scaling and
  narrow-device coverage for the changed surfaces.
- Extend golden fixtures for the supplied customer-home reference states.

### Phase 1 acceptance evidence

- Customer bottom navigation exposes exactly the five approved destinations.
- Each module launcher action opens the correct existing Planext4u controller or
  is hidden when its feature/controller is unavailable.
- Configured home sections render once, in ascending priority order.
- Unknown/disabled sections cannot crash or expose an unauthorised feature.
- Navigation, dynamic-home, large-text and narrow-viewport widget tests pass.
- `dart run melos run verify` passes with no contract or token drift.

## Phase 2 — Integrated role journeys and runtime reliability

**Indicative duration:** 8–10 weeks
**Primary outcome:** Customer demand, vendor fulfilment and rider execution work
as authenticated cross-role journeys in a real staging environment.

### Provider and platform integrations

- Activate staging Firebase/APNS, maps/navigation, media upload/processing,
  Razorpay/Paystack and WebRTC through environment-owned credentials.
- Keep payment confirmation webhook-authoritative; the mobile application shows
  pending state until the backend confirms the ledger transition.
- Validate push registration/rotation/unregister and deep-link allowlists across
  all application states.
- Exercise media quarantine, scan, moderation and publication lifecycle.

### Cross-role journeys

- Product order: discovery → cart → checkout → vendor acceptance → rider offer →
  pickup → tracking → POD → settlement → rating/refund.
- Service booking: availability hold → payment → vendor schedule → start OTP →
  completion evidence → customer confirmation/dispute.
- Food order: menu constraints → restaurant queue → dispatch → tracking →
  delivery/refund.
- Socio-to-commerce, Homes inquiry, classified safe-contact and emergency
  responder communication flows.

### Reliability and security

- Prove ordered encrypted offline queues for rider location and job transitions.
- Add mutation replay, expired-session, stale-revision and duplicate-webhook
  tests.
- Validate least-privilege roles, denial cases, KYC visibility and masked contact
  rules against staging.
- Add correlated mobile/backend telemetry without personal, payment or KYC data.

### Phase 2 acceptance evidence

- Named cross-role E2E suites pass on Android and iOS physical devices.
- Payment retries, duplicate callbacks, inventory races and settlement
  reconciliation produce one authoritative outcome.
- Rider background operation meets agreed battery, accuracy and reconnect
  budgets on a constrained Android device.
- Push, media, map and WebRTC provider failure drills have actionable fallbacks.
- No P0/P1 security or contract defect remains open.

## Phase 3 — Production hardening and controlled release

**Indicative duration:** 6–8 weeks plus external approval lead time
**Primary outcome:** Signed, observable and supportable mobile releases are
approved for progressive rollout.

### Product completeness

- Complete and validate English, Tamil, Hindi, Telugu, Kannada, Malayalam,
  Marathi, Bengali and Gujarati translations.
- Validate screen-reader order, dynamic type, contrast, motion preferences,
  keyboard/focus behaviour and error announcements.
- Complete light/dark mode, low-bandwidth, offline/reconnect, permission lifecycle
  and account export/deletion regression.

### Production engineering

- Run SAST, dependency, secret, mobile binary, API penetration and privacy
  manifest reviews.
- Execute calibrated load, soak, chaos and disaster-recovery exercises against
  production-equivalent infrastructure.
- Validate crash-free session, cold-start, image-first-paint, API latency,
  checkout-success and notification-delivery targets.
- Complete Android/iOS signing, store metadata, screenshots, privacy disclosures,
  release notes and rollback-capable CI/CD.

### Operations and rollout

- Complete legal emergency approval, responder readiness, finance/payment/KYC
  reviews and customer-support training.
- Run internal, one-city pilot, 5%, 25%, 50% and 100% rollout stages.
- Define automated rollback thresholds for crashes, payment failures, order
  failures, notification loss and backend SLO breaches.

### Phase 3 acceptance evidence

- All required devices, locales and accessibility suites pass.
- Production credentials are supplied only through protected environments.
- Disaster recovery and rollback are rehearsed and timed.
- Business, engineering, security, finance, legal and operations approve the
  production-readiness review.
- No P0/P1 parity, privacy, payment or operational gap remains.

## Delivery organisation and estimate

A practical parallel team is 6–8 people: two customer/mobile engineers, one
vendor engineer, one rider engineer, one backend/integration engineer, one QA
automation engineer, and shared design/security/platform support. The three
phases require approximately 20–26 engineering weeks; infrastructure,
credential, legal or regional-readiness delays can extend the calendar to
24–32 weeks. A solo implementation is expected to take 12–18 months or more.

## Phase 1 implementation status

**Status: complete — 100% of the Phase 1 source and repository-verifiable
acceptance scope passed on 2026-08-30.** The implementation is contract-neutral,
keeps server authority intact and imports no InAllCart source, asset, API or
dependency.

| ID | Change | Acceptance | Status |
| --- | --- | --- | --- |
| `P4U-MI1-001` | Approved five-destination customer navigation | Home, Socio, Categories, Account and Cart are visible and correctly routed | Complete |
| `P4U-MI1-002` | Accessible home module launcher | Shop, Socio, Services, Food, Homes, Classifieds and Emergency respect controller availability | Complete |
| `P4U-MI1-003` | Deterministic configured-home composition | Enabled known sections render once by priority; aliases deduplicate; unknown sections are ignored | Complete |
| `P4U-MI1-004` | Localised presentation metadata | Bounded display copy and allowlisted internal actions never expose raw server keys | Complete |
| `P4U-MI1-005` | Shared discovery and commerce components | Campaign, benefits, section headers, rails, placeholders and product actions are responsive and semantic | Complete |
| `P4U-MI1-006` | Vendor workflow standardisation | Catalog, order, booking, promotion, settlement and profile destinations include draft/sync/conflict handling | Complete |
| `P4U-MI1-007` | Rider workflow standardisation | Duty, offers, jobs, navigation, location recovery, POD evidence and earnings have explicit state handling | Complete |
| `P4U-MI1-008` | Accessibility and responsive coverage | Changed customer/vendor/rider surfaces pass narrow-device tests at 130% and 200% text | Complete |
| `P4U-MI1-009` | Golden reference fixtures | Phone/tablet and light/dark catalogue fixtures cover the extended shared component set | Complete |
| `P4U-MI1-010` | Native dependency and flavor integrity | Three Android and three iOS production-flavor debug/simulator builds compile successfully | Complete |
| `P4U-MI1-011` | Complete repository quality gate | Contracts, tokens, formatting, flavors, CI policy, analysis and all tests pass | Complete |

### Completion evidence

- `dart run melos run verify` passed across all 11 workspace packages and apps.
- API contract hash `332ef63e39ef8f7e4dc13a25709b697f288fbb66061f29f73ecf0ee7a8db4b0f`
  and generated design tokens have no drift.
- Customer, vendor and rider production-flavor Android debug APKs compiled.
- Customer, vendor and rider production-flavor iOS simulator applications
  compiled without code signing.
- Vendor and rider use Flutter Swift Package integration without stale
  CocoaPods wiring; customer retains CocoaPods only for its current compatible
  plugin set. Flavor validation enforces both supported configurations.

“Phase 1 complete” does not grant production release approval. Real provider
credentials, physical-device cross-role staging runs, payment/webhook evidence,
maps and private media-provider activation, signing, store review, security
assessment and controlled rollout are deliberately assigned to Phases 2 and 3.

## Phase 2 implementation status

**Status: repository implementation complete; environment-owned acceptance is
pending.** On 2026-08-30, the customer, vendor and rider source boundaries,
automated reliability evidence and complete 3-app × 3-environment native compile
matrix passed. This does not mislabel unavailable cloud credentials or physical
device evidence as complete.

| ID | Repository outcome | Status |
| --- | --- | --- |
| `P4U-MI2-001` | Customer, vendor and rider use unique random install identifiers stored in platform secure storage | Complete |
| `P4U-MI2-002` | Push permission, token rotation, explicit retry, unregister and exact per-flavor deep-link allowlists | Complete |
| `P4U-MI2-003` | API request telemetry is correlated and privacy-redacted in all three runtimes | Complete |
| `P4U-MI2-004` | Payment UI treats only captured/reconciled backend states as success and safely recovers retry/failure states | Complete |
| `P4U-MI2-005` | Rider task replay is encrypted, ordered, bounded and resumes device sequence after restart | Complete |
| `P4U-MI2-006` | Rider navigation uses validated server coordinates and an explicit external-provider fallback | Complete |
| `P4U-MI2-007` | WebRTC and private-media features fail closed when their protected provider is absent; fabricated signalling/evidence is rejected | Complete |
| `P4U-MI2-008` | Staging smoke authenticates customer, vendor and rider tenants and checks role-owned work/offer surfaces | Complete in source; live run pending |
| `P4U-MI2-009` | Protected Firebase preflight covers 3 apps × 3 environments × 2 platforms; Android plugin activation is config-driven | Complete in source; credentials pending |
| `P4U-MI2-010` | Complete repository gate and 18 current-source native flavor builds | Complete |
| `P4U-MI2-011` | Vendor/rider onboarding accepts only validated private-document, tokenized-bank and approved-zone provider data; release UI fails closed while those providers are absent | Complete in source; providers pending |

### Phase 2 verification evidence

- `dart run melos run verify` passed across all 11 packages and applications.
- All nine Android debug APKs compiled: customer, vendor and rider for
  development, staging and production.
- All nine iOS simulator applications compiled without code signing for the
  same app/flavor matrix.
- Contract hash
  `332ef63e39ef8f7e4dc13a25709b697f288fbb66061f29f73ecf0ee7a8db4b0f`
  remained current.
- `tool/validate_phase2_integrations.dart` is part of the normal repository
  gate and can additionally validate all protected Firebase configuration files
  with `--provider-config-root=/absolute/path`.
- `MOB-P2-XROLE-001` now verifies customer, vendor and rider staging readiness;
  existing `MOB-E2E-004/005/006/007/008` suites cover service, food, vendor,
  rider and Socio/local journeys with deterministic server-authority fixtures.

### Environment-owned gates still required

- Supply the 18 matching Firebase Android/iOS configuration files outside Git,
  APNS keys and provider-console registrations.
- Deploy the paired staging backend and run `MOB-P2-XROLE-001` plus the named
  Android/iOS physical-device E2E suites against controlled role tenants.
- Supply the private media upload/processing adapter and real WebRTC peer/ICE
  provider contract; until then those controls deliberately remain unavailable.
- Run Razorpay/Paystack sandbox callbacks, duplicate webhook, inventory-race,
  settlement-reconciliation, push-delivery and provider-failure drills.
- Complete constrained-device rider battery/background-location measurement and
  the Phase 2 security review. These require external systems or physical
  devices and cannot be manufactured by repository code.

## Phase 3 implementation status

**Status: repository implementation complete; production approval and rollout
remain externally gated.** The source controls cover customer, vendor and rider
equally. Protected credentials, signed distribution, production-equivalent
security/performance evidence, professional language review, store approval and
organizational approvals cannot be created by repository code.

| ID | Repository outcome | Status |
| --- | --- | --- |
| `P4U-MI3-001` | Nine-locale runtime wiring and localized shared role chrome across customer, vendor and rider | Complete in source; professional review required |
| `P4U-MI3-002` | Reduced motion, reading-order focus, semantic announcements, low-bandwidth image opt-in and bounded image decode | Complete |
| `P4U-MI3-003` | Privacy-redacted API/runtime diagnostics and measurable cold-start, image-paint, checkout and notification outcomes | Complete in source; production exporter/dashboards required |
| `P4U-MI3-004` | Android backup/cleartext hardening and fail-closed protected release signing for all three apps | Complete |
| `P4U-MI3-005` | iOS privacy manifests embedded for all three apps plus versioned Android Data Safety declarations | Complete in source; privacy/legal review required |
| `P4U-MI3-006` | Commit-pinned local/source, OSV dependency and Gitleaks security gates | Complete in source; binary/API penetration review required |
| `P4U-MI3-007` | Protected workflow builds signed AAB and IPA candidates, uploads immutable artifacts and attests provenance without automatic publishing | Complete in source; secrets and first signed run required |
| `P4U-MI3-008` | Store metadata, nine-locale release notes and role-specific screenshot capture specification | Complete in source; final capture and store review required |
| `P4U-MI3-009` | Six-stage progressive rollout, minimum sample/observation windows and executable advance/hold/rollback thresholds | Complete |
| `P4U-MI3-010` | Release, rollback, privacy, security, accessibility and performance operating runbooks | Complete |
| `P4U-MI3-011` | Repository Phase 3 validator incorporated into the normal quality gate | Complete |

The controlling evidence and honest release decision are recorded in
`docs/phase-3/PRODUCTION_HARDENING_EXIT_REVIEW.md`.
