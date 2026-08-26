# Requirements traceability matrix v0.1

## Source codes

| Code | Source |
| --- | --- |
| UBRD | Updated P4U BRD |
| BRD | P4U Business Requirements Document v2.0 |
| PRD | P4U Product Requirements Document v2.0 |
| FRD | P4U Functional Requirements Document v2.0 |
| UI | P4U UI Design Requirements v1.0 |
| TECH | P4U Technical Documentation v2.0 |
| POC | Deployed POC black-box observation |
| OWNER | Explicit product-owner instruction |

`Status` is `Specified`, `Audit pending`, `Decision pending` or `Approved`. No row may be deleted; superseded requirements remain linked to their decision record.

## Identity and customer shell

| ID | Requirement | Actor | Source | Acceptance baseline | Status |
| --- | --- | --- | --- | --- | --- |
| P4U-ID-001 | Phone OTP registration and login | All mobile roles | PRD, FRD, UBRD | Rate-limited OTP, verified provider token, platform session, recovery and audit | Specified |
| P4U-ID-002 | Email/password login and password setup/reset | All | FRD, POC | Secure password policy, expiring reset, session/device audit and generic enumeration-safe errors | Audit pending |
| P4U-ID-003 | Google OAuth | Customer | FRD, UI | System-browser OAuth, PKCE/deep link, role-safe account linking | Specified |
| P4U-ID-004 | Multi-role identity and portal routing | Customer, Vendor, Rider, Admin | FRD, TECH | One auth identity, dedicated roles, least-privilege routing and server authorisation | Audit pending |
| P4U-ID-005 | Privileged MFA and fresh reauthentication | Admin, Finance | UBRD, TECH | MFA plus reauth for settlement/KYC/security actions with auditable failure/lockout | Specified |
| P4U-ID-006 | Deactivation and 30-day deletion | Customer, Vendor | FRD, PRD | Soft deactivation, grace period, cancellation, export/retention handling and audit | Specified |
| P4U-CS-001 | Dynamic splash and onboarding | Customer | FRD, UI | CMS content, 1.2 s target, skip/progress, offline fallback and first-run persistence | Specified |
| P4U-CS-002 | Permission education and capture | Customer | FRD, UI | Location/notification/contacts rationale, deny/retry/settings paths and consent evidence | Specified |
| P4U-CS-003 | GPS/manual location and addresses | Customer | PRD, FRD | GPS and pincode fallback, geocoding, serviceability, saved addresses and checkout requirement | Specified |
| P4U-CS-004 | CMS-driven personalised home | Customer | FRD, UBRD, UI | Ordered widgets, banners/deep links, categories, rails, wallet, ads, leaderboards and cache fallback | Audit pending |
| P4U-CS-005 | Force update and remote configuration | All apps | FRD, TECH | Minimum version, optional/mandatory update, country/tenant feature flags and safe defaults | Specified |
| P4U-CS-006 | Accessibility, dark mode and nine languages | All | PRD, UI, TECH | WCAG AA, semantics, 130% text, reduced motion, light/dark and EN plus eight Indian locales | Specified |

## Marketplace, wallet and orders

