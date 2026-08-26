# Feature catalogue

Nothing in this catalogue may be removed without a recorded product decision. Phase 1 converts every line into uniquely identified, testable requirements.

| Domain | Retained capabilities |
| --- | --- |
| Identity | Phone OTP, email/password, Google OAuth, password setup/reset, refresh sessions, multi-role identity, MFA for privileged users, device registry, deactivation and delayed deletion |
| Customer shell | Dynamic splash/onboarding, permissions, GPS/manual location, CMS-driven home, force update, profile completeness, accessibility and localisation |
| Marketplace | Local discovery, search/autocomplete, catalog, variants, inventory, PDP, reviews/Q&A, cart, coupons, delivery scheduling, checkout, returns/refunds, POD and ratings |
| Services | Provider discovery, live availability, schedules, slot locks, booking, advance/full payment, reschedule/cancel, start OTP, completion photo and no-show handling |
| Food | Restaurants, menus, customisation, coupons, order lifecycle, restaurant cut-offs, rider assignment, live tracking, order chat, cancellation/refund and ratings |
| Homes | Rent/Buy/PG/Flatmate, posting, moderation, KYC verification badge, search/maps, galleries, amenities, EMI/value tools, owner chat/call and visit scheduling |
| Classifieds | Posting wizard, five-image limit, geo search, moderation/auto-publish, masking, WhatsApp handoff, reports, expiry, reposting and featured upgrades |
| Socio | Feed, posts, reels, stories/highlights, follows, private profiles, likes/comments/nested replies/shares/saves/collections, mentions/tags, DMs, voice notes, 1:1 calls, commerce stickers, ads, moderation and blocking |
| Wallet and loyalty | Configurable points conversion, FIFO expiry, earn/spend/refill/reversal ledger, referrals, engagement rewards, caps, campaigns, anti-abuse and checkout redemption |
| Vendor | Registration, document OCR, KYC stages, field visit, geo zones, profile, catalog, inventory, schedules, bookings, orders, delivery status, ads/promotions, messaging, recommendations, analytics, settlements, bank verification and franchise support |
| Rider | Registration/KYC, online state, background location, offers/countdown, pickup/navigation, status transitions, customer contact, POD photo/signature/OTP, blur checks, earnings, attendance, acceptance-rate warning and reassignment |
| Communications | Push, email, in-app inbox, WhatsApp, quiet hours, preferences, templates, delivery receipts, contextual support and time-bounded order chat |
| Emergency | Ambulance/first-aid request, consented location, volunteer/field responder assignment, live response tracking, escalation, communications and admin SLA reporting |
| Franchise and field operations | Franchise/KYC registration, territory ownership, sub-admin roles, vendor clusters, field-officer visits/check-ins, delivery workforce, attendance and regional analytics |
| Admin and governance | RBAC/MFA, country switcher, master data, users/vendors/riders/franchises, verification, catalog/content moderation, orders/bookings, wallet, campaigns, CMS, policies, notifications, emergency operations, tickets, feature flags, sessions and immutable audit trail |
| Reports and intelligence | Sales, GST, payments, settlements, customers, vendors, referrals, points, day book, credit notes, exports, geo maps, heatmaps, leaderboards, recommendations and performance analytics |

## Conflict retained as configuration

The updated BRD describes a points-only economy while the PRD/FRD describes points combined with Razorpay/Paystack/COD. The new platform will support administrator-controlled `POINTS_ONLY` and `HYBRID_PAYMENT` modes by country/tenant until product selects the launch policy. This preserves both requirements without hard-coding a contradiction.

