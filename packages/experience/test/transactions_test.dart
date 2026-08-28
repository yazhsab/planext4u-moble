import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

void main() {
  test('pinned Phase 3 quote, payment, order and wallet fixtures decode', () {
    final root = _workspaceRoot().path;
    final quote = CheckoutQuote.fromJson(
      jsonDecode(
        File(
          '$root/packages/api_client/contracts/checkout_quote.fixture.json',
        ).readAsStringSync(),
      ),
    );
    final payment = CustomerPayment.fromJson(
      jsonDecode(
        File(
          '$root/packages/api_client/contracts/payment.fixture.json',
        ).readAsStringSync(),
      ),
    );
    final order = CustomerOrder.fromJson(
      jsonDecode(
        File(
          '$root/packages/api_client/contracts/order.fixture.json',
        ).readAsStringSync(),
      ),
    );
    final wallet = WalletAccount.fromJson(
      jsonDecode(
        File(
          '$root/packages/api_client/contracts/wallet.fixture.json',
        ).readAsStringSync(),
      ),
    );
    expect(quote.total.display(), '₹147.85');
    expect(quote.paymentMethods, contains(CustomerPaymentMethod.cod));
    expect(payment.pending, isTrue);
    expect(order.status, 'PLACED');
    expect(wallet.balance, 24000);
    expect(wallet.reconciles, isTrue);
  });

  test(
    'controller uses only server quote totals and persists pending recovery',
    () async {
      final remote = _TransactionRemote();
      final recovery = MemoryPaymentRecoveryStore();
      final controller = TransactionController(
        remote: remote,
        recoveryStore: recovery,
      );
      await controller.loadCheckout();
      expect(
        await controller.createQuote(
          cartRevision: 7,
          addressId: 'address-1',
          slotId: 'slot-1',
          promotionCode: 'local10',
          walletPoints: 25,
        ),
        isTrue,
      );
      expect(controller.state.quote?.total.amountMinor, 98765);
      final result = await controller.place(CustomerPaymentMethod.razorpay);
      expect(result?.payment.pending, isTrue);
      expect(await recovery.read(), 'payment-1');
      await controller.recoverPayment();
      expect(controller.state.status, TransactionStatus.success);
      expect(await recovery.read(), isNull);
    },
  );
}

Directory _workspaceRoot() {
  var directory = Directory.current.absolute;
  while (directory.parent.path != directory.path) {
    if (File(
      '${directory.path}/packages/api_client/contracts/transaction.openapi.json',
    ).existsSync()) {
      return directory;
    }
    directory = directory.parent;
  }
  throw StateError('Workspace not found.');
}

final class _TransactionRemote implements TransactionRemote {
  final now = DateTime.utc(2026, 8, 27, 10);
  late final quoteValue = CheckoutQuote.fromJson({
    'id': 'quote-1',
    'cart_revision': 7,
    'items': [_line],
    'address': {
      'id': 'address-1',
      'label': 'Home',
      'postal_code': '600001',
      'locality': 'Chennai',
    },
    'delivery': {
      'id': 'slot-1',
      'country': 'IN',
      'window_start': '2026-08-28T10:00:00Z',
      'window_end': '2026-08-28T14:00:00Z',
      'fee': {'amount_minor': 1000, 'currency': 'INR'},
      'capacity': 10,
    },
    'subtotal': _money(100000),
    'discount': _money(5000),
    'tax': _money(4000),
    'fees': _money(1000),
    'wallet_applied': _money(1235),
    'wallet_points_redeemed': 1235,
    'total': _money(98765),
    'promotion_code': 'LOCAL10',
    'pricing_policy_version': 'pricing-v1',
    'payment_methods': ['RAZORPAY', 'COD'],
    'warnings': <String>[],
    'allowed_actions': ['PLACE_ORDER'],
    'expires_at': '2026-08-27T10:10:00Z',
    'created_at': '2026-08-27T10:00:00Z',
  });
  late final orderValue = CustomerOrder.fromJson({
    'id': 'order-1',
    'revision': 1,
    'status': 'PENDING_PAYMENT',
    'snapshot': {'total': _money(98765), 'payment_method': 'RAZORPAY'},
    'allowed_actions': ['CHECK_PAYMENT'],
    'timeline': [
      {
        'status': 'PENDING_PAYMENT',
        'actor': 'PLATFORM',
        'created_at': '2026-08-27T10:00:00Z',
      },
    ],
    'created_at': '2026-08-27T10:00:00Z',
    'updated_at': '2026-08-27T10:00:00Z',
  });
  CustomerPayment _payment(String status) => CustomerPayment.fromJson({
    'id': 'payment-1',
    'order_reference': 'checkout-1',
    'method': 'RAZORPAY',
    'status': status,
    'amount': _money(98765),
    'provider_reference': 'provider-1',
    'allowed_actions': status == 'RECONCILED'
        ? ['VIEW_ORDER']
        : ['CHECK_STATUS'],
    'created_at': '2026-08-27T10:00:00Z',
    'updated_at': '2026-08-27T10:00:00Z',
  });
  @override
  Future<List<CustomerAddress>> addresses() async => [
    CustomerAddress.fromJson({
      'id': 'address-1',
      'label': 'Home',
      'postal_code': '600001',
      'locality': 'Chennai',
    }),
  ];
  @override
  Future<List<CustomerDeliverySlot>> deliverySlots() async => [
    quoteValue.delivery,
  ];
  @override
  Future<WalletAccount> wallet() async =>
      WalletAccount.fromJson({'balance': 0, 'entries': <Object?>[]});
  @override
  Future<CheckoutQuote> quote({
    required int cartRevision,
    required String addressId,
    required String deliverySlotId,
    required String promotionCode,
    required int walletPoints,
    String? idempotencyKey,
  }) async => quoteValue;
  @override
  Future<PlaceOrderResult> place({
    required String quoteId,
    required CustomerPaymentMethod method,
    String? idempotencyKey,
  }) async => PlaceOrderResult(
    quote: quoteValue,
    payment: _payment('PROVIDER_ORDER_CREATED'),
    order: orderValue,
  );
  @override
  Future<CustomerPayment> payment(String id) async => _payment('RECONCILED');
  @override
  Future<List<CustomerOrder>> orders() async => [orderValue];
  @override
  Future<CustomerOrder> order(String id) async => orderValue;
  @override
  Future<CustomerOrder> cancel({
    required CustomerOrder order,
    required String reason,
  }) async => order;
  @override
  Future<CustomerOrder> confirmDelivery(CustomerOrder order) async => order;
  @override
  Future<CustomerOrder> requestReturn({
    required CustomerOrder order,
    required List<Map<String, Object?>> lines,
    required String reason,
  }) async => order;
  @override
  Future<CustomerOrder> rate({
    required CustomerOrder order,
    required int score,
    required String comment,
  }) async => order;
}

const _line = {
  'variant_id': 'variant-1',
  'item_id': 'item-1',
  'vendor_id': 'vendor-1',
  'item_name': 'Local item',
  'variant_name': 'Standard',
  'quantity': 1,
  'unit_price': {'amount_minor': 100000, 'currency': 'INR'},
  'line_total': {'amount_minor': 100000, 'currency': 'INR'},
  'available': true,
  'price_changed': false,
};
Map<String, Object?> _money(int value) => {
  'amount_minor': value,
  'currency': 'INR',
};
