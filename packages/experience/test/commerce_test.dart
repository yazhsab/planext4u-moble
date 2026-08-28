import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

void main() {
  test('cart decodes the pinned backend fixture and checkout capability', () {
    final fixture = File(
      '${_workspaceRoot().path}/packages/api_client/contracts/commerce_cart.fixture.json',
    );
    final cart = CustomerCart.fromJson(jsonDecode(fixture.readAsStringSync()));

    expect(
      cart.total.display(),
      '\u20B9'
      '130.00',
    );
    expect(cart.revision, 1);
    expect(cart.items.single.quantity, 2);
    expect(cart.canCheckout, isTrue);
  });

  test(
    'controller preserves authoritative totals returned by the server',
    () async {
      final remote = _FixedCartRemote(
        initial: CustomerCart.fromJson(_cartJson(totalMinor: 13000)),
        updated: CustomerCart.fromJson(
          _cartJson(revision: 2, quantity: 2, totalMinor: 99900),
        ),
      );
      final controller = CartController(remote: remote);

      await controller.load();
      expect(await controller.setItem('variant-500ml', 2), isTrue);

      expect(remote.lastExpectedRevision, 1);
      expect(
        controller.state.cart?.total.display(),
        '\u20B9'
        '999.00',
      );
      expect(controller.state.cart?.items.single.quantity, 2);
    },
  );

  test(
    'revision conflicts refresh the cart and require customer review',
    () async {
      final initial = CustomerCart.fromJson(_cartJson(totalMinor: 13000));
      final refreshed = CustomerCart.fromJson(
        _cartJson(revision: 2, quantity: 2, totalMinor: 26000),
      );
      final remote = _ConflictCartRemote(
        initial: initial,
        refreshed: refreshed,
      );
      final controller = CartController(remote: remote);

      await controller.load();
      expect(await controller.setItem('variant-500ml', 3), isFalse);

      expect(controller.state.status, CartStatus.conflict);
      expect(controller.state.cart?.revision, 2);
      expect(controller.state.message, contains('cart changed'));
    },
  );
}

Directory _workspaceRoot() {
  var directory = Directory.current.absolute;
  while (directory.parent.path != directory.path) {
    if (File(
      '${directory.path}/packages/api_client/contracts/commerce_cart.fixture.json',
    ).existsSync()) {
      return directory;
    }
    directory = directory.parent;
  }
  throw StateError('Planext4u workspace root was not found.');
}

Map<String, Object?> _cartJson({
  int revision = 1,
  int quantity = 1,
  required int totalMinor,
}) => {
  'id': 'cart-customer-1',
  'revision': revision,
  'items': [
    {
      'variant_id': 'variant-500ml',
      'item_id': 'item-sesame-oil',
      'vendor_id': 'vendor-local-001',
      'item_name': 'Cold-pressed sesame oil',
      'variant_name': '500 ml',
      'quantity': quantity,
      'unit_price': {'amount_minor': 13000, 'currency': 'INR'},
      'line_total': {'amount_minor': totalMinor, 'currency': 'INR'},
      'available': true,
      'price_changed': false,
    },
  ],
  'subtotal': {'amount_minor': totalMinor, 'currency': 'INR'},
  'discount': {'amount_minor': 0, 'currency': 'INR'},
  'tax': {'amount_minor': 0, 'currency': 'INR'},
  'fees': {'amount_minor': 0, 'currency': 'INR'},
  'total': {'amount_minor': totalMinor, 'currency': 'INR'},
  'pricing_status': 'CURRENT',
  'allowed_actions': ['CHECKOUT'],
  'updated_at': '2026-08-27T10:00:00Z',
};

final class _FixedCartRemote implements CartRemote {
  _FixedCartRemote({required this.initial, required this.updated});

  final CustomerCart initial;
  final CustomerCart updated;
  int? lastExpectedRevision;

  @override
  Future<CustomerCart> getCart() async => initial;

  @override
  Future<CustomerCart> setItem({
    required String variantId,
    required int quantity,
    required int expectedRevision,
    String? idempotencyKey,
  }) async {
    lastExpectedRevision = expectedRevision;
    return updated;
  }

  @override
  Future<CustomerCart> removeItem({
    required String variantId,
    required int expectedRevision,
    String? idempotencyKey,
  }) => throw UnimplementedError();
}

final class _ConflictCartRemote implements CartRemote {
  _ConflictCartRemote({required this.initial, required this.refreshed});

  final CustomerCart initial;
  final CustomerCart refreshed;
  var _reads = 0;

  @override
  Future<CustomerCart> getCart() async => _reads++ == 0 ? initial : refreshed;

  @override
  Future<CustomerCart> setItem({
    required String variantId,
    required int quantity,
    required int expectedRevision,
    String? idempotencyKey,
  }) async => throw const ApiConflictFailure(
    code: 'CART_REVISION_CONFLICT',
    message: 'The cart was updated by another request.',
    correlationId: 'corr-conflict',
    retryable: false,
    statusCode: 409,
  );

  @override
  Future<CustomerCart> removeItem({
    required String variantId,
    required int expectedRevision,
    String? idempotencyKey,
  }) => throw UnimplementedError();
}
