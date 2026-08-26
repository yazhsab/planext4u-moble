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

Phase 1 product archaeology and target-definition work is in progress. Application feature coding begins after its inventory and architecture gates are signed off.

- [Six-phase delivery plan](docs/PROGRAM_PLAN.md)
- [Phase 1 discovery status](docs/phase-1/DISCOVERY_STATUS.md)
- [Requirements traceability](docs/phase-1/REQUIREMENTS_TRACEABILITY.md)
- [Screen and flow inventory](docs/phase-1/SCREEN_AND_FLOW_INVENTORY.md)
- [Role and permission matrix](docs/phase-1/ROLE_PERMISSION_MATRIX.md)
- [POC audit runbook](docs/phase-1/POC_AUDIT_RUNBOOK.md)
- [Decision log](docs/phase-1/DECISION_LOG.md)
- [Feature catalogue](docs/FEATURE_CATALOGUE.md)
- [Design-system baseline](docs/DESIGN_SYSTEM_BASELINE.md)
- [Greenfield boundary ADR](docs/adr/0001-greenfield-boundary.md)
- [Backend platform](https://github.com/yazhsab/planext4u-backend)
