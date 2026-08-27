import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_observability/planext4u_observability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixedTime = DateTime.utc(2026, 8, 27, 12);

  for (final deployment in TelemetryDeployment.values) {
    test('analytics and crash opt-out is enforced in ${deployment.name}', () {
      final consent = MutableTelemetryConsent();
      final sink = BufferedTelemetrySink();
      final telemetry = StructuredTelemetry(
        consent: consent,
        sink: sink,
        policy: TelemetryPolicy.forDeployment(deployment),
        clock: () => fixedTime,
      );

      expect(telemetry.analytics('home.viewed'), isFalse);
      expect(
        telemetry.crash(StateError('private'), StackTrace.current),
        isFalse,
      );
      expect(sink.events, isEmpty);

      consent.current = const TelemetryConsent(
        analyticsAllowed: true,
        diagnosticsAllowed: true,
      );
      expect(telemetry.analytics('home.viewed'), isTrue);
      expect(
        telemetry.crash(StateError('private'), StackTrace.current),
        isTrue,
      );
      expect(sink.events, hasLength(2));

      consent.current = const TelemetryConsent.denied();
      expect(telemetry.analytics('home.viewed'), isFalse);
      expect(sink.events, hasLength(2));
    });
  }

  test('redacts sensitive keys, values, URLs and control characters', () {
    final result = redactTelemetryAttributes({
      'email': 'customer@example.com',
      'access_token': 'not-safe',
      'label': 'customer@example.com',
      'endpoint': 'https://api.example.test/items?customer=123#private',
      'operation': 'catalog\nlookup',
      'count': 3,
    });

    expect(result['email'], '[REDACTED]');
    expect(result['access_token'], '[REDACTED]');
    expect(result['label'], '[REDACTED]');
    expect(result['endpoint'], 'https://api.example.test/items');
    expect(result['operation'], 'catalog lookup');
    expect(result['count'], 3);
  });

  test('API diagnostics are operational, correlated and sanitized', () {
    final sink = BufferedTelemetrySink();
    final telemetry = StructuredTelemetry(
      consent: MutableTelemetryConsent(),
      sink: sink,
      policy: TelemetryPolicy.forDeployment(TelemetryDeployment.staging),
      clock: () => fixedTime,
    );
    final diagnostics = ApiTelemetryDiagnostics(telemetry);

    diagnostics.requestStarted(
      operation: 'catalog.list',
      method: 'get',
      attempt: 1,
      correlationId: 'correlation-1234',
    );
    diagnostics.requestFinished(
      operation: 'catalog.list',
      attempt: 1,
      outcome: ApiDiagnosticOutcome.success,
      statusCode: 200,
      elapsed: const Duration(milliseconds: 42),
      correlationId: 'correlation-1234',
    );

    expect(sink.events, hasLength(2));
    expect(sink.events.last.correlationId, 'correlation-1234');
    expect(sink.events.last.attributes['duration_ms'], 42);
    expect(sink.events.last.attributes.containsKey('url'), isFalse);
  });

  test(
    'production suppresses debug diagnostics but keeps request outcomes',
    () {
      final sink = BufferedTelemetrySink();
      final diagnostics = ApiTelemetryDiagnostics(
        StructuredTelemetry(
          consent: MutableTelemetryConsent(),
          sink: sink,
          policy: TelemetryPolicy.forDeployment(TelemetryDeployment.production),
          clock: () => fixedTime,
        ),
      );

      diagnostics.requestStarted(
        operation: 'bootstrap.read',
        method: 'GET',
        attempt: 1,
        correlationId: 'correlation-5678',
      );
      diagnostics.requestFinished(
        operation: 'bootstrap.read',
        attempt: 1,
        outcome: ApiDiagnosticOutcome.failure,
        statusCode: 503,
        elapsed: const Duration(seconds: 1),
        correlationId: 'correlation-5678',
      );

      expect(sink.events, hasLength(1));
      expect(sink.events.single.level, TelemetryLevel.warning);
    },
  );

  test('crash reports do not serialize messages or stack traces', () {
    final sink = BufferedTelemetrySink();
    final telemetry = StructuredTelemetry(
      consent: MutableTelemetryConsent(
        const TelemetryConsent(
          analyticsAllowed: false,
          diagnosticsAllowed: true,
        ),
      ),
      sink: sink,
      policy: TelemetryPolicy.forDeployment(TelemetryDeployment.staging),
      clock: () => fixedTime,
    );

    telemetry.crash(
      StateError('secret@example.com token-value'),
      StackTrace.fromString('private stack'),
      fatal: true,
    );

    final encoded = sink.events.single.toJson().toString();
    expect(encoded, isNot(contains('secret@example.com')));
    expect(encoded, isNot(contains('private stack')));
    expect(sink.events.single.attributes['error_type'], 'StateError');
  });

  test('correlation context is scoped and rejects unsafe values', () {
    expect(TelemetryCorrelation.current, isNull);
    final observed = TelemetryCorrelation.run(
      'request-correlation-1',
      TelemetryCorrelation.currentOrNew,
    );
    expect(observed, 'request-correlation-1');
    expect(TelemetryCorrelation.current, isNull);
    expect(
      () => TelemetryCorrelation.run('unsafe value', () {}),
      throwsFormatException,
    );
  });
}
