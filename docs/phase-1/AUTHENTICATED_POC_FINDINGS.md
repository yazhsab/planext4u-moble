# Authenticated POC findings

## Audit record

- Evidence ID: `P4U-POC-AUTH-20260826-01`
- Date: 2026-08-26
- Environment: deployed production POC at `www.planext4u.net`
- Roles exercised: supplied super-administrator account and supplied customer account
- Additional public surfaces: vendor and rider login/registration
- Method: black-box browser inspection only
- Coverage: 64 authenticated administrator routes and 39 customer/role surfaces
- Mutation policy: no create, update, approve, reject, refund, settle, delete, broadcast, upload, payment or contact action was submitted

No credentials, session values, customer records, KYC data, payment data, support content or screenshots containing live personal data were retained.

## Authentication and role entry points

| Role | Route | Observed entry capability | Parity direction |
| --- | --- | --- | --- |
| Administrator | `/login` | Email/password login, customer/vendor portal links; supplied account resolves to Super Admin | Retain role routing; add mandatory privileged MFA and session controls |
| Customer | `/app/login` | Phone OTP with country code, email/password, reset, registration, terms and privacy | Retain both modes; add documented Google OAuth and production abuse controls |
| Vendor | `/vendor/login`, `/vendor/register` | Phone OTP or email/password; six-step Personal/Business/KYC/Bank/Plan/Review registration | Retain as a dedicated app; reconcile with the five-step customer-side seller flow |
| Rider | `/rider/login`, `/rider/register` | Email/password entry and a short public rider registration form | Retain entry concept; build the complete documented KYC, duty and location-consent flow |

The audit did not use vendor or rider credentials, so authenticated vendor/rider dashboard parity remains document-led until dedicated test accounts are supplied.

## Administrator route inventory

| Group | Routes observed | Principal visible capabilities |
| --- | --- | --- |
| Main marketplace | `/dashboard`, `/orders`, `/customers`, `/vendors`, `/cf/vendors`, `/products`, `/admin/services`, `/categories`, `/admin/parent-items`, `/admin/product-attributes` | KPI/trend dashboard, product/service order tabs, status/date filters, CSV export, customer lifecycle tabs, separate product/service vendor approval queues, catalog approvals, category/attribute governance |
| Finance and reports | `/settlements`, `/points`, `/admin/coupons`, `/tax`, `/admin/vendor-plans`, `/reports`, `/report-log` | Settlement ledger, loyalty configuration/history, coupon campaigns/codes/fraud/audit, tax rules, vendor plans, operational reports, GST statutory reports and export-generation log |
| Service configuration | `/cf/city`, `/cf/area`, `/cf/categories`, `/cf/services`, `/cf/products` | City/area/pincode masters, service-category hierarchy, availability/trending flags and service-product catalog controls |
| P4U Homes | `/admin/properties`, `/admin/homes/moderation`, `/admin/localities`, `/admin/property-plans`, `/admin/homes/amenities`, `/admin/homes/users`, `/admin/homes/cms`, `/admin/property-reports` | Property moderation/flags, localities, owner/seeker/assisted plans, amenities/filters, users, CMS and listing/enquiry analytics |
| P4U Social | `/admin/social` | Overview plus Users, Moderation, Hashtags, Audio and Config sections |
| P4U Food | `/admin/restaurants`, `/admin/riders`, `/admin/rider-kyc`, `/admin/rider-settlements`, `/admin/food-orders`, `/admin/food-coupons` | Restaurant/rider entry, rider KYC and settlement queues, food orders and coupons |
| Franchise | `/admin/franchise/plans`, `/admin/franchise/registrations`, `/admin/franchise/active`, `/admin/registration-payments`, `/admin/franchise/projections` | Plans, registration approval and reconciliation, active franchise/payment views, receipts and multi-scale business projections |
| CMS and platform | `/admin/homepage-cms`, `/admin/notifications`, `/admin/media-library`, `/admin/file-uploads`, `/admin/onboarding`, `/occupations`, `/admin/module-visibility`, `/platform-variables`, `/popup-banners`, `/banners`, `/advertisements` | Homepage sections/video ads, segmented push, media/KYC storage views, CSV processing, onboarding content, module flags, ads and campaign metrics |
| Support and governance | `/website-queries`, `/admin/complaints`, `/support-tickets`, `/referrals`, `/classifieds`, `/admin/cms-pages`, `/integrations`, `/admin/dropshipping`, `/admin/vendor-onboarding`, `/admin/splash-screens`, `/settings` | Query/ticket/complaint queues, referrals, classified moderation, CMS/policies, country/gateway/OAuth/KYC/maps integrations, dropshipping, onboarding/splash and general/payment/SEO/security settings |

The administrator navigation exposed 64 unique routes. Destructive and financial action buttons were inventoried but never activated.

## Customer and mobile-role surface inventory

