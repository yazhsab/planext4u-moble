# Phase 2 generated API client implementation

## Contract authority

`packages/api_client` consumes a checked-in, reproducible snapshot of the
backend's common OpenAPI 3.1 contract and standard problem fixture. The generator
validates the required contract version, schemas and operations before emitting
formatted Dart. Unknown JSON fields and future enum values are tolerated while
required fields and value constraints remain strict.

| Input | Backend source commit | SHA-256 |
| --- | --- | --- |
| `common.openapi.json` | `3c3114b` | `332ef63e39ef8f7e4dc13a25709b697f288fbb66061f29f73ecf0ee7a8db4b0f` |
| `problem.fixture.json` | `3c3114b` | `825ac6e3ae62d63e74556fc54a82f0ddfd09fdf86edfdb9c82d00995072a927e` |

`contracts/provenance.json` records the repository, source paths, commit and both
hashes. `generate_contracts.dart --check` is the first workspace verification
step, so drift fails before format, analysis or tests.

## Request and authentication policy

Request construction snapshots query parameters, headers and the JSON body.
Reserved security headers cannot be supplied by a feature. The client owns
Bearer authorization, correlation IDs, content length/type and idempotency keys.
Unsafe mutations are never replayed. A command becomes replayable only through
the explicit idempotent factory, which validates or generates its key.

An authenticated request reads its access token for each attempt. A 401 can
trigger at most one refresh, and only a safe read or idempotent command may be
replayed. Missing, malformed or unavailable secure-session data fails before the
transport receives the request.

## Resilience bounds

The default policy permits three attempts. Backoff begins at 200 ms, uses
exponential jitter and caps at two seconds. Only transport errors, timeouts and
408/429/502/503/504 contract responses are eligible. Numeric `Retry-After` is
honoured up to 30 seconds. The caller can cancel the active socket operation or
the pending backoff delay.

`IoApiTransport` accepts absolute HTTP(S) URLs without embedded credentials,
enforces a per-attempt timeout, aborts cancelled requests, does not follow
redirects and reads at most 2 MiB per response by default. Staging and production
HTTPS enforcement remains at the typed environment-configuration boundary.

## Failure and observability contract

Callers receive a stable failure taxonomy for authentication, authorization,
validation, conflict, rate limiting, dependencies, transport, timeout,
cancellation, response-contract violations and unknown server failures. Valid
backend field errors and correlation IDs are preserved; malformed payloads are
normalized to a safe contract failure rather than leaking raw content.

Diagnostics contain only operation identifier, method, attempt, outcome, status,
duration and correlation ID. Their interface cannot receive URL/query data,
headers or bodies. The optional header-redaction helper removes authorization,
cookie and idempotency values, and diagnostics failures cannot change a request
outcome.

## Verification evidence

The package tests cover generated fixture decoding, additive enums, request
snapshotting, repeated query encoding, auth refresh, unsafe-mutation protection,
idempotency stability, exact retry exhaustion, server-delay caps, cancellation,
failure mapping, malformed payloads and PII redaction. Loopback HTTP integration
tests exercise request I/O, timeout abort, active cancellation, bounded response
reads and redirect refusal against a real Dart `HttpServer`.

Run the complete foundation gate from the workspace root:

```sh
dart run melos run verify
```
