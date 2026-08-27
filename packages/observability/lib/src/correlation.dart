import 'dart:async';
import 'dart:math';

const _correlationZoneKey = #planext4uCorrelationId;

final class TelemetryCorrelation {
  TelemetryCorrelation._();

  static String? get current => Zone.current[_correlationZoneKey] as String?;

  static String currentOrNew() => current ?? create();

  static String create({DateTime? at, Random? random}) {
    final timestamp = (at ?? DateTime.now().toUtc()).microsecondsSinceEpoch;
    final entropy = (random ?? Random.secure()).nextInt(0x7fffffff);
    return '${timestamp.toRadixString(16)}-${entropy.toRadixString(16)}';
  }

  static R run<R>(String correlationId, R Function() body) {
    if (!RegExp(r'^[A-Za-z0-9._:-]{8,128}$').hasMatch(correlationId)) {
      throw const FormatException('Invalid correlation ID.');
    }
    return runZoned(body, zoneValues: {_correlationZoneKey: correlationId});
  }
}
