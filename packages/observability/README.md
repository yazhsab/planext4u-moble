# Planext4u observability

This package owns the Phase 2 mobile telemetry boundary:

- operational API events with end-to-end correlation identifiers;
- analytics and crash collection gated by the latest consent snapshot;
- centralized attribute redaction and bounded structured JSON output;
- development, staging, and production minimum-level policies; and
- crash envelopes that never serialize exception messages or stack traces.

Operational events are deliberately restricted to low-cardinality fields. Never
pass request/response bodies, personal identifiers, access tokens, or raw URLs to
telemetry. Provider SDK adapters belong behind `TelemetrySink`; no provider SDK is
permitted inside feature packages.