| ID | Requirement | Actor | Source | Acceptance baseline | Status |
| --- | --- | --- | --- | --- | --- |
| P4U-MKT-001 | Local-first discovery and search | Customer | BRD, PRD, FRD, UBRD | Geo ranking, autocomplete, filters, recent/trending, vendor/service/product/tag results and pagination | Specified |
| P4U-MKT-002 | Catalog and PDP | Customer | PRD, FRD, UI, UBRD | Media zoom, variants, server stock/price, delivery estimate, trust, descriptions, reviews, Q&A and related items | Audit pending |
| P4U-MKT-003 | Cart and price revalidation | Customer | FRD, UI | Persistent cart, variant/quantity control, vendor grouping, server reprice and stale-price warning | Specified |
| P4U-MKT-004 | Promotion and fee rule engine | Customer, Vendor, Admin | BRD, FRD | Min/max rules, exclusivity/stacking, caps, bearer allocation, server time and audit | Specified |
| P4U-MKT-005 | Checkout and scheduled delivery | Customer | PRD, FRD, UI, UBRD | Address, schedule, coupon, wallet, itemised total, terms, idempotent place-order and failure retry | Audit pending |
| P4U-PAY-001 | Razorpay/Paystack/COD orchestration | Customer, Finance | PRD, FRD, TECH | Server order creation, signature/webhook verification, idempotency, reconciliation and country configuration | Specified |
| P4U-WAL-001 | Immutable wallet ledger | Customer, Admin | BRD, FRD, UBRD | Earn/spend/refill/reversal, timestamp/category/source, atomic balance and reconciliation | Specified |
| P4U-WAL-002 | FIFO expiry, referrals and rewards | Customer, Admin | BRD, FRD | Oldest-first expiry, original-expiry refunds, first-purchase referral and configured event rewards | Specified |
| P4U-WAL-003 | Points-only and hybrid modes | Customer, Admin | UBRD, PRD, FRD | Country/tenant policy supports both modes; no client-authoritative conversion or balance | Decision pending |
| P4U-WAL-004 | Engagement anti-abuse | Customer, Admin | UBRD | Visibility/duration proof, daily/device caps, cooldown, risk flags and manual-review audit | Specified |
| P4U-ORD-001 | Product order lifecycle | Customer, Vendor, Rider | FRD, UI, UBRD | Placed through delivered/cancelled/returned with allowed transitions, timestamps and next actions | Audit pending |
| P4U-ORD-002 | Atomic inventory and payment recovery | Platform | FRD, TECH | Reservation/concurrency control, payment saga, expiry/release and duplicate command safety | Specified |
| P4U-ORD-003 | Cancellation, return and partial refund | Customer, Vendor, Finance | FRD | Policy gate, partial-line support, original/wallet refund, ledger links and notifications | Specified |
| P4U-ORD-004 | Live tracking and communications | Customer, Vendor, Rider | FRD, UI, UBRD | Map/ETA, 10-30 s updates, timeline, consent, chat/call/WhatsApp and graceful stale-location state | Audit pending |
| P4U-ORD-005 | POD and completion/rating | Customer, Rider | FRD, UI, UBRD | Photo, recipient/signature/OTP policy, customer confirmation, verified review and reward event | Decision pending |

## Services and food

| ID | Requirement | Actor | Source | Acceptance baseline | Status |
| --- | --- | --- | --- | --- | --- |
| P4U-SVC-001 | Service discovery and provider trust | Customer | FRD, UI, UBRD | Geo filters, verified vendor, category, rating, completed count, live engagement and next slot | Audit pending |
| P4U-SVC-002 | Weekly availability and slot locking | Vendor, Customer | FRD, UBRD | Daily/weekly schedule, buffer/capacity, no overlap, live booking lock and timezone safety | Specified |
| P4U-SVC-003 | Booking/payment/reschedule/cancel | Customer, Vendor | FRD, UBRD | Full/advance payment, one free reschedule policy, mandatory change reason and notifications | Specified |
| P4U-SVC-004 | Start/completion/no-show evidence | Vendor, Customer | FRD | Start OTP, completion photo, no-show claim, dispute trail and verified review | Specified |
| P4U-FOOD-001 | Restaurant discovery and menu | Customer | FRD, UI | Geo discovery, availability/cut-off, categories, customisation, dietary labels and cart pricing | Audit pending |
| P4U-FOOD-002 | Food order and restaurant queue | Customer, Restaurant | FRD, UI | Coupon/payment, accept/reject, preparation/ready stages, auto-cancel/refund and customer updates | Audit pending |
| P4U-FOOD-003 | Food dispatch/tracking/chat | Customer, Rider | FRD, UI | Assignment, 10 s location target, stage timeline, ETA and chat expiry one hour after delivery | Specified |

