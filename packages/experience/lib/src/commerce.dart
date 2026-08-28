import 'package:flutter/foundation.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';

import 'catalog.dart';

enum CartPricingStatus { current, repriced }

final class CartLine {
  const CartLine({
    required this.variantId,
    required this.itemId,
    required this.vendorId,
    required this.itemName,
    required this.variantName,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.available,
    required this.priceChanged,
    this.mediaRef,
  });

  factory CartLine.fromJson(Object? value) {
    final json = _commerceObject(value, 'cart line');
    final quantity = _commerceInteger(json, 'quantity');
    if (quantity < 1 || quantity > 999) {
      throw const FormatException('Cart quantity is invalid.');
    }
    return CartLine(
      variantId: _commerceString(json, 'variant_id'),
      itemId: _commerceString(json, 'item_id'),
      vendorId: _commerceString(json, 'vendor_id'),
      itemName: _commerceString(json, 'item_name'),
      variantName: _commerceString(json, 'variant_name'),
      mediaRef: json['media_ref'] as String?,
      quantity: quantity,
      unitPrice: CatalogMoney.fromJson(json['unit_price']),
      lineTotal: CatalogMoney.fromJson(json['line_total']),
      available: _commerceBoolean(json, 'available'),
      priceChanged: _commerceBoolean(json, 'price_changed'),
    );
  }

  final String variantId;
  final String itemId;
  final String vendorId;
  final String itemName;
  final String variantName;
  final String? mediaRef;
  final int quantity;
  final CatalogMoney unitPrice;
  final CatalogMoney lineTotal;
  final bool available;
  final bool priceChanged;
}

final class CustomerCart {
  const CustomerCart({
    required this.id,
    required this.revision,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.fees,
    required this.total,
    required this.pricingStatus,
    required this.allowedActions,
    required this.updatedAt,
  });

  factory CustomerCart.fromJson(Object? value) {
    final json = _commerceObject(value, 'cart');
    final revision = _commerceInteger(json, 'revision');
    if (revision < 0) throw const FormatException('Cart revision is invalid.');
    final actions = json['allowed_actions'];
    if (actions is! List<Object?> || actions.any((value) => value is! String)) {
      throw const FormatException('Cart allowed actions are invalid.');
    }
    return CustomerCart(
      id: _commerceString(json, 'id'),
      revision: revision,
      items: List<CartLine>.unmodifiable(
        _commerceList(json, 'items').map(CartLine.fromJson),
      ),
      subtotal: CatalogMoney.fromJson(json['subtotal']),
      discount: CatalogMoney.fromJson(json['discount']),
      tax: CatalogMoney.fromJson(json['tax']),
      fees: CatalogMoney.fromJson(json['fees']),
      total: CatalogMoney.fromJson(json['total']),
      pricingStatus: switch (json['pricing_status']) {
        'CURRENT' => CartPricingStatus.current,
        'REPRICED' => CartPricingStatus.repriced,
        _ => throw const FormatException('Cart pricing status is invalid.'),
      },
      allowedActions: Set<String>.unmodifiable(actions.cast<String>()),
      updatedAt: _commerceInstant(json, 'updated_at'),
    );
  }

  final String id;
  final int revision;
  final List<CartLine> items;
  final CatalogMoney subtotal;
  final CatalogMoney discount;
  final CatalogMoney tax;
  final CatalogMoney fees;
  final CatalogMoney total;
  final CartPricingStatus pricingStatus;
  final Set<String> allowedActions;
  final DateTime updatedAt;

  bool get canCheckout => allowedActions.contains('CHECKOUT');
}

abstract interface class CartRemote {
  Future<CustomerCart> getCart();
  Future<CustomerCart> setItem({
    required String variantId,
    required int quantity,
    required int expectedRevision,
    String? idempotencyKey,
  });
  Future<CustomerCart> removeItem({
    required String variantId,
    required int expectedRevision,
    String? idempotencyKey,
  });
}

final class CartApi implements CartRemote {
  const CartApi(this._client);
  final ApiClient _client;

  @override
  Future<CustomerCart> getCart() async => (await _client.send(
    ApiRequest.get(operation: 'commerce.get_cart', path: '/v1/cart'),
    CustomerCart.fromJson,
  )).value;

