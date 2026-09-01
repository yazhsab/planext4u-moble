enum ReleaseStage {
  internal,
  cityPilot,
  percent5,
  percent25,
  percent50,
  percent100,
}

extension ReleaseStageProgression on ReleaseStage {
  ReleaseStage? get next => switch (this) {
    ReleaseStage.internal => ReleaseStage.cityPilot,
    ReleaseStage.cityPilot => ReleaseStage.percent5,
    ReleaseStage.percent5 => ReleaseStage.percent25,
    ReleaseStage.percent25 => ReleaseStage.percent50,
    ReleaseStage.percent50 => ReleaseStage.percent100,
    ReleaseStage.percent100 => null,
  };
}

enum ReleaseDecision { advance, hold, rollback }

final class ReleaseHealthSnapshot {
  const ReleaseHealthSnapshot({
    required this.sessions,
    required this.checkoutAttempts,
    required this.crashFreeSessionPercent,
    required this.checkoutSuccessPercent,
    required this.paymentFailurePercent,
    required this.orderFailurePercent,
    required this.notificationLossPercent,
    required this.backendAvailabilityPercent,
    required this.apiP95Milliseconds,
  });

  factory ReleaseHealthSnapshot.fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const FormatException('Release health must be an object.');
    }
    final snapshot = ReleaseHealthSnapshot(
      sessions: _integer(value, 'sessions'),
      checkoutAttempts: _integer(value, 'checkout_attempts'),
      crashFreeSessionPercent: _number(value, 'crash_free_session_percent'),
      checkoutSuccessPercent: _number(value, 'checkout_success_percent'),
      paymentFailurePercent: _number(value, 'payment_failure_percent'),
      orderFailurePercent: _number(value, 'order_failure_percent'),
      notificationLossPercent: _number(value, 'notification_loss_percent'),
      backendAvailabilityPercent: _number(
        value,
        'backend_availability_percent',
      ),
      apiP95Milliseconds: _integer(value, 'api_p95_ms'),
    );
    snapshot.validate();
    return snapshot;
  }

  final int sessions;
  final int checkoutAttempts;
  final double crashFreeSessionPercent;
  final double checkoutSuccessPercent;
  final double paymentFailurePercent;
  final double orderFailurePercent;
  final double notificationLossPercent;
  final double backendAvailabilityPercent;
  final int apiP95Milliseconds;

  void validate() {
    if (sessions < 0 || checkoutAttempts < 0 || apiP95Milliseconds < 0) {
      throw const FormatException('Release health counts are invalid.');
    }
    for (final value in [
      crashFreeSessionPercent,
      checkoutSuccessPercent,
      paymentFailurePercent,
      orderFailurePercent,
      notificationLossPercent,
      backendAvailabilityPercent,
    ]) {
      if (!value.isFinite || value < 0 || value > 100) {
        throw const FormatException('Release health percentage is invalid.');
      }
    }
  }
}

final class ReleaseGuardrailPolicy {
  const ReleaseGuardrailPolicy({
    this.minimumSessions = 1000,
    this.minimumCheckoutAttempts = 100,
    this.advanceCrashFreeSessionPercent = 99.8,
    this.rollbackCrashFreeSessionPercent = 99.5,
    this.minimumCheckoutSuccessPercent = 97,
    this.rollbackPaymentFailurePercent = 3,
    this.rollbackOrderFailurePercent = 3,
    this.rollbackNotificationLossPercent = 5,
    this.minimumBackendAvailabilityPercent = 99.9,
    this.rollbackBackendAvailabilityPercent = 99,
    this.maximumApiP95Milliseconds = 400,
  });

  final int minimumSessions;
  final int minimumCheckoutAttempts;
  final double advanceCrashFreeSessionPercent;
  final double rollbackCrashFreeSessionPercent;
  final double minimumCheckoutSuccessPercent;
  final double rollbackPaymentFailurePercent;
  final double rollbackOrderFailurePercent;
  final double rollbackNotificationLossPercent;
  final double minimumBackendAvailabilityPercent;
  final double rollbackBackendAvailabilityPercent;
  final int maximumApiP95Milliseconds;

  ReleaseEvaluation evaluate(ReleaseHealthSnapshot snapshot) {
    snapshot.validate();
    final rollbackReasons = <String>[
      if (snapshot.crashFreeSessionPercent < rollbackCrashFreeSessionPercent)
        'crash_free_sessions',
      if (snapshot.paymentFailurePercent > rollbackPaymentFailurePercent)
        'payment_failures',
      if (snapshot.orderFailurePercent > rollbackOrderFailurePercent)
        'order_failures',
      if (snapshot.notificationLossPercent > rollbackNotificationLossPercent)
        'notification_loss',
      if (snapshot.backendAvailabilityPercent <
          rollbackBackendAvailabilityPercent)
        'backend_availability',
    ];
    if (rollbackReasons.isNotEmpty) {
      return ReleaseEvaluation(
        decision: ReleaseDecision.rollback,
        reasons: List.unmodifiable(rollbackReasons),
      );
    }

    final holdReasons = <String>[
      if (snapshot.sessions < minimumSessions) 'insufficient_sessions',
      if (snapshot.checkoutAttempts < minimumCheckoutAttempts)
        'insufficient_checkout_attempts',
      if (snapshot.crashFreeSessionPercent < advanceCrashFreeSessionPercent)
        'crash_free_sessions',
      if (snapshot.checkoutSuccessPercent < minimumCheckoutSuccessPercent)
        'checkout_success',
      if (snapshot.backendAvailabilityPercent <
          minimumBackendAvailabilityPercent)
        'backend_availability',
      if (snapshot.apiP95Milliseconds > maximumApiP95Milliseconds)
        'api_latency',
    ];
    return ReleaseEvaluation(
      decision: holdReasons.isEmpty
          ? ReleaseDecision.advance
          : ReleaseDecision.hold,
      reasons: List.unmodifiable(holdReasons),
    );
  }
}

final class ReleaseEvaluation {
  const ReleaseEvaluation({required this.decision, required this.reasons});

  final ReleaseDecision decision;
  final List<String> reasons;
}

final class MobilePerformanceBudget {
  const MobilePerformanceBudget({
    this.coldStartMilliseconds = 2500,
    this.imageFirstPaintMilliseconds = 1200,
    this.apiP95Milliseconds = 400,
  });

  final int coldStartMilliseconds;
  final int imageFirstPaintMilliseconds;
  final int apiP95Milliseconds;

  bool accepts({
    required int coldStartMilliseconds,
    required int imageFirstPaintMilliseconds,
    required int apiP95Milliseconds,
  }) =>
      coldStartMilliseconds <= this.coldStartMilliseconds &&
      imageFirstPaintMilliseconds <= this.imageFirstPaintMilliseconds &&
      apiP95Milliseconds <= this.apiP95Milliseconds;
}

int percentile95(Iterable<int> samples) {
  final sorted = samples.toList()..sort();
  if (sorted.isEmpty || sorted.any((value) => value < 0)) {
    throw const FormatException('Performance samples are invalid.');
  }
  final index = ((sorted.length * 0.95).ceil() - 1).clamp(0, sorted.length - 1);
  return sorted[index];
}

int _integer(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('$key must be an integer.');
  return value;
}

double _number(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! num) throw FormatException('$key must be numeric.');
  return value.toDouble();
}