## Homes, classifieds and Socio

| ID | Requirement | Actor | Source | Acceptance baseline | Status |
| --- | --- | --- | --- | --- | --- |
| P4U-HOME-001 | Rent/Buy/PG/Flatmate listings | Owner, Broker, Seeker | PRD, FRD | Posting, media, locality, amenities, moderation, status/expiry and search/map filters | Specified |
| P4U-HOME-002 | Verification and duplicate/spam controls | Owner, Admin | FRD | KYC badge, duplicate phone/property signals, moderation evidence and appeal | Specified |
| P4U-HOME-003 | Inquiry, visit and owner contact | Seeker, Owner | FRD, UI | Chat/call, scheduled visit, consent/privacy, lead status and reminders | Specified |
| P4U-HOME-004 | EMI, value and locality intelligence | Seeker, Admin | PRD, FRD, UI | Server/approved formulas, transparent assumptions, price trends and nightly reports | Specified |
| P4U-CLS-001 | Classified posting and moderation | Seller, Admin | PRD, FRD, UI | Four-step wizard, 5-image/length limits, low-risk auto-publish and prohibited-content rejection | Specified |
| P4U-CLS-002 | Classified discovery/contact/lifecycle | Buyer, Seller | FRD, UI | City/category search, masking, WhatsApp, reporting, 60-day expiry and three free reposts | Specified |
| P4U-SOC-001 | Profiles, follows and privacy | Creator, Viewer | FRD, UI, UBRD | Public/private, follow/unfollow, counts, grid/reels/tagged, block/mute and access enforcement | Audit pending |
| P4U-SOC-002 | Feed, posts and commerce tags | Creator, Viewer, Vendor | PRD, FRD, UBRD | Cursor feed, images/video/polls, up to 5 media, tags/stickers, visibility and ad injection | Audit pending |
| P4U-SOC-003 | Engagement and moderation | Viewer, Moderator | FRD, UBRD | Like, nested comments <= 3, share/save/collections, report categories, thresholds, decision/appeal | Audit pending |
| P4U-SOC-004 | Stories, highlights and reels | Creator, Viewer | FRD, UI, UBRD | 24 h expiry, progress/navigation, seen state, video limits, highlights and vertical-snap reels | Audit pending |
| P4U-SOC-005 | DMs, voice notes and 1:1 calls | User, Vendor | FRD, UI | Mutual-follow policy, requests, text/media/location, 60 s voice, presence, WebRTC signalling and blocks | Audit pending |
| P4U-SOC-006 | Sponsored content and creator rewards | Vendor, Creator, Admin | BRD, UBRD | Labelled placements, targeting, impression/click/conversion proof, caps and wallet reward events | Specified |

## Vendor, rider, emergency and administration

