# Mobile CI and staging gate

Phase 2 mobile changes are protected by a clean-checkout workflow pinned to
Flutter 3.41.4. The required `quality` job runs generated-contract and token
drift checks, formatting, flavor validation, static analysis, unit tests,
widget tests and golden tests. Separate matrix jobs compile customer, vendor
and rider for development, staging and production on Android and iOS.

`MOB-E2E-001` runs on an Android emulator with deterministic synthetic data. It
exercises the fresh-install consent, login, foreground-location, customer-home
and catalog-read boundaries without embedding a real person's credentials.

The staging smoke workflow probes readiness and bootstrap every day. A manual
release-candidate run requires the protected staging environment secret
`STAGING_SYNTHETIC_ACCESS_TOKEN` and additionally verifies the authenticated
home projection. The smoke tool accepts HTTPS origins only, bounds responses,
does not print the token or response body, and emits a correlation ID.

Required branch protection checks are `quality`, all three Android build jobs,
all three iOS build jobs and `MOB-E2E-001 Android emulator`. Deployment remains
blocked until the paired backend staging slice is available and the manual
authenticated smoke run passes.
