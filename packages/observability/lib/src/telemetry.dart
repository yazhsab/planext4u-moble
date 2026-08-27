import 'dart:convert';

import 'package:planext4u_api_client/planext4u_api_client.dart';

enum TelemetryScope { operational, analytics, diagnostics }

enum TelemetryLevel { debug, info, warning, error }

enum TelemetryDeployment { development, staging, production }

final class TelemetryConsent {
  const TelemetryConsent({
    required this.analyticsAllowed,
    required this.diagnosticsAllowed,
  });

  const TelemetryConsent.denied()
    : analyticsAllowed = false,
      diagnosticsAllowed = false;

  final bool analyticsAllowed;
  final bool diagnosticsAllowed;

  bool allows(TelemetryScope scope) => switch (scope) {
    TelemetryScope.operational => true,
    TelemetryScope.analytics => analyticsAllowed,
    TelemetryScope.diagnostics => diagnosticsAllowed,
  };
}

abstract interface class TelemetryConsentProvider {
  TelemetryConsent get current;
}

final class MutableTelemetryConsent implements TelemetryConsentProvider {
  MutableTelemetryConsent([this.current = const TelemetryConsent.denied()]);

  @override
  TelemetryConsent current;
}

final class TelemetryPolicy {
  const TelemetryPolicy({required this.deployment, required this.minimumLevel});

  factory TelemetryPolicy.forDeployment(TelemetryDeployment deployment) =>
      TelemetryPolicy(
        deployment: deployment,
        minimumLevel: deployment == TelemetryDeployment.production
            ? TelemetryLevel.info
            : TelemetryLevel.debug,
      );

  final TelemetryDeployment deployment;
  final TelemetryLevel minimumLevel;

  bool admits(TelemetryLevel level) => level.index >= minimumLevel.index;
}

final class TelemetryEvent {
  const TelemetryEvent({
    required this.name,
    required this.scope,
    required this.level,
    required this.occurredAt,
    required this.correlationId,
    required this.attributes,
  });

  final String name;
  final TelemetryScope scope;
  final TelemetryLevel level;
  final DateTime occurredAt;
  final String? correlationId;
  final Map<String, Object> attributes;

  Map<String, Object?> toJson() => {
    'name': name,
    'scope': scope.name,
    'level': level.name,
    'occurred_at': occurredAt.toUtc().toIso8601String(),
    if (correlationId != null) 'correlation_id': correlationId,
    'attributes': attributes,
  };
}

abstract interface class TelemetrySink {
  void emit(TelemetryEvent event);
}

final class BufferedTelemetrySink implements TelemetrySink {
  final List<TelemetryEvent> _events = [];

  List<TelemetryEvent> get events => List.unmodifiable(_events);

  @override
  void emit(TelemetryEvent event) => _events.add(event);

  void clear() => _events.clear();
}

final class JsonLineTelemetrySink implements TelemetrySink {
  const JsonLineTelemetrySink(this.write);

  final void Function(String line) write;

  @override
  void emit(TelemetryEvent event) => write(jsonEncode(event.toJson()));
}

final class StructuredTelemetry {
  StructuredTelemetry({
    required TelemetryConsentProvider consent,
    required TelemetrySink sink,
    required TelemetryPolicy policy,
    DateTime Function()? clock,
  }) : _consent = consent,
       _sink = sink,
       _policy = policy,
       _clock = clock ?? DateTime.now;

  final TelemetryConsentProvider _consent;
  final TelemetrySink _sink;
  final TelemetryPolicy _policy;
  final DateTime Function() _clock;

  bool record(
    String name, {
    required TelemetryScope scope,
    TelemetryLevel level = TelemetryLevel.info,
    String? correlationId,
    Map<String, Object?> attributes = const {},
  }) {
    if (!_consent.current.allows(scope) || !_policy.admits(level)) return false;
    _sink.emit(
      TelemetryEvent(
        name: _safeName(name),
        scope: scope,
        level: level,
        occurredAt: _clock().toUtc(),
        correlationId: _safeCorrelation(correlationId),
        attributes: redactTelemetryAttributes(attributes),
      ),
    );
    return true;
  }

  bool analytics(
    String name, {
    String? correlationId,
    Map<String, Object?> attributes = const {},
  }) => record(
    name,
    scope: TelemetryScope.analytics,
    correlationId: correlationId,
    attributes: attributes,
  );

