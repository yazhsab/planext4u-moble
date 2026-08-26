# Deferred validation register

Phase 1 may close with the following bounded validation items because their implementation targets are already defined and their absence does not leave an ambiguous business rule.

| ID | Missing external evidence | Approved baseline | Required validation gate | Owner / latest phase |
| --- | --- | --- | --- | --- |
| `P4U-DV-001` | Authenticated vendor POC account | Documents plus public six-step onboarding and admin supply controls define scope | Validate dashboard/navigation parity with a synthetic vendor before Phase 4 feature acceptance | Product + QA / Phase 4 |
| `P4U-DV-002` | Authenticated rider POC account | FRD/UI plus public registration and admin rider controls define scope | Validate duty/assignment/POD details with a synthetic rider before Phase 4 feature acceptance | Ops + QA / Phase 4 |
| `P4U-DV-003` | Non-super-admin POC accounts | Target permission matrix is authoritative | Run role-denial contract/E2E suite before admin staging release | Security / Phase 2 |
| `P4U-DV-004` | Approved legacy exports/schema | No legacy source or UI inference; migration disabled by default | Inventory authorised exports before Phase 6 migration rehearsal | Data owner / Phase 6 |
| `P4U-DV-005` | Legal emergency operating approval | Emergency feature flag defaults off | Disclaimer, responder vetting, SLA/escalation SOP and regional approval before Phase 5 activation | Legal + Ops / Phase 5 |
| `P4U-DV-006` | Production workload telemetry | Document capacity targets are the sizing baseline | Calibrate arrival rates, payloads and concurrency before Phase 3 load gate | Platform / Phase 3 |
| `P4U-DV-007` | DNS ownership evidence | `planext4u.net` is canonical for contracts | Verify DNS, universal links and app-link ownership before staging deep links | Platform / Phase 2 |

These are executable delivery risks with owners and deadlines, not unresolved Phase 1 product decisions. Any missed latest-phase gate disables the affected rollout or migration; it does not silently relax acceptance criteria.
