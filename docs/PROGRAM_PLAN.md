# Planext4u greenfield delivery plan

## Programme objective

Build production-grade Planext4u customer, vendor, and rider Flutter applications plus a Go microservices platform and web administrator console. The result must preserve every approved POC capability and supplied requirement while removing all source-code and runtime dependency on the Lovable/Vercel implementation.

Indicative duration: 40-48 weeks. Teams may overlap phases only after the preceding architecture and contract gates are approved.

## Phase 1 - Product archaeology and target definition (Weeks 1-4)

### Work

- Black-box audit of customer, vendor, rider, finance, moderator, operations, and administrator journeys in the live POC; capture route, role, field, validation, status, notification, report, export, and error-state evidence.
- Reconcile the Updated BRD, BRD, PRD, FRD, UI requirements, technical document, and POC into a requirements traceability matrix with stable IDs.
- Resolve explicit conflicts: points-only versus hybrid payment, domain name, India-only launch versus country switcher, and administrator-console repository/deployment boundary.
- Produce journey maps, state machines, screen inventory, API inventory, master-data inventory, role/permission matrix, data classification, retention matrix, and migration assessment.
- Recreate the visual system in Figma from approved requirements and black-box observation; do not extract legacy source assets.
- Establish capacity model, SLOs, threat model, DPDP/GST/RBI/KYC obligations, and accessibility/localisation acceptance criteria.

### Outputs

- Approved traceability matrix and feature catalogue.
- Figma foundations/components and golden reference screens.
- Architecture decision records and service boundaries.
- Prioritised backlog with estimates and named acceptance tests.
- Legacy data migration and coexistence strategy.

### Exit gate

Every observed or documented feature is either mapped to a delivery story, explicitly deferred with owner/date, or rejected by a signed product decision. No implementation begins against an ambiguous business rule.

## Phase 2 - Platform foundations and vertical slice (Weeks 5-10)

### Mobile

- Create a Melos Flutter monorepo with customer/vendor/rider apps, dev/staging/prod flavours, shared design-system and generated API-contract packages.
- Implement secure bootstrap, phone/email/OAuth identity, session refresh, role routing, secure storage, device registration, remote configuration, localisation, analytics consent, logging, crash reporting, offline cache, networking/retry/idempotency, and accessibility foundations.
- Deliver widget catalogue, skeleton/empty/error/offline patterns, golden tests, and one end-to-end vertical slice: login -> location -> home -> catalog read.

### Backend and operations

- Bootstrap Go service template, gateway/BFF, identity/profile, configuration/CMS, media, notification, and audit capabilities.
- Establish OpenAPI/AsyncAPI/protobuf contracts, PostgreSQL ownership, migrations, transactional outbox, event bus, Redis, S3/CloudFront, secrets, Terraform, dev/staging/prod AWS accounts, CI/CD, observability, security scanning, and ephemeral test environments.
- Create administrator shell with RBAC, MFA, country/tenant context, navigation, design tokens, and audit visibility.

### Exit gate

The vertical slice deploys automatically to staging, meets authentication/security tests, and emits correlated logs/metrics/traces. Mobile and backend contract tests pass without manual environment changes.

## Phase 3 - Customer commerce and transaction core (Weeks 11-20)

### Scope

- Customer FTUX, permissions, address/geocoding, dynamic home/CMS, local search, categories, vendor discovery, leaderboards, recommendations and help shortcuts.
- Marketplace catalog, PDP media/variants/reviews/Q&A, inventory, cart, promotions, taxes/fees, delivery scheduling and checkout.
- Wallet/loyalty ledger with points-only and hybrid modes, refills, redemption, FIFO expiry, referrals, rewards, caps and anti-abuse.
- Payment orchestration for Razorpay, Paystack and COD where configured; signed webhooks, idempotency, reconciliation, refund and failure recovery.
- Order orchestration, atomic inventory reservation, cancellation, returns, refund, POD, ratings, notifications and customer tracking.
- Admin master data, catalog moderation, orders, payments, wallet, campaigns, CMS, support and the core finance reports.

### Exit gate

First-order journey passes automated E2E tests in staging, including duplicate webhook, stock race, payment retry, partial refund, wallet reversal, notification failure and accessibility scenarios. Checkout success is at least 97% in controlled test runs.

