import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_customer/payment_provider_launcher.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

void main() {
  test(
    'native launcher routes only backend-created provider handoffs',
    () async {
      final razorpay = _RecordingCheckout();
      final paystack = _RecordingCheckout();
      final launcher = NativePaymentProviderLauncher(
        razorpay: razorpay,
        paystack: paystack,
      );
      final payment = _payment(CustomerPaymentMethod.razorpay);

      await launcher.launch(payment);

      expect(razorpay.value, same(payment));
      expect(paystack.value, isNull);
    },
  );

  test('native launcher rejects non-provider payment methods', () async {
    final launcher = NativePaymentProviderLauncher(
      razorpay: _RecordingCheckout(),
      paystack: _RecordingCheckout(),
    );

    await expectLater(
      launcher.launch(_payment(CustomerPaymentMethod.cod)),
      throwsA(isA<PaymentHandoffUnavailable>()),
    );
  });
}

CustomerPayment _payment(CustomerPaymentMethod method) => CustomerPayment(
  id: 'payment-test-001',
  orderReference: 'checkout-test-001',
  method: method,
  status: 'PROVIDER_ORDER_CREATED',
  amount: const CatalogMoney(amountMinor: 14785, currency: 'INR'),
  allowedActions: const {'CHECK_STATUS'},
  updatedAt: DateTime.utc(2026, 8, 28),
);

final class _RecordingCheckout implements NativeProviderCheckout {
  CustomerPayment? value;
  @override
  Future<void> launch(CustomerPayment payment) async => value = payment;
}
