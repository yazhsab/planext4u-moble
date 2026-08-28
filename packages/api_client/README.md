# Planext4u API client

Contract-generated models and a bounded, cancellation-aware networking policy
shared by the customer, vendor and rider Flutter applications.

## Usage

```dart
import 'package:planext4u_api_client/planext4u_api_client.dart';

final transport = IoApiTransport();
final client = ApiClient(
  baseUrl: config.apiBaseUrl,
  transport: transport,
  authSession: secureAuthSession,
);
final health = await CommonApi(client).getHealth();
```

The application owns `IoApiTransport` and must call `close()` when its dependency
scope is disposed. Access and refresh tokens remain behind `ApiAuthSession`; they
must come from the platform secure-storage adapter, never compile-time config.

Use `ApiRequest.get` for replay-safe reads. Mutations default to no replay. Use
`ApiRequest.command` only where the backend explicitly supports idempotency; it
creates and preserves an `Idempotency-Key` across the bounded retry sequence.

## Contract generation

The checked-in OpenAPI snapshot and problem fixture are mechanically copied from
the backend repository and recorded in `contracts/provenance.json`. From the
workspace root, refresh them with:

```sh
dart run packages/api_client/tool/generate_contracts.dart \
  --sync-from=/absolute/path/to/planext4u-backend/api/openapi/common.openapi.json \
  --fixture-from=/absolute/path/to/planext4u-backend/api/fixtures/problem.json \
  --catalog-from=/absolute/path/to/planext4u-backend/api/openapi/catalog.openapi.json \
  --commerce-from=/absolute/path/to/planext4u-backend/api/openapi/commerce.openapi.json \
  --commerce-fixture-from=/absolute/path/to/planext4u-backend/api/fixtures/commerce_cart.json \
  --transaction-from=/absolute/path/to/planext4u-backend/api/openapi/transaction.openapi.json \
  --notification-from=/absolute/path/to/planext4u-backend/api/openapi/notification.openapi.json \
  --checkout-quote-from=/absolute/path/to/planext4u-backend/api/fixtures/checkout_quote.json \
  --payment-from=/absolute/path/to/planext4u-backend/api/fixtures/payment.json \
  --order-from=/absolute/path/to/planext4u-backend/api/fixtures/order.json \
  --wallet-from=/absolute/path/to/planext4u-backend/api/fixtures/wallet.json \
  --booking-from=/absolute/path/to/planext4u-backend/api/openapi/booking.openapi.json \
  --service-booking-from=/absolute/path/to/planext4u-backend/api/fixtures/service_booking.json \
  --supply-from=/absolute/path/to/planext4u-backend/api/openapi/supply.openapi.json \
  --food-from=/absolute/path/to/planext4u-backend/api/openapi/food.openapi.json \
  --fulfillment-from=/absolute/path/to/planext4u-backend/api/openapi/fulfillment.openapi.json \
  --vendor-program-from=/absolute/path/to/planext4u-backend/api/fixtures/vendor_program.json \
  --food-order-from=/absolute/path/to/planext4u-backend/api/fixtures/food_order.json \
  --rider-assignment-from=/absolute/path/to/planext4u-backend/api/fixtures/rider_assignment.json
```

Do not hand-edit `lib/src/generated/*.g.dart`. CI and the root verification gate
reject a stale or modified snapshot:

```sh
dart run packages/api_client/tool/generate_contracts.dart --check
dart run melos run verify
```

## Network guarantees

- one refresh attempt and replay only for safe or idempotent requests;
- at most three attempts with capped exponential jitter;
- retry only for transport/timeouts or 408, 429, 502, 503 and 504 responses;
- `Retry-After` capped at 30 seconds;
- per-attempt timeout, active cancellation, 2 MiB response limit and no redirects;
- stable correlation and idempotency identifiers across attempts;
- typed authentication, authorization, validation, conflict, rate-limit,
  dependency, transport, timeout, cancellation, contract and unknown failures;
- metadata-only diagnostics. URLs, bodies, tokens and idempotency keys are not
  part of the diagnostics interface.
