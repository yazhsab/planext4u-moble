# Identity and session implementation

Story: `MOB-P2-005`

The package at `packages/identity` implements the mobile half of the backend identity contract introduced by `BE-P2-005`.

## Security decisions

- Phone OTP, email and Google/Apple flows are provider adapters. Provider credentials never cross the shared package; only a short-lived provider assertion is exchanged.
- Platform tokens are stored as one versioned record through `flutter_secure_storage` 11.0.0 (Android Keystore-backed AES-GCM/RSA-OAEP and Apple Keychain).
- Refresh rotation is single-flight and non-replayable. A server authentication denial clears the complete local session.
- Logout clears local credentials before best-effort server revocation, including offline and dependency-failure paths.
- Corrupt or unsupported secure-storage records are cleared. Token values never enter exceptions, state labels, diagnostics or logs.
- Customer, vendor and rider apps accept only a matching backend role; wrong-role sessions are revoked and denied.

## State contract

`uninitialized -> signedOut/authenticated/offlineAuthenticated/offlineRecoveryRequired/expired/roleDenied`

An offline session is useful only while its access token remains valid. Refresh-expired sessions are purged. Network failures retain an unexpired refresh token for later recovery; authentication failures do not.

## Verification

The package covers provider exchange, OTP/email/OAuth routing, restore, token expiry, single-flight rotation, revocation denial, wrong-role denial, offline recovery, logout purge, corrupt storage and the concrete HTTP contract with synthetic fixtures.
