# Phase 1 decision log

| ID | Decision needed | Proposed default | Owner | Needed by | State |
| --- | --- | --- | --- | --- | --- |
| P4U-DEC-001 | Canonical product domain: `planext4.net` or `planext4u.net` | Use `planext4u.net`; DNS ownership validation remains a deployment check | Product + Platform | 2026-08-26 | Accepted |
| P4U-DEC-002 | Repository spelling `planext4u-moble` | Preserve the explicitly requested repository name; use correctly spelled package/bundle identifiers | Product | 2026-08-26 | Accepted |
| P4U-DEC-003 | Launch wallet policy | Implement both `POINTS_ONLY` and `HYBRID_PAYMENT`; select per country/tenant | Product + Finance + Legal | 2026-08-26 | Accepted |
| P4U-DEC-004 | New purchase blocked by unconfirmed prior order | Replace global block with a configurable risk/policy rule; never block emergencies or support | Product + Ops | 2026-08-26 | Accepted |
| P4U-DEC-005 | Separate apps versus a role-switching binary | Three store apps from one Flutter workspace, matching FRD package separation | Product + Mobile | 2026-08-26 | Accepted |
| P4U-DEC-006 | Administrator frontend repository | Keep `admin-web` deployable inside the backend monorepo initially; extract only with cadence evidence | Engineering | 2026-08-26 | Accepted |
| P4U-DEC-007 | Initial Go service deployment count | Start with 12 deployable groups; split only with scaling/security/cadence evidence | Architecture | 2026-08-26 | Accepted |
| P4U-DEC-008 | Emergency-service liability and operating model | Feature flag off until disclaimer, responder vetting, escalation and regional SOP are legally approved | Legal + Ops | 2026-08-26 | Accepted with release gate |
| P4U-DEC-009 | International/country-switcher scope | India is the launch country; retain country/tenant configuration for later markets | Product | 2026-08-26 | Accepted |
| P4U-DEC-010 | POC data/schema authority | Authorised exports are the only migration evidence; never infer production truth solely from the UI | Product + Data | 2026-08-26 | Accepted |
| P4U-DEC-011 | Auth provider | Firebase Phone Auth for OTP with Go-issued platform tokens, subject to Phase 2 cost/security spike | Security + Architecture | 2026-08-26 | Accepted with validation spike |
| P4U-DEC-012 | Admin privileged approval model | MFA/fresh auth plus four-eyes approval for settlements, high-value adjustments and tax changes | Finance + Security | 2026-08-26 | Accepted |

## Approval basis

The product owner directed completion of Phase 1 on 2026-08-26. The proposed defaults were therefore adopted as the unambiguous engineering baseline. “Accepted with release gate” does not claim external legal certification; it means implementation may proceed while the feature remains disabled until the named release evidence exists.
