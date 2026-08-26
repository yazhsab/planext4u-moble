# ADR-0001: Greenfield boundary

- Status: Accepted
- Date: 2026-08-26

## Decision

Planext4u Mobile will be designed and implemented from scratch. The Lovable/Vercel repository is not a dependency, migration source, package source, or code reference.

Permitted inputs are:

1. Product requirements approved by the product owner.
2. The supplied BRD, PRD, FRD, UI requirements, and technical documentation.
3. Black-box observation of the deployed POC after explicit access approval.
4. Authorised exports of production data and schemas for migration planning.

## Requirement priority

When sources conflict, the following order applies:

1. Explicit product-owner instruction.
2. Updated P4U BRD.
3. PRD and FRD.
4. UI Design Requirements.
5. Technical Documentation.
6. Observed POC behaviour.

The explicit Go microservices requirement therefore supersedes the Node.js references in older documents. No observed POC defect becomes a target requirement unless product explicitly accepts it.

## Consequences

- Behavioural equivalence is proved through traceability and tests, not code reuse.
- All API and data contracts are newly specified and versioned.
- Visual parity is measured with approved screenshots and golden tests.
- Existing data is migrated through reviewed export/transform/import jobs, never through direct coupling to legacy application code.

