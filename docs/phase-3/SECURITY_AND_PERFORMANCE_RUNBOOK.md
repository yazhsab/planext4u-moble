# Security, accessibility and performance runbook

## Repository gate

Run from the repository root:

```sh
flutter pub get
dart run melos run verify
```

The gate checks generated API contracts and design tokens, formatting, native
flavors, role integrations, secret/transport/signing/privacy controls, release
policy, static analysis and every unit/widget test. GitHub additionally runs OSV
dependency and Gitleaks history scans with commit-pinned actions.

## Security evidence

Before production approval, the security owner must attach:

- triaged source and dependency scan reports;
- Android and iOS signed-binary static/dynamic assessment;
- authenticated and unauthenticated API penetration results for customer,
  vendor and rider role boundaries;
- payment callback, webhook duplication, stale revision and idempotency tests;
- private media/KYC access, deep-link allowlist, push token and log-redaction tests;
- dependency/SDK inventory matched to privacy declarations; and
- remediation evidence showing zero open P0/P1 findings.

Production and staging disable cleartext traffic. Android backups are disabled.
The rider alone declares background location, and runtime behavior must keep it
restricted to on-duty fulfillment.

## Accessibility and locale matrix

On representative small/large Android and iOS devices, test all nine supported
locales in light/dark mode at 100%, 130% and 200% text scaling. For every role,
record TalkBack/VoiceOver reading order, meaningful labels, 48dp targets,
keyboard/switch focus, live error announcements, color contrast, reduced motion,
permission denial and offline/reconnect behavior. Professional language review
is required for real catalog, order, financial, safety and legal content.

## Performance budgets

The source records privacy-redacted aggregates against these budgets:

| Metric | Budget |
| --- | ---: |
| Cold start to first frame | at most 2500 ms |
| Network image first paint | at most 1200 ms |
| API p95 latency | at most 400 ms |
| Crash-free sessions for advancement | at least 99.8% |
| Checkout success for advancement | at least 97% |

Measure cold and warm launches on representative low/mid/high devices, release
builds and realistic networks. Image measurements use uncached and cached runs.
API measurements include mobile-to-edge time and are correlated to backend
traces without personal identifiers.

## Production-equivalent exercises

- Calibrated load: expected peak plus agreed headroom across authentication,
  discovery, cart, order, vendor work and rider offers.
- Soak: sustained role traffic long enough to expose queue, token, memory,
  connection and storage leaks.
- Chaos: payment/provider timeout, push loss, media failure, map/navigation
  outage, websocket loss, stale revisions and partial backend dependency failure.
- Disaster recovery: restore authoritative data/services in the secondary
  environment and measure RTO/RPO against approved objectives.
- Rider field test: constrained Android device, background/offline sequence,
  battery drain, location accuracy, reconnect and proof-of-delivery upload.

Never manufacture these results in fixtures. Store calibrated inputs, dashboards,
timestamps, environment version, outcomes and approver identity in the release
record, then evaluate aggregate rollout health with
`tool/evaluate_release_health.dart`.
