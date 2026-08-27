# Planext4u identity

Role-aware mobile identity boundary for the customer, vendor, and rider apps.

- Provider SDKs return short-lived assertions; this package exchanges them for platform sessions.
- Access and rotating refresh credentials live only in platform Keychain/Keystore storage.
- Refresh is single-flight and non-replayable. Reuse denial purges local credentials.
- Offline startup is explicit: valid access can continue in a constrained state; expired access requires reconnection.
- Cross-role authentication is revoked and denied before application navigation.

Provider SDK implementations remain app-composition adapters. Tests use synthetic assertions only.
