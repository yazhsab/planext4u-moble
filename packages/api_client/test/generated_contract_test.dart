import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_api_client/src/generated/contract_fixture.g.dart';

void main() {
  test('backend problem fixture decodes through generated models', () {
    final envelope = ApiErrorEnvelope.fromJson(jsonDecode(problemFixtureJson));

    expect(envelope.error.code, 'LOCATION_NOT_SERVICEABLE');
    expect(envelope.error.correlationId, 'corr-synthetic-001');
    expect(envelope.error.retryable, isFalse);
    expect(envelope.error.fieldErrors, hasLength(1));
    expect(envelope.error.fieldErrors.single.field, 'location_id');
    expect(envelope.toJson()['error'], isA<Map<String, Object?>>());
  });

  test('generated enums tolerate additive unknown values', () {
    expect(ApiAppRole.fromJson('FUTURE_ROLE'), ApiAppRole.unknown);
    expect(GeoPurpose.fromJson('FUTURE_PURPOSE'), GeoPurpose.unknown);
    expect(HealthStatus.fromJson('degraded'), HealthStatus.unknown);
  });

  test('generated value models validate contract constraints', () {
    expect(
      Money.fromJson({'minor_units': 124900, 'currency': 'INR'}).toJson(),
      {'minor_units': 124900, 'currency': 'INR'},
    );
    expect(
      () => Money.fromJson({'minor_units': 12.5, 'currency': 'INR'}),
      throwsFormatException,
    );
    expect(
      () => GeoPoint.fromJson({
        'latitude': 100,
        'longitude': 80,
        'captured_at': '2026-08-27T00:00:00Z',
        'purpose': 'SERVICEABILITY',
      }),
      throwsFormatException,
    );
  });

  test('generated models tolerate unknown additive object properties', () {
    final response = HealthResponse.fromJson({
      'status': 'ready',
      'service': 'gateway',
      'version': 'synthetic',
      'future_optional_property': true,
    });
    expect(response.status, HealthStatus.ready);
  });
}
