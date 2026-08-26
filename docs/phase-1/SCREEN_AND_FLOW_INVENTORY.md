# Screen and flow inventory v0.1

Status legend: `D` documented, `P` publicly observed, `A` authenticated audit pending, `G` golden reference pending.

## Customer application

| Area | Screens / flows | Evidence |
| --- | --- | --- |
| Bootstrap | Dynamic splash, 3-step onboarding, permissions, update gate, maintenance/offline | D, A, G |
| Authentication | Phone OTP, email/password, Google OAuth, OTP verify, password setup/reset, role recovery, deletion/deactivation | D, P, A, G |
| Location | GPS prompt, manual city/pincode, address list, add/edit/map pin, serviceability failure | D, A, G |
| Home | Location/search app bar, banner carousel, categories, quick-access tiles, product/service rails, wallet strip, floating ad, leaderboard, featured vendors, recommendations, emergency/help shortcuts | D, A, G |
| Search/browse | Search overlay, autocomplete groups, recent/trending, product/service/vendor/tag results, filters/sort, infinite list, empty/offline states | D, A, G |
| Product | PDP gallery/zoom, variants, price/offers, stock/delivery, trust, description, reviews, Q&A, related items, share/wishlist | D, A, G |
| Cart/checkout | Cart, swipe remove, coupon, wallet, address sheet, delivery schedule, payment groups, terms/confirm, failure/retry, success | D, A, G |
| Orders | Active/past list, detail, tracking map/timeline, rider/contact, cancellation/return/refund, completion/POD, rating/review, issue/support | D, A, G |
| Services | Categories/list, detail/vendor, availability/day/slot, booking summary/payment, active tracking, reschedule/cancel, completion/rating | D, A, G |
| Food | Restaurants/filter, restaurant/menu, item customisation sheet, food cart/coupon/checkout, tracking/chat, completion/rating | D, A, G |
| Homes | Listing/search/map/filter, property card, detail/gallery/specs/amenities, EMI/value, owner contact, schedule visit, post/manage listing, plans/reports | D, A, G |
| Classifieds | Category/grid/search, detail/contact/report, four-step post-ad wizard, manage/repost/feature | D, A, G |
| Socio | Feed, composer, comments, explore/search, stories tray/viewer/create, reels, profile tabs, follows, collections, DMs, message requests, chat, voice note, call | D, A, G |
| Wallet/rewards | Balance/ledger filters, earn content, refill, campaigns, referral/share, adjustment/reversal detail | D, A, G |
| Notifications/support | Notification centre/preferences, WhatsApp opt-in, help centre, contextual ticket/chat/call, emergency request/tracking | D, A, G |
| Profile/settings | Profile/edit/completeness, addresses, wishlist/saves, orders, wallet, referrals, privacy/security, language/theme/accessibility, policies, account controls | D, A, G |

## Vendor application

| Area | Screens / flows | Evidence |
| --- | --- | --- |
| Authentication/onboarding | Login/register, business information, category application, OCR document capture/review, KYC timeline, field visit schedule/reschedule, rejection/resubmit | D, A, G |
| Dashboard | Profile/language/notifications, KPI snapshot, verification banner, dynamic quick actions, alerts, recommendations, bottom navigation | D, A, G |
| Business | Profile, locations/zones, operating hours, bank accounts, policies, subscription/feature access | D, A, G |
| Catalog | Product/service tabs, list/filter, add/edit media/variants/SKU/stock/schedule, approval/rejection, Q&A | D, A, G |
| Operations | New/preparing/ready/completed orders, service bookings, accept/reject/reschedule/cancel, live status, delivery handoff and disputes | D, A, G |
| Inventory | Inventory list, adjustments, bulk updates, low-stock alerts and audit | D, A, G |
| Promotions/Socio | Campaigns, banners, sponsored posts, VIP listings, audience/period/budget, performance | D, A, G |
| Analytics | Daily/weekly/monthly sales, products/services, engagement, trends, recommendations, exports | D, A, G |
| Finance | Payments, commission, statements, settlements, invoices, payout bank and support/dispute | D, A, G |
| Communication | Customer/order chat, franchise support, notifications and announcements | D, A, G |

## Rider application

| Area | Screens / flows | Evidence |
| --- | --- | --- |
| Onboarding | Login, profile/KYC, bank, permissions, location-consent and duty policy | D, A, G |
| Duty | Online/clock-in toggle, shift/attendance, permission/GPS failure and break/offline | D, A, G |
| Assignment | Offer card/countdown, pickup/drop, distance/payout, accept/decline, concurrent acceptance and reassignment | D, A, G |
| Active task | Full-screen map, route/stop detail, contact, arrived/picked/preparing/delivering states, failure/escalation | D, A, G |
| Completion | OTP, photo framing/blur/retake, signature, recipient and immutable success | D, A, G |
| Earnings | Today/week totals, task ledger, incentives, adjustments, weekly payout and dispute | D, A, G |
| History/profile | Delivery/service history, performance/acceptance rate, attendance, notifications, profile/settings/support | D, A, G |

## Administrator console

| Group | Screens / flows | Evidence |
| --- | --- | --- |
| Access | Login/MFA, password reset, session lock, role/permission management, country switcher | D, P, A, G |
| Command centre | KPI/trend/split cards, actionable queues, system alerts and country/date filters | D, A, G |
| Identity/supply | Customers, vendors, applications, service providers, riders, franchises, field officers, KYC, bank and zones | D, A, G |
| Commerce | Categories/attributes, products/services, inventory, orders/bookings/food orders, returns/refunds and reviews/Q&A | D, A, G |
| Finance | Payments, wallet, referrals, rewards, commissions, settlements, invoices, credit notes, tax/GST and reconciliation | D, A, G |
| Content/growth | CMS layouts, splash/onboarding, banners/video ads, campaigns/coupons, sponsored posts, leaderboards and recommendations | D, A, G |
| Verticals | Restaurants/menus, Homes/localities/amenities/plans/reports, classifieds/categories/reports and emergency operations | D, A, G |
| Socio/trust | Profiles, posts/reels/stories/comments, reports, moderation queues, decisions, blocks and appeals | D, A, G |
| Communications | Notification templates/broadcasts/receipts, WhatsApp, email, in-app inbox, support tickets and policies | D, A, G |
| Operations maps | Vendor/franchise clusters, rider/agent live map, assignments, attendance, delays, heatmaps and field visits | D, A, G |
| Reports | Sales, GST GSTR-1/3B/9, payments, settlements, customers, vendors, referrals, points, day book and credit notes | D, A, G |
| Governance | Feature flags, countries/currencies/tax/gateways, platform variables, sessions, audit logs, exports and retention jobs | D, A, G |

## Primary journey evidence sets

1. First customer order from clean install through POD and review.
2. Vendor onboarding through approval, catalog submission and first settlement.
3. Rider duty through assignment, offline recovery, POD and earnings.
4. Service booking through start OTP, completion photo and review.
5. Food order through restaurant queue, dispatch and chat expiry.
6. Socio post/reel/story with product tag, DM, report and moderation.
7. Homes listing through moderation, inquiry and scheduled visit.
8. Classified ad through publish, contact, report, expiry and repost.
9. Emergency request through responder assignment and SLA closure.
10. Finance reconciliation and all report/export families.