  bool crash(
    Object error,
    StackTrace stackTrace, {
    bool fatal = false,
    String? correlationId,
  }) => record(
    'app.crash',
    scope: TelemetryScope.diagnostics,
    level: TelemetryLevel.error,
    correlationId: correlationId,
    attributes: {'error_type': error.runtimeType.toString(), 'fatal': fatal},
  );
}

final class ApiTelemetryDiagnostics implements ApiDiagnostics {
  const ApiTelemetryDiagnostics(this.telemetry);

  final StructuredTelemetry telemetry;

  @override
  void requestStarted({
    required String operation,
    required String method,
    required int attempt,
    required String correlationId,
  }) {
    telemetry.record(
      'api.request.started',
      scope: TelemetryScope.operational,
      level: TelemetryLevel.debug,
      correlationId: correlationId,
      attributes: {
        'operation': operation,
        'http_method': method.toUpperCase(),
        'attempt': attempt,
      },
    );
  }

  @override
  void requestFinished({
    required String operation,
    required int attempt,
    required ApiDiagnosticOutcome outcome,
    required int? statusCode,
    required Duration elapsed,
    required String correlationId,
  }) {
    telemetry.record(
      'api.request.finished',
      scope: TelemetryScope.operational,
      level: outcome == ApiDiagnosticOutcome.success
          ? TelemetryLevel.info
          : TelemetryLevel.warning,
      correlationId: correlationId,
      attributes: {
        'operation': operation,
        'attempt': attempt,
        'outcome': outcome.name,
        'http_status_code': ?statusCode,
        'duration_ms': elapsed.inMilliseconds,
      },
    );
  }
}

Map<String, Object> redactTelemetryAttributes(Map<String, Object?> input) {
  final output = <String, Object>{};
  for (final entry in input.entries) {
    final key = _safeKey(entry.key);
    output[key] = _isSensitiveKey(key) ? '[REDACTED]' : _safeValue(entry.value);
  }
  return Map.unmodifiable(output);
}

String _safeName(String value) {
  final normalized = value.trim().toLowerCase();
  if (!RegExp(r'^[a-z][a-z0-9_.-]{0,63}$').hasMatch(normalized)) {
    return 'telemetry.invalid_name';
  }
  return normalized;
}

String _safeKey(String value) {
  final normalized = value.trim().toLowerCase();
  if (!RegExp(r'^[a-z][a-z0-9_.-]{0,63}$').hasMatch(normalized)) {
    return 'invalid_attribute';
  }
  return normalized;
}

bool _isSensitiveKey(String key) {
  const sensitiveSegments = {
    'address',
    'authorization',
    'body',
    'cookie',
    'email',
    'idempotency',
    'name',
    'password',
    'phone',
    'secret',
    'session',
    'stack',
    'token',
  };
  return key.split(RegExp(r'[._-]')).any(sensitiveSegments.contains);
}

Object _safeValue(Object? value) {
  if (value == null) return 'null';
  if (value is bool || value is num) return value;
  if (value is Enum) return value.name;
  final text = value.toString().replaceAll(RegExp(r'[\r\n\t]'), ' ').trim();
  if (_containsSensitivePattern(text)) return '[REDACTED]';
  final uri = Uri.tryParse(text);
  if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
    return uri
        .replace(query: '', fragment: '')
        .toString()
        .replaceFirst(RegExp(r'[?#]+$'), '');
  }
  return text.length <= 256 ? text : '${text.substring(0, 256)}…';
}

bool _containsSensitivePattern(String value) {
  final email = RegExp(r'\b[^\s@]+@[^\s@]+\.[^\s@]+\b');
  final bearer = RegExp(r'\bbearer\s+[a-z0-9._~+/=-]+', caseSensitive: false);
  final phone = RegExp(r'(?<!\d)(?:\+?\d[ -]?){8,15}(?!\d)');
  return email.hasMatch(value) ||
      bearer.hasMatch(value) ||
      phone.hasMatch(value);
}

String? _safeCorrelation(String? value) {
  if (value == null) return null;
  return RegExp(r'^[A-Za-z0-9._:-]{8,128}$').hasMatch(value) ? value : null;
}
