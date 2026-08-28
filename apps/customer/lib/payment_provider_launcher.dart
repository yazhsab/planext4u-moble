import 'dart:async';

import 'package:paystack_flutter_sdk/paystack_flutter_sdk.dart';
import 'package:planext4u_experience/planext4u_experience.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

final class PaymentProviderCancelled implements Exception {
  const PaymentProviderCancelled();
}

final class PaymentProviderFailed implements Exception {
  const PaymentProviderFailed(this.message);
  final String message;
}

/// Launches only provider sessions created and signed by the Planext4u
/// backend. No merchant secret is accepted by this adapter.
final class NativePaymentProviderLauncher implements PaymentProviderLauncher {
  NativePaymentProviderLauncher({
    NativeProviderCheckout? razorpay,
    NativeProviderCheckout? paystack,
  }) : _razorpay = razorpay ?? const RazorpayNativeCheckout(),
       _paystack = paystack ?? PaystackNativeCheckout();

  final NativeProviderCheckout _razorpay;
  final NativeProviderCheckout _paystack;

  @override
  Future<void> launch(CustomerPayment payment) async {
    switch (payment.method) {
      case CustomerPaymentMethod.razorpay:
        await _razorpay.launch(payment);
        return;
      case CustomerPaymentMethod.paystack:
        await _paystack.launch(payment);
        return;
      default:
        throw const PaymentHandoffUnavailable();
    }
  }
}

abstract interface class NativeProviderCheckout {
  Future<void> launch(CustomerPayment payment);
}

final class RazorpayNativeCheckout implements NativeProviderCheckout {
  const RazorpayNativeCheckout();

  @override
  Future<void> launch(CustomerPayment payment) async {
    final handoff = payment.clientHandoff;
    if (handoff == null ||
        handoff.type != 'RAZORPAY_CHECKOUT' ||
        handoff.providerOrderId == null) {
      throw const PaymentHandoffUnavailable();
    }
    final provider = Razorpay();
    final result = Completer<void>();
    provider.on(Razorpay.EVENT_PAYMENT_SUCCESS, (Object? value) {
      if (result.isCompleted) return;
      if (value is PaymentSuccessResponse &&
          value.orderId == handoff.providerOrderId &&
          value.paymentId != null) {
        result.complete();
      } else {
        result.completeError(
          const PaymentProviderFailed('Razorpay returned an invalid result.'),
        );
      }
    });
    provider.on(Razorpay.EVENT_PAYMENT_ERROR, (Object? value) {
      if (result.isCompleted) return;
      if (value is PaymentFailureResponse &&
          value.code == Razorpay.PAYMENT_CANCELLED) {
        result.completeError(const PaymentProviderCancelled());
      } else {
        result.completeError(
          PaymentProviderFailed(
            value is PaymentFailureResponse
                ? value.message ?? 'Razorpay could not complete payment.'
                : 'Razorpay could not complete payment.',
          ),
        );
      }
    });
    try {
      provider.open({
        'key': handoff.publicKey,
        'order_id': handoff.providerOrderId,
        'amount': payment.amount.amountMinor,
        'currency': payment.amount.currency,
        'name': 'Planext4u',
        'description': 'Order ${payment.orderReference}',
        'retry': {'enabled': false},
      });
      await result.future.timeout(const Duration(minutes: 10));
    } on TimeoutException {
      throw const PaymentProviderFailed('Razorpay checkout timed out.');
    } finally {
      provider.clear();
    }
  }
}

final class PaystackNativeCheckout implements NativeProviderCheckout {
  PaystackNativeCheckout({Paystack? paystack})
    : _paystack = paystack ?? Paystack();

  final Paystack _paystack;

  @override
  Future<void> launch(CustomerPayment payment) async {
    final handoff = payment.clientHandoff;
    if (handoff == null ||
        handoff.type != 'PAYSTACK_CHECKOUT' ||
        handoff.accessCode == null) {
      throw const PaymentHandoffUnavailable();
    }
    final initialized = await _paystack.initialize(handoff.publicKey, false);
    if (!initialized) {
      throw const PaymentProviderFailed('Paystack could not be initialized.');
    }
    final response = await _paystack.launch(handoff.accessCode!);
    switch (response.status.toLowerCase()) {
      case 'success':
        if (response.reference != payment.providerReference) {
          throw const PaymentProviderFailed(
            'Paystack returned an invalid payment reference.',
          );
        }
        return;
      case 'cancelled':
      case 'canceled':
        throw const PaymentProviderCancelled();
      default:
        throw PaymentProviderFailed(
          response.message.isEmpty
              ? 'Paystack could not complete payment.'
              : response.message,
        );
    }
  }
}
