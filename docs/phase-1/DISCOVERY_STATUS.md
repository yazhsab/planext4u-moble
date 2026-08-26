# Phase 1 discovery status

- Phase: Product archaeology and target definition
- Planned window: 2026-08-26 to 2026-09-23
- Overall state: Complete
- Greenfield rule: No Lovable/Vercel source code may be inspected, copied, imported or used as a runtime dependency.

## Workstream status

| Workstream | Owner | State | Evidence / next action |
| --- | --- | --- | --- |
| Source hierarchy and greenfield boundary | Product + Architecture | Complete | ADR-0001 accepted |
| Document requirements extraction | Product | Complete | Feature catalogue and 71-ID traceability matrix approved |
| Public POC audit | Product design | Complete | Customer, admin, vendor and rider entry surfaces catalogued |
| Authenticated POC audit | Product design + QA | Complete | 64 admin routes and 39 customer/role surfaces inspected read-only; later role validation is registered |
| Screen and flow inventory | Product design | Complete | Document/POC union approved; state and role validation has named delivery gates |
| Role and permission matrix | Security + Product | Complete | Target matrix and privileged controls approved; denial tests are Phase 2 evidence |
| Visual/design-system baseline | Design | Complete | Tokens, component rules, responsive states and five Figma-importable golden SVGs approved |
| Business-rule conflict resolution | Product | Complete | Twelve defaults accepted in the decision log |
| Service boundaries and state machines | Backend architecture | Complete | Approved in the paired backend exit review |
| Data classification and retention | Security + Legal | Complete for engineering | Release/legal validations remain named gates |
| Capacity, SLO and workload model | Platform | Complete for baseline | Production calibration is a Phase 3 gate |
| Migration/coexistence | Data + Platform | Complete for baseline | Migration stays disabled until authorised Phase 6 exports |
| Phase 2 backlog and test strategy | Product + Engineering | Complete | Estimated stories, dependencies and named acceptance suites published |

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