| ID | Requirement | Actor | Source | Acceptance baseline | Status |
| --- | --- | --- | --- | --- | --- |
| P4U-VND-001 | Vendor registration, OCR and staged KYC | Vendor, Field Officer, Admin | FRD, UBRD | Phone/email, business data, private docs, OCR review, staged notifications and decision reasons | Audit pending |
| P4U-VND-002 | Field visit and geo service zones | Vendor, Field Officer | UBRD | Scheduling/reschedule, officer identity, geo check-in, map/pincode/radius zones and audit | Specified |
| P4U-VND-003 | Vendor dashboard and dynamic actions | Vendor | UI, UBRD | Sales/orders/inventory/points, verification progress, role-based quick actions, alerts and offline snapshot | Audit pending |
| P4U-VND-004 | Catalog, inventory and order queues | Vendor | PRD, FRD, UI | Product/service CRUD, SKU/stock, approval, order tabs, safe transitions and customer updates | Audit pending |
| P4U-VND-005 | Promotions, recommendations and analytics | Vendor | BRD, UBRD | Campaigns, sponsored posts, trends, low stock, actionable suggestions and sales/engagement reports | Specified |
| P4U-VND-006 | Bank verification and settlements | Vendor, Finance | FRD, UI | Verified bank before payout, itemised statements, cooling period, PDF/export and dispute trail | Audit pending |
| P4U-RDR-001 | Rider onboarding, KYC and online duty | Rider | FRD, UI | Secure login, docs/bank, online state, clock in/out, consent and background-location policy | Audit pending |
| P4U-RDR-002 | Offer, acceptance and reassignment | Rider, Dispatch | FRD, UI | Pickup/drop/distance/payout, countdown, atomic acceptance, <70% warning and GPS-loss reassignment | Specified |
| P4U-RDR-003 | Active task and POD | Rider | FRD, UI | Navigation, contact, stage actions, offline queue, OTP/photo/signature, blur check and immutable completion | Audit pending |
| P4U-RDR-004 | Earnings, attendance and performance | Rider, Finance, Admin | FRD, UBRD | Daily ledger, weekly settlement, hours/idle/task history, disputes and performance analytics | Specified |
| P4U-EMR-001 | Emergency request and consented location | Customer | UBRD | Ambulance/first-aid request, clear emergency disclaimer, consent, location and status/communication | Specified |
| P4U-EMR-002 | Responder assignment and SLA monitoring | Volunteer, Admin | UBRD | Skills/availability match, assignment, live tracking, escalation, completion and response-time audit | Specified |
| P4U-FRN-001 | Franchise registration and regional oversight | Franchise, Admin | UBRD | Legal/KYC, territory, sub-admin, vendor/rider clusters, scoped data and performance | Specified |
| P4U-ADM-001 | Admin RBAC, MFA and country context | Admin roles | FRD, UI, UBRD | Least privilege, country/currency/tax/gateway context, fresh auth and session/audit review | Audit pending |
| P4U-ADM-002 | Master data and entity governance | Admin, Ops | FRD | CRUD/approval for categories/attributes/occupations/users/vendors/riders with dependent-delete blocks | Audit pending |
| P4U-ADM-003 | Moderation, CMS and policies | Moderator, Admin | FRD, UBRD | Queues, decisions/reasons/appeals, banners/layouts/splash, policy versions and feature flags | Audit pending |
| P4U-ADM-004 | Notifications, tickets and emergency operations | Support, Admin | FRD, UBRD | Segmented broadcasts, templates, receipts, ticket assignment/SLA and emergency command view | Audit pending |
| P4U-RPT-001 | Ten finance/operations report families | Finance, Ops | FRD | Server pagination, date/country/vendor filters, sanitised CSV/XLSX/PDF, queued large export and audit | Audit pending |
| P4U-RPT-002 | Maps, heatmaps, leaderboards and intelligence | Admin, Vendor | UBRD | Geo clusters, zone demand, engagement/availability, performance scores and explainable recommendations | Specified |

## Non-functional and release requirements

| ID | Requirement | Source | Acceptance baseline | Status |
| --- | --- | --- | --- | --- |
| P4U-NFR-001 | Scale and latency | PRD, TECH | 1M MAU, 10K concurrent active sessions and API P95 <= 400 ms with endpoint budgets | Specified |
| P4U-NFR-002 | Availability and recovery | PRD, TECH | 99.9% critical paths, MTTD < 5 min and P1 MTTR < 30 min | Specified |
| P4U-NFR-003 | Mobile performance | BRD, PRD | 2 GB Android support, cold start <= 2.5 s and image first paint <= 1.2 s on agreed device/network | Specified |
| P4U-NFR-004 | Security/privacy/compliance | BRD, PRD, TECH | DPDP/GST/RBI/KYC controls, TLS, encryption, least privilege, audit, retention and tested deletion | Specified |
| P4U-NFR-005 | Observability and controlled rollout | PRD, TECH | Correlated logs/metrics/traces, actionable alerts, SLO burn rates, canary/rollback and runbooks | Specified |
| P4U-NFR-006 | No legacy source reuse | OWNER | Independent implementation, new contracts/assets and export-based migration only | Approved |
