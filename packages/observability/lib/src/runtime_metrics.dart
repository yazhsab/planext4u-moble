import 'telemetry.dart';

final class MobileObservability {
  MobileObservability._(this.telemetry)
    : apiDiagnostics = ApiTelemetryDiagnostics(telemetry),
      runtimeMetrics = MobileRuntimeMetrics(telemetry);

  factory MobileObservability({
    required TelemetryDeployment deployment,
    required TelemetrySink sink,
    TelemetryConsentProvider? consent,
  }) => MobileObservability._(
    StructuredTelemetry(
      consent: consent ?? MutableTelemetryConsent(),
      sink: sink,
      policy: TelemetryPolicy.forDeployment(deployment),
    ),
  );

  final StructuredTelemetry telemetry;
  final ApiTelemetryDiagnostics apiDiagnostics;
  final MobileRuntimeMetrics runtimeMetrics;
}

final class MobileRuntimeMetrics {
  const MobileRuntimeMetrics(this._telemetry);

  final StructuredTelemetry _telemetry;

  void firstFrame(Duration elapsed, {required String application}) {
    _telemetry.record(
      'app.first_frame',
      scope: TelemetryScope.operational,
      level: elapsed > const Duration(milliseconds: 2500)
          ? TelemetryLevel.warning
          : TelemetryLevel.info,
      attributes: {
        'application': application,
        'duration_ms': elapsed.inMilliseconds,
        'budget_ms': 2500,
      },
    );
  }

  void imageFirstPaint(Duration elapsed, {required String surface}) {
    _telemetry.record(
      'app.image_first_paint',
      scope: TelemetryScope.operational,
      level: elapsed > const Duration(milliseconds: 1200)
          ? TelemetryLevel.warning
          : TelemetryLevel.info,
      attributes: {
        'surface': surface,
        'duration_ms': elapsed.inMilliseconds,
        'budget_ms': 1200,
      },
    );
  }

  void checkoutOutcome({required bool successful, required String mode}) {
    _telemetry.record(
      'checkout.outcome',
      scope: TelemetryScope.operational,
      level: successful ? TelemetryLevel.info : TelemetryLevel.warning,
      attributes: {'successful': successful, 'mode': mode},
    );
  }

  void notificationOutcome({required bool delivered}) {
    _telemetry.record(
      'notification.outcome',
      scope: TelemetryScope.operational,
      level: delivered ? TelemetryLevel.info : TelemetryLevel.warning,
      attributes: {'delivered': delivered},
    );
  }

  void runtimeError(Object error, {required bool fatal}) {
    _telemetry.record(
      'app.runtime_error',
      scope: TelemetryScope.operational,
      level: TelemetryLevel.error,
      attributes: {'error_type': error.runtimeType.toString(), 'fatal': fatal},
    );
  }
}
