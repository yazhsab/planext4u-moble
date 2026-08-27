enum ApiDiagnosticOutcome { success, failure, cancelled }

abstract interface class ApiDiagnostics {
  void requestStarted({
    required String operation,
    required String method,
    required int attempt,
    required String correlationId,
  });

  void requestFinished({
    required String operation,
    required int attempt,
    required ApiDiagnosticOutcome outcome,
    required int? statusCode,
    required Duration elapsed,
    required String correlationId,
  });
}

final class NoopApiDiagnostics implements ApiDiagnostics {
  const NoopApiDiagnostics();

  @override
  void requestStarted({
    required String operation,
    required String method,
    required int attempt,
    required String correlationId,
  }) {}

  @override
  void requestFinished({
    required String operation,
    required int attempt,
    required ApiDiagnosticOutcome outcome,
    required int? statusCode,
    required Duration elapsed,
    required String correlationId,
  }) {}
}

Map<String, String> redactHeadersForDiagnostics(Map<String, String> headers) {
  const sensitive = {
    'authorization',
    'cookie',
    'idempotency-key',
    'proxy-authorization',
    'set-cookie',
  };
  return Map.unmodifiable({
    for (final entry in headers.entries)
      entry.key: sensitive.contains(entry.key.toLowerCase())
          ? '[REDACTED]'
          : entry.value,
  });
}
