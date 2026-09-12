# Mobile release and rollback runbook

## Release invariant

Every production candidate is role-specific, signed in the protected
role-specific `production-customer`, `production-vendor` or `production-rider`
GitHub environment and generated from a reviewed `main` commit. The
workflow builds both the Android App Bundle and iOS IPA, uploads an immutable
30-day candidate artifact and attaches build-provenance attestations. It does
not publish to Google Play or App Store Connect.

## Protected environment inputs

The release manager configures the following secrets separately for the
selected customer, vendor or rider environment:

- Android keystore, store password, key alias and key password.
- Apple distribution certificate, certificate password, provisioning profile,
  export-options plist and development team identifier.
- Android and iOS Firebase production configuration matching the selected
  production package/bundle identifier.

Each role environment also needs the public `MOBILE_API_BASE_URL` variable and
`MOBILE_SIGNING_ROTATION_APPROVED=true` after the signing owner records retirement
or store-authorized reset of the historically exposed credentials. Setting the
variable is an owner attestation; it does not perform key rotation. Do not delete
or replace a published application's signing identity outside the store owner's
approved reset/rotation procedure. Do not reuse historical repository keystores.

The workflow validates input structure with `tool/validate_release_inputs.dart`,
passes version/build values as quoted shell variables and checks the provisioning
profile team and exact role application identifier. No role falls back to shared
`production` secrets. Protect each named environment and restrict it to `main`
before running a signed candidate. Store build numbers must also be checked
against the latest uploaded version; local validation cannot prove monotonicity.

Credentials are decoded only into the ephemeral runner, validated before the
build and removed in an always-running cleanup step. Production Android release
tasks also fail locally when protected signing variables are incomplete.

## Candidate procedure

1. Confirm the release commit passes `dart run melos run verify` and Mobile
   Security workflow checks.
2. Confirm product, engineering, security, finance, legal and operations
   approvals are recorded in the change ticket.
3. Run **Protected mobile release candidate**, select one role, supply a semantic
   version, monotonically increasing build number and intended rollout stage.
4. Verify the workflow's application identifier checks, signed AAB/IPA,
   provenance attestations and artifact hashes.
5. Install the candidate through internal store distribution and execute the
   physical-device, locale, accessibility, payment, push and role E2E matrix.
6. Upload only the reviewed candidate to the relevant store. Keep managed
   publishing/manual release enabled.

Each role is released independently. A customer release never supplies vendor
or rider credentials, and a problem in one role can be halted without advancing
the others.

## Progressive rollout

The only permitted progression is:

`internal → cityPilot → percent5 → percent25 → percent50 → percent100`

Respect the observation duration in `release/rollout/policy.json`. Export an
aggregate, non-personal health snapshot and evaluate it before promotion:

```sh
dart run tool/evaluate_release_health.dart \
  --input=/secure/path/release-health.json \
  --stage=percent5
```

Exit code `0` permits the next stage subject to manual approval. Exit code `2`
means hold. Exit code `3` means rollback. Insufficient samples always hold.

## Immediate rollback conditions

Halt rollout and begin rollback when any role crosses a policy threshold:

- crash-free sessions below 99.5%;
- payment failure or order failure above 3%;
- notification loss above 5%;
- backend availability below 99%; or
- any confirmed P0 security, privacy, payment-integrity or safety incident.

## Rollback actions

1. Stop the affected store rollout; do not advance any related role.
2. Disable unsafe server-configurable features using already-authorized backend
   controls, without broadening client permissions.
3. Re-promote the last approved compatible binary when store policy permits.
4. Preserve server-authoritative payment/order state and idempotency records.
5. Notify incident command, support, operations, finance/security/privacy owners
   appropriate to the incident classification.
6. Verify crash, checkout, order, notification and backend health recovery.
7. Record detection, decision, store halt, restoration and validation times.
8. Re-enter at `internal` only after root cause, regression evidence and all
   affected approvals are complete.

The mobile client must never “repair” money, inventory, settlement or assignment
state locally during rollback.
