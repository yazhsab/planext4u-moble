# Planext4u Mobile

Greenfield Flutter workspace for the Planext4u customer, vendor, and rider applications.

This repository is intentionally independent of the Lovable/Vercel proof-of-concept. No source code, generated code, dependencies, or assets will be copied from the legacy repository. The live application may be used only as a black-box behavioural and visual reference after access is authorised.

## Planned applications

- `apps/customer` - marketplace, services, food, Homes, classifieds, Socio, wallet, emergency assistance, and account features.
- `apps/vendor` - onboarding, KYC, catalog, service schedules, orders, inventory, promotions, analytics, settlements, and support.
- `apps/rider` - onboarding, availability, assignments, maps, delivery/service lifecycle, proof of delivery, attendance, and earnings.
- Shared packages - design system, API contracts, authentication, secure storage, media, maps, observability, localisation, and testing.

The administrator console is planned as a separately deployable web workspace under `planext4u-backend/admin-web` so the requested two-repository boundary is preserved. It can be extracted to a dedicated repository later without changing its API contracts.

## Current status

Planning baseline only. Implementation begins after Phase 1 feature inventory and architecture sign-off.

- [Six-phase delivery plan](docs/PROGRAM_PLAN.md)
- [Feature catalogue](docs/FEATURE_CATALOGUE.md)
- [Design-system baseline](docs/DESIGN_SYSTEM_BASELINE.md)
- [Greenfield boundary ADR](docs/adr/0001-greenfield-boundary.md)
- [Backend platform](https://github.com/yazhsab/planext4u-backend)
