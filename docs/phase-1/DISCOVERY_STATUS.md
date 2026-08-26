# Phase 1 discovery status

- Phase: Product archaeology and target definition
- Planned window: 2026-08-26 to 2026-09-23
- Overall state: In progress
- Greenfield rule: No Lovable/Vercel source code may be inspected, copied, imported or used as a runtime dependency.

## Workstream status

| Workstream | Owner | State | Evidence / next action |
| --- | --- | --- | --- |
| Source hierarchy and greenfield boundary | Product + Architecture | Complete | ADR-0001 accepted |
| Document requirements extraction | Product | Baseline complete | Feature catalogue and traceability v0.1 created |
| Public POC audit | Product design | Complete | Customer, admin, vendor and rider entry surfaces catalogued |
| Authenticated POC audit | Product design + QA | Baseline complete | 64 admin routes and 39 customer/role surfaces inspected read-only; mutation journeys excluded |
| Screen and flow inventory | Product design | Baseline complete | Document inventory reconciled with authenticated POC findings; golden references pending |
| Role and permission matrix | Security + Product | In progress | Super Admin and customer visibility observed; scoped admin/vendor/rider accounts pending |
| Visual/design-system baseline | Design | Baseline complete | Document tokens captured; Figma and golden references pending |
| Business-rule conflict resolution | Product | In progress | Points-only/hybrid proposal recorded; product decision pending |
| Service boundaries and state machines | Backend architecture | Baseline complete | Initial bounded contexts/state machines documented; approval pending |
| Data classification and retention | Security + Legal | Baseline complete | Draft classification/retention matrix documented; approval pending |
| Capacity, SLO and workload model | Platform | Baseline complete | Document baselines captured; production workload inputs pending |
| Migration/coexistence | Data + Platform | Baseline complete | Export-first/no-code-coupling strategy documented; authorised export inventory pending |
| Figma foundations and golden screens | Design | Ready to start | Authenticated visual inventory is available; sanitised priority references pending |

## Evidence rules

- Every requirement receives a stable `P4U-*` identifier.
- Every POC observation records role, URL/route, viewport, precondition, action, result, screenshot reference, API/error observation when visible, and parity decision.
- Credentials, tokens, private customer data and raw KYC/payment data must never enter this repository.
- Read-only inspection is the default. Any state-changing test uses dedicated test records and an approved cleanup plan.
- A POC defect is evidence, not a target requirement, unless Product explicitly accepts it.

## Phase 1 exit criteria

- All supplied requirements and authenticated POC capabilities map to stable IDs.
- Screen, report, export, notification, role, field, validation and state-transition inventories are complete.
- Open conflicts have an owner, due date and documented default.
- Figma foundations and priority-flow references are approved.
- Go service boundaries, API/event strategy, data ownership and migration approach are approved.
- Capacity model, SLOs, threat model, compliance controls and test strategy are signed off.
- Phase 2 backlog has estimates, dependencies and executable acceptance tests.