  @override
  Future<CustomerCart> setItem({
    required String variantId,
    required int quantity,
    required int expectedRevision,
    String? idempotencyKey,
  }) async => (await _client.send(
    ApiRequest.command(
      operation: 'commerce.set_cart_item',
      method: 'PUT',
      path: '/v1/cart/items/${Uri.encodeComponent(variantId)}',
      body: {'quantity': quantity},
      headers: {'If-Match': '"$expectedRevision"'},
      idempotencyKey: idempotencyKey,
    ),
    CustomerCart.fromJson,
  )).value;

  @override
  Future<CustomerCart> removeItem({
    required String variantId,
    required int expectedRevision,
    String? idempotencyKey,
  }) async => (await _client.send(
    ApiRequest.command(
      operation: 'commerce.remove_cart_item',
      method: 'DELETE',
      path: '/v1/cart/items/${Uri.encodeComponent(variantId)}',
      body: null,
      headers: {'If-Match': '"$expectedRevision"'},
      idempotencyKey: idempotencyKey,
    ),
    CustomerCart.fromJson,
  )).value;
}

enum CartStatus { loading, ready, updating, conflict, unavailable, failure }

final class CartState {
  const CartState({required this.status, this.cart, this.message});
  final CartStatus status;
  final CustomerCart? cart;
  final String? message;
}

final class CartController extends ChangeNotifier {
  CartController({required CartRemote remote}) : _remote = remote;

  final CartRemote _remote;
  CartState _state = const CartState(status: CartStatus.loading);
  CartState get state => _state;

  Future<void> load() async {
    _set(CartState(status: CartStatus.loading, cart: _state.cart));
    try {
      _set(CartState(status: CartStatus.ready, cart: await _remote.getCart()));
    } catch (_) {
      _set(CartState(status: CartStatus.failure, cart: _state.cart));
    }
  }

  Future<bool> setItem(String variantId, int quantity) async {
    var current = _state.cart;
    if (current == null) {
      await load();
      current = _state.cart;
    }
    if (current == null) return false;
    _set(CartState(status: CartStatus.updating, cart: current));
    try {
      final updated = await _remote.setItem(
        variantId: variantId,
        quantity: quantity,
        expectedRevision: current.revision,
      );
      _set(CartState(status: CartStatus.ready, cart: updated));
      return true;
    } on ApiConflictFailure catch (failure) {
      if (failure.code == 'CART_REVISION_CONFLICT') {
        CustomerCart? refreshed;
        try {
          refreshed = await _remote.getCart();
        } catch (_) {
          refreshed = current;
        }
        _set(
          CartState(
            status: CartStatus.conflict,
            cart: refreshed,
            message: 'Your cart changed. Review the latest price and quantity.',
          ),
        );
      } else {
        _set(
          CartState(
            status: CartStatus.unavailable,
            cart: current,
            message: 'That quantity is no longer available.',
          ),
        );
      }
      return false;
    } catch (_) {
      _set(CartState(status: CartStatus.failure, cart: current));
      return false;
    }
  }

  Future<bool> removeItem(String variantId) async {
    final current = _state.cart;
    if (current == null) return false;
    _set(CartState(status: CartStatus.updating, cart: current));
    try {
      final updated = await _remote.removeItem(
        variantId: variantId,
        expectedRevision: current.revision,
      );
      _set(CartState(status: CartStatus.ready, cart: updated));
      return true;
    } catch (_) {
      await load();
      return false;
    }
  }

  void _set(CartState value) {
    _state = value;
    notifyListeners();
  }
}

Map<String, Object?> _commerceObject(Object? value, String label) {
  if (value is! Map<String, Object?>) {
    throw FormatException('$label must be an object.');
  }
  return value;
}

List<Object?> _commerceList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List<Object?>) throw FormatException('$key must be a list.');
  return value;
}

String _commerceString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return value;
}

int _commerceInteger(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('$key must be an integer.');
  return value;
}

bool _commerceBoolean(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('$key must be a boolean.');
  return value;
}

DateTime _commerceInstant(Map<String, Object?> json, String key) {
  final value = DateTime.tryParse(_commerceString(json, key));
  if (value == null || !value.isUtc) {
    throw FormatException('$key must be a UTC date-time.');
  }
  return value;
}
