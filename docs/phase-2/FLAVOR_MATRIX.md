# Mobile flavor and identity matrix

## Store identities

The misspelled repository name is intentionally preserved, while all product
identifiers use the correct `planext4u` spelling.

| App | Development | Staging | Production |
| --- | --- | --- | --- |
| Customer | `net.planext4u.customer.dev` | `net.planext4u.customer.staging` | `net.planext4u.customer` |
| Vendor | `net.planext4u.vendor.dev` | `net.planext4u.vendor.staging` | `net.planext4u.vendor` |
| Rider | `net.planext4u.rider.dev` | `net.planext4u.rider.staging` | `net.planext4u.rider` |

Android application IDs and iOS bundle IDs use the same matrix. Development
and staging builds can coexist with production builds on a device.

## Public environments

| Environment | API default | Web/deep-link host |
| --- | --- | --- |
| Development | `http://localhost:8080` | `dev.planext4u.net` |
| Staging | `https://api.staging.planext4u.net` | `staging.planext4u.net` |
| Production | `https://api.planext4u.net` | `planext4u.net` |

Web paths are `/app` for customer, `/vendor` for vendor and `/rider` for rider.
OAuth callback schemes are role and environment specific, for example
`planext4u-customer-dev://oauth/callback` and
`planext4u-customer://oauth/callback`.

Native manifests and schemes are complete. Publishing the domain association
files (`assetlinks.json` and `apple-app-site-association`) remains the controlled
DNS/deployment gate in `P4U-DV-007`; it cannot be proven from application source.

## Build commands

Run commands from an app directory and keep the native flavor aligned with the
public `APP_ENV` Dart define:

```sh
flutter build apk \
  --debug \
  --flavor staging \
  --dart-define=APP_ENV=staging

flutter build ios \
  --simulator \
  --no-codesign \
  --flavor staging \
  --dart-define=APP_ENV=staging
```

Only the allow-listed public keys `APP_ENV`, `API_BASE_URL`, `WEB_BASE_URL` and
`DEEP_LINK_HOST` may be supplied. Tokens, API keys, provider configuration,
client secrets and signing credentials are recoverable from app binaries and
must use platform secret/configuration systems instead.

## Reproducible checks

- `ruby tool/configure_ios_flavors.rb` regenerates Xcode configurations and
  schemes from the checked-in identity matrix.
- `dart run tool/validate_flavors.dart` checks the nine native identities,
  hosts, schemes, path prefixes, entitlements and release-signing boundary.
- `dart run melos run verify` runs flavor validation with formatting, analysis
  and tests.

Validation on 2026-08-27 built all nine Android debug APK variants and all nine
iOS Simulator variants successfully.
