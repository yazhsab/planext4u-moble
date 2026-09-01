import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_observability/planext4u_observability.dart';

void main() {
  const healthy = ReleaseHealthSnapshot(
    sessions: 10000,
    checkoutAttempts: 1000,
    crashFreeSessionPercent: 99.91,
    checkoutSuccessPercent: 98.2,
    paymentFailurePercent: 0.7,
    orderFailurePercent: 0.6,
    notificationLossPercent: 1.1,
    backendAvailabilityPercent: 99.95,
    apiP95Milliseconds: 320,
  );

  test('healthy release advances through the controlled rollout stages', () {
    final result = const ReleaseGuardrailPolicy().evaluate(healthy);
    expect(result.decision, ReleaseDecision.advance);
    expect(result.reasons, isEmpty);
    expect(ReleaseStage.internal.next, ReleaseStage.cityPilot);
    expect(ReleaseStage.percent50.next, ReleaseStage.percent100);
    expect(ReleaseStage.percent100.next, isNull);
  });

  test('insufficient evidence or latency breach holds a rollout', () {
    final result = const ReleaseGuardrailPolicy().evaluate(
      const ReleaseHealthSnapshot(
        sessions: 50,
        checkoutAttempts: 5,
        crashFreeSessionPercent: 99.9,
        checkoutSuccessPercent: 98,
        paymentFailurePercent: 1,
        orderFailurePercent: 1,
        notificationLossPercent: 1,
        backendAvailabilityPercent: 99.95,
        apiP95Milliseconds: 510,
      ),
    );
    expect(result.decision, ReleaseDecision.hold);
    expect(
      result.reasons,
      containsAll([
        'insufficient_sessions',
        'insufficient_checkout_attempts',
        'api_latency',
      ]),
    );
  });

  test('a critical health breach always requests rollback', () {
    final result = const ReleaseGuardrailPolicy().evaluate(
      const ReleaseHealthSnapshot(
        sessions: 10000,
        checkoutAttempts: 1000,
        crashFreeSessionPercent: 99.2,
        checkoutSuccessPercent: 96,
        paymentFailurePercent: 3.5,
        orderFailurePercent: 1,
        notificationLossPercent: 6,
        backendAvailabilityPercent: 98.8,
        apiP95Milliseconds: 700,
      ),
    );
    expect(result.decision, ReleaseDecision.rollback);
    expect(
      result.reasons,
      containsAll([
        'crash_free_sessions',
        'payment_failures',
        'notification_loss',
        'backend_availability',
      ]),
    );
  });

  test('health decoder rejects impossible values', () {
    expect(
      () => ReleaseHealthSnapshot.fromJson({
        'sessions': 100,
        'checkout_attempts': 10,
        'crash_free_session_percent': 101,
        'checkout_success_percent': 98,
        'payment_failure_percent': 1,
        'order_failure_percent': 1,
        'notification_loss_percent': 1,
        'backend_availability_percent': 99.9,
        'api_p95_ms': 300,
      }),
      throwsFormatException,
    );
  });

  test('performance budgets and p95 use deterministic samples', () {
    expect(percentile95([100, 120, 150, 200, 700]), 700);
    expect(
      const MobilePerformanceBudget().accepts(
        coldStartMilliseconds: 2200,
        imageFirstPaintMilliseconds: 1100,
        apiP95Milliseconds: 350,
      ),
      isTrue,
    );
  });
}