| Area | Routes or entry points observed | Principal visible capabilities |
| --- | --- | --- |
| Public identity | `/app/login`, `/app/register`, `/app/forgot-password`, `/app/terms`, `/app/privacy` | OTP/email login, state/district/occupation registration, location capture, reset and policy pages |
| Launcher and navigation | `/app` | Shop, Socio, Services, Classifieds, Wallet, Emergency, Help and Quick Assist launcher; profile entry |
| Marketplace | `/app/browse`, `/app/product/{id}`, `/app/cart` | Location/search, category list, filters/sort, pagination, sponsored placement, variants, description/specification/review tabs, wishlist/share, add-to-cart and buy actions |
| Services | `/app/services`, `/app/service/{id}` | Category and geo discovery, filters/sort/GPS, provider cards, date/slot selection, booking action, complaint and review entry |
| Food | `/app/food` | Location/search and cuisine/diet filters; route is implemented but absent from the customer launcher and primary navigation |
| Homes | `/app/find-home`, `/app/homes` | Primary navigation labels Find Home as `SOON`; `/app/find-home` is a coming-soon screen and `/app/homes` returns Page Not Found |
| Classifieds | `/app/classifieds`, `/app/classifieds/{id}`, `/app/classifieds/post` | Browse/search, category/location filters, detail, WhatsApp contact, post-ad form and My Ads/Profile navigation |
| Socio | `/app/social`, `/app/social/explore`, `/app/social/reels`, `/app/social/messages`, `/app/social/friends`, `/app/social/notifications`, `/app/social/create`, `/app/social/settings`, `/app/social/profile` | Stories, suggested people, feed engagement, category explore, reels, primary/message requests, friends, notifications, gallery/video/photo/camera composer, preferences and profile controls |
| Account | `/app/profile`, `/app/profile/edit`, `/app/orders`, `/app/wishlist`, `/app/wallet`, `/app/kyc`, `/app/referrals`, `/app/support`, `/app/change-password` | Profile/settings hub, product/service order tabs, saved products/services/sellers, wallet ledger/redeem, KYC, referral share/history, tickets/complaints and password change |
| Seller onboarding | `/app/vendor-register` | Five-step Personal/Business/KYC/Bank/Review flow with state/district dependencies |
| Vendor/rider public onboarding | `/vendor/login`, `/vendor/register`, `/rider/login`, `/rider/register` | Dedicated role entry and registration surfaces |

Emergency, Help and Quick Assist currently navigate to filtered `/app/services` results. No distinct emergency-request, responder-assignment, consent, escalation or SLA workflow was visible in the customer POC.

## Reproducible gaps and defects

| ID | Observation | Target handling |
| --- | --- | --- |
| `P4U-POC-GAP-001` | `/admin/properties` crashes with a runtime error because a select item uses an empty value | Do not reproduce. Add component contract tests and an error-safe property list |
| `P4U-POC-GAP-002` | Homes is labelled `SOON`; `/app/homes` is missing while the admin has extensive Homes controls | Build the complete documented Homes domain; release behind an explicit feature flag |
| `P4U-POC-GAP-003` | `/app/food` exists but is not exposed from the launcher or primary navigation | Preserve Food requirements and decide launch visibility per tenant/country flag |
| `P4U-POC-GAP-004` | Emergency, Help and Quick Assist are category filters rather than complete operational journeys | Implement the documented responder workflow only after legal/operations approval; never copy the shallow POC behaviour as sufficient |
| `P4U-POC-GAP-005` | Customer-side seller onboarding has five steps while the vendor portal registration has six and adds Plan | Define one canonical onboarding state machine with role-specific presentation |
| `P4U-POC-GAP-006` | Privileged admin login showed email/password without an MFA challenge | Require MFA/fresh authentication and four-eyes controls in the target platform |
| `P4U-POC-GAP-007` | Legacy category data visibly contains duplicates, inconsistent casing, test values and unnamed entries | Migrate through governed canonical mappings; do not copy taxonomy defects |
| `P4U-POC-GAP-008` | Some administrator feature pages omit the shared console navigation shell | Provide a consistent responsive admin shell and route-level authorization/error boundaries |

## Requirement reconciliation

- The POC confirms visible breadth for marketplace, services, classifieds, Socio, wallet, customer support, vendor onboarding, Food administration, Homes administration, franchise management, reporting, CMS and integrations.
- Document requirements remain authoritative for unobservable backend invariants, security, accessibility, offline behaviour, scale, data retention, state transitions and complete vendor/rider journeys.
- Feature absence, runtime defects, weak security and inconsistent navigation are recorded as gaps; they are not parity targets.
- Mapped requirement families: `P4U-ID-*`, `P4U-CS-*`, `P4U-MKT-*`, `P4U-WAL-*`, `P4U-ORD-*`, `P4U-SVC-*`, `P4U-FOOD-*`, `P4U-HOME-*`, `P4U-CLS-*`, `P4U-SOC-*`, `P4U-VND-*`, `P4U-RDR-*`, `P4U-EMR-*`, `P4U-FRN-*`, `P4U-ADM-*` and `P4U-RPT-*`.

## Remaining evidence limits

- No state-changing happy-path journey was executed against production.
- No non-super-admin permission comparison was possible.
- No authenticated vendor or rider dashboard account was available.
- No raw production data export or schema was inspected.
- Responsive golden references and accessibility measurements remain Phase 1 design work.
