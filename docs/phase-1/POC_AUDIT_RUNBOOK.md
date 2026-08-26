# Deployed POC audit runbook

## Purpose

Create behavioural and visual evidence for parity without inspecting or reusing the Lovable source code. The POC is an untrusted reference; product documents and approved decisions remain authoritative.

## Known entry points

| Surface | URL | Public observation |
| --- | --- | --- |
| Administrator | `https://www.planext4u.net/login` | Admin email/password, customer and vendor entry links, teal branded portal |
| Customer | `https://www.planext4u.net/app/login` | Phone OTP and email/password tabs, registration/reset/policy links |
| Vendor | `https://www.planext4u.net/vendor/login` | Linked from administrator login; authenticated inventory pending |

The product owner also referenced `planext4.net`; DNS/product ownership must be confirmed before canonical-link and deep-link specifications are frozen.

## Safety and privacy

- Do not store credentials, tokens, cookies, API keys or authenticated URLs containing secrets.
- Use only product-owner-provided test accounts.
- Redact names, phones, addresses, KYC, payment and support content from evidence.
- Default to read-only navigation. Do not approve, reject, refund, settle, delete, broadcast, contact users or change configuration during discovery.
- If a state-changing flow cannot be understood without mutation, create a dedicated synthetic record after approval and record cleanup/reversal.
- Do not inspect application source maps, deployed JavaScript bundles, browser storage, network secrets or the legacy repository.

## Evidence record

Each observation records:

```text
Evidence ID:
Date/time and environment:
Role:
Starting URL/route:
Viewport/device:
Preconditions:
Steps:
Observed result:
Fields and validation:
Statuses and next actions:
Loading/empty/error/permission states:
Notifications/side effects:
Export/report behaviour:
Screenshot/video reference (redacted):
Mapped requirement IDs:
Parity decision: Retain / Improve / Product decision / Do not reproduce defect
Notes and open questions:
```

## Audit sequence

1. Inventory navigation, route names, groups, counts and permission visibility for each role.
2. Walk every list/detail/create/edit/approval/report surface without submitting mutations.
3. Capture form fields, defaults, validation, dependent controls, status values and confirmation dialogs.
4. Capture loading, empty, error, offline, expired-session, permission-denied and long-content states.
5. Capture responsive behaviour at 390x844, 430x932, 768x1024, 1366x768 and 1440x900 as applicable.
6. Trace the ten primary journeys listed in the screen inventory using synthetic records where approved.
7. Reconcile observed capabilities against the traceability matrix and create a gap/decision for every mismatch.
8. Review findings with Product, Operations, Finance, Support and Security before design sign-off.

## Completion gate

- No accessible route remains uncatalogued.
- Every navigation item maps to a role, screen and requirement.
- All status values and transition actions have an owner and proposed state machine.
- All reports/filters/exports and configuration fields are documented.
- Visual references cover priority, empty, error and permission states—not only happy paths.