## Phase 4 - Supply, services, food and fulfilment (Weeks 21-30)

### Vendor app

- Registration, OCR document upload, staged KYC, field-officer visit, geo zones, verified badge, profile/catalog/inventory, product and service schedules, order/booking queues, live status, customer messaging, promotions, AI-assisted recommendations, analytics, bank verification and settlements.

### Rider app

- Onboarding/KYC, availability, background location, assignment countdown/acceptance, maps/navigation, pickup/drop/service workflows, chat/call, offline-tolerant status transitions, OTP/photo/signature POD, blur validation, reassignment, attendance, earnings and payout history.

### Verticals and backend

- Service booking locks, availability, reschedule/cancel, start OTP, completion photo and no-show/dispute flows.
- Restaurant/menu/customisation/cart, food order orchestration, restaurant cut-offs, dispatch, live tracking, time-bounded chat and refunds.
- Franchise, field-workforce, routing/dispatch, settlement, attendance and regional operations services.
- Admin supply, KYC, live maps, vendor/rider/franchise operations, settlements and SLA dashboards.

### Exit gate

Product, service and food orders complete end-to-end with live tracking and financially reconciled settlements. Background location, battery consumption, offline recovery and 2 GB Android-device performance meet agreed budgets.

## Phase 5 - Engagement, local verticals and full governance (Weeks 31-40)

### Scope

- Socio feed/ranking, posts, reels, stories/highlights, follows, private profiles, engagement, nested comments, mentions/hashtags, saves/collections, product stickers, sponsored content, DMs, voice notes, presence and WebRTC signalling.
- Media processing for images/video, moderation queues, reporting, block/mute, privacy controls, expiry and content-retention jobs.
- Homes: all listing types, owner KYC, search/maps, galleries, amenities, EMI/value estimation, chat/call, visits, plans, reports and featured upgrades.
- Classifieds: posting wizard, moderation/auto-publish, masked contact, WhatsApp handoff, expiry/repost, reports and featured upgrades.
- Emergency assistance, responder assignment, live map, escalation and SLA reporting.
- Complete administrator console: moderation, communications, policies, configuration, feature flags, audit/session review, country management, all ten finance/ops reports, exports, maps, heatmaps, leaderboards and intelligence dashboards.

### Exit gate

All catalogue requirements have passing acceptance tests; moderation/privacy rules are enforced server-side; media, realtime and reporting soak tests meet their SLOs; no P0/P1 parity gap remains.

## Phase 6 - Production hardening, migration and controlled launch (Weeks 41-48)

### Work

- Full regression across roles, devices, locales, light/dark mode, low bandwidth, offline/reconnect, permissions and account lifecycle.
- Contract, integration, migration-rehearsal, golden, accessibility, security, penetration, dependency, k6 load, soak, chaos and disaster-recovery tests.
- Tune for the documented targets: 1M MAU, 10K concurrent active sessions, API P95 <= 400 ms, 99.9% critical-path availability, mobile cold start <= 2.5 s, image first paint <= 1.2 s, MTTD < 5 min and P1 MTTR < 30 min.
- Rehearse authorised data export/transform/import, media transfer, identifier mapping, wallet and finance reconciliation, and rollback. Run legacy POC and new platform in a time-boxed read-compatible coexistence period.
- Complete DPIA/DPDP controls, GST reports, RBI/payment reviews, KYC policy, app privacy manifests, store signing, release notes, operational runbooks, incident drills, support training and vendor/rider pilot.
- Progressive rollout: internal -> one-city pilot -> 5% -> 25% -> 50% -> 100%, with automatic rollback thresholds.

### Exit gate

Business, engineering, security, finance and operations sign the production-readiness review. Migration reconciles to agreed tolerances, disaster recovery is proven, observability alerts are actionable, and the POC is retired only after rollback window closure.

## Quality policy across all phases

- Definition of done requires unit, integration, contract and role-authorization tests plus analytics, accessibility, localisation, telemetry and rollback coverage.
- API changes are additive within a supported version; breaking changes require migration windows.
- Money, points, stock, settlement and status transitions use server-owned state machines, idempotency keys, immutable ledgers and auditable events.
- Secrets never enter mobile binaries, source control, logs or client-managed configuration.
- Every production mutation has an actor, correlation ID and audit record.
