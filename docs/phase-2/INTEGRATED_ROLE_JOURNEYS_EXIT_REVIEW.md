# Integrated role journeys — Phase 2 exit review

Date: 2026-08-30

This review applies to Phase 2 of `THREE_PHASE_MOBILE_IMPLEMENTATION_PLAN.md`,
not the earlier foundation milestone that also used the name “Phase 2”.

## Decision

The repository-owned implementation is complete for customer, vendor and
rider/driver across development, staging and production. Deployment acceptance
remains open until protected provider configuration, a deployed paired backend
and physical devices are available.

## Role and flavor coverage

| Application | Development | Staging | Production | Android | iOS |
| --- | --- | --- | --- | --- | --- |
| Customer | Pass | Pass | Pass | 3 APKs compiled | 3 simulator apps compiled |
| Vendor | Pass | Pass | Pass | 3 APKs compiled | 3 simulator apps compiled |
| Rider/driver | Pass | Pass | Pass | 3 APKs compiled | 3 simulator apps compiled |

“Driver” is implemented as the independently distributed rider application and
uses the `RIDER` backend role, `net.planext4u.rider*` app identities and
`/rider` route boundary.

## Implemented controls

- Secure random per-install IDs replace shared static device identifiers.
- Push state exposes denied, registering, registered and unavailable outcomes;
  registration can retry without waiting for token rotation.
- HTTPS and custom-scheme deep links use exact environment-owned allowlists.
- Customer, vendor and rider API traffic emits correlated, redacted operational
  diagnostics without enabling analytics or crash payload collection by
  default.
- Payments remain pending until the backend reports `CAPTURED` or `RECONCILED`;
  terminal failures and cancellations can no longer render as success.
- Rider offline task commands are encrypted, ordered, validated, capped at 100
  and continue their monotonic device sequence after process restart.
- Rider maps launch only from server-supplied validated coordinates and fall
  back to a privacy-safe task summary if the provider cannot open.
- WebRTC creation requires a real platform offer provider; the former fabricated
  offer path is removed and the user sees an unavailable state when no provider
  is installed.
- Vendor and rider onboarding no longer submits placeholder KYC, service-zone
  or banking material. Domain validation requires private asset references,
  tokenized bank references, mandatory document types and approved rider zones;
  the release UI remains unavailable until the corresponding provider adapters
  are installed.
- The source gate validates Firebase build wiring, APNS entitlements, provider
  boundaries, payment authority, role contracts and prohibited fake runtime
  material.

## Evidence

- Workspace gate: `dart run melos run verify` — pass.
- Native compilation: 9 Android debug APKs + 9 iOS simulator applications —
  pass.
- Flavor/config validation: `dart run tool/validate_flavors.dart` — pass.
- Phase 2 integration validation:
  `dart run tool/validate_phase2_integrations.dart` — pass in source mode.
- Cross-role staging workflow: `MOB-P2-XROLE-001` implemented for customer,
  vendor and rider readiness.

## External acceptance gates

The following are not represented as passed because the required external state
is absent from the workspace:

1. Protected Firebase/APNS configuration for every app/flavor/platform.
2. Deployed staging backend and provisioned customer/vendor/rider tenants.
3. Private media upload/scan/moderation service and WebRTC peer/ICE adapter.
4. Razorpay/Paystack sandbox merchant callbacks and duplicate-webhook evidence.
5. Android and iOS physical-device E2E, rider background/battery measurements,
   provider failure drills and the Phase 2 security review.

Run the protected configuration gate before a credentialed build:

```sh
dart run tool/validate_phase2_integrations.dart \
  --provider-config-root=/absolute/path/to/protected/mobile-config
```

The expected protected layout is
`<root>/<customer|vendor|rider>/<development|staging|production>/` containing
`google-services.json` and `GoogleService-Info.plist`. The files must never be
committed to this repository.
