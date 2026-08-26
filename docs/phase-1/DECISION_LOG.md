# Phase 1 decision log

| ID | Decision needed | Proposed default | Owner | Needed by | State |
| --- | --- | --- | --- | --- | --- |
| P4U-DEC-001 | Canonical product domain: `planext4.net` or `planext4u.net` | Use the currently reachable `planext4u.net` until DNS ownership is confirmed | Product + Platform | Phase 1 week 2 | Open |
| P4U-DEC-002 | Repository spelling `planext4u-moble` | Preserve requested name; rename before CI/app-store identifiers if `mobile` was intended | Product | Phase 1 week 1 | Open |
| P4U-DEC-003 | Launch wallet policy | Implement both `POINTS_ONLY` and `HYBRID_PAYMENT`; select per country/tenant | Product + Finance + Legal | Phase 1 week 2 | Open |
| P4U-DEC-004 | New purchase blocked by unconfirmed prior order | Replace global block with configurable risk/policy rule; never block emergencies or support | Product + Ops | Phase 1 week 2 | Open |
| P4U-DEC-005 | Separate apps versus a role-switching binary | Three store apps from one Flutter workspace, matching FRD package separation | Product + Mobile | Phase 1 week 2 | Proposed |
| P4U-DEC-006 | Administrator frontend repository | Keep `admin-web` deployable inside backend monorepo initially; extract later if team cadence requires | Engineering | Phase 1 week 3 | Proposed |
| P4U-DEC-007 | Initial Go service deployment count | Group bounded contexts into 10-12 deployables; split only with scaling/security/cadence evidence | Architecture | Phase 1 week 3 | Proposed |
| P4U-DEC-008 | Emergency-service liability and operating model | Feature flag off until legal disclaimer, responder vetting, escalation and regional SOP are approved | Legal + Ops | Before Phase 5 | Open |
| P4U-DEC-009 | International/country-switcher scope | India is launch country; retain country/tenant configuration for later markets | Product | Phase 1 week 2 | Proposed |
| P4U-DEC-010 | POC data/schema authority | Use authorised exports for migration discovery; never infer production truth solely from UI | Product + Data | Phase 1 week 2 | Proposed |
| P4U-DEC-011 | Auth provider | Firebase Phone Auth for OTP with Go-issued platform tokens unless security/cost review selects alternative | Security + Architecture | Phase 1 week 3 | Proposed |
| P4U-DEC-012 | Admin privileged approval model | MFA/fresh auth plus four-eyes approval for settlements, high-value adjustments and tax changes | Finance + Security | Phase 1 week 3 | Proposed |
