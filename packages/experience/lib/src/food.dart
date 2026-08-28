import 'package:flutter/foundation.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';

import 'catalog.dart';

enum FoodExperienceStatus { idle, loading, ready, submitting, failure, offline }

final class FoodRestaurant {
  const FoodRestaurant({
    required this.id,
    required this.name,
    required this.cuisine,
    required this.rating,
    required this.verified,
    required this.open,
    required this.preparationMinutes,
    required this.deliveryFee,
    required this.minimumOrder,
  });

  factory FoodRestaurant.fromJson(Object? value) {
    final json = _object(value, 'restaurant');
    final rating = _number(json, 'rating');
    if (rating < 0 || rating > 5) {
      throw const FormatException('Restaurant rating is invalid.');
    }
    return FoodRestaurant(
      id: _string(json, 'id'),
      name: _string(json, 'name'),
      cuisine: _strings(json, 'cuisine'),
      rating: rating,
      verified: _boolean(json, 'verified'),
      open: _boolean(json, 'open'),
      preparationMinutes: _integer(json, 'preparation_minutes'),
      deliveryFee: CatalogMoney.fromJson(json['delivery_fee']),
      minimumOrder: CatalogMoney.fromJson(json['minimum_order']),
    );
  }

  final String id;
  final String name;
  final List<String> cuisine;
  final double rating;
  final bool verified;
  final bool open;
  final int preparationMinutes;
  final CatalogMoney deliveryFee;
  final CatalogMoney minimumOrder;
}

final class FoodOption {
  const FoodOption({
    required this.id,
    required this.name,
    required this.priceDelta,
    required this.available,
  });

  factory FoodOption.fromJson(Object? value) {
    final json = _object(value, 'food option');
    return FoodOption(
      id: _string(json, 'id'),
      name: _string(json, 'name'),
      priceDelta: CatalogMoney.fromJson(json['price_delta']),
      available: _boolean(json, 'available'),
    );
  }

  final String id;
  final String name;
  final CatalogMoney priceDelta;
  final bool available;
}

final class FoodOptionGroup {
  const FoodOptionGroup({
    required this.id,
    required this.name,
    required this.minimum,
    required this.maximum,
    required this.options,
  });

  factory FoodOptionGroup.fromJson(Object? value) {
    final json = _object(value, 'food option group');
    final minimum = _integer(json, 'minimum');
    final maximum = _integer(json, 'maximum');
    if (minimum < 0 || maximum < minimum) {
      throw const FormatException('Food option constraints are invalid.');
    }
    return FoodOptionGroup(
      id: _string(json, 'id'),
      name: _string(json, 'name'),
      minimum: minimum,
      maximum: maximum,
      options: _list(json, 'options').map(FoodOption.fromJson).toList(),
    );
  }

  final String id;
  final String name;
  final int minimum;
  final int maximum;
  final List<FoodOption> options;
}

final class FoodMenuItem {
  const FoodMenuItem({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.description,
    required this.category,
    required this.vegetarian,
    required this.basePrice,
    required this.available,
    required this.optionGroups,
  });

  factory FoodMenuItem.fromJson(Object? value) {
    final json = _object(value, 'menu item');
    return FoodMenuItem(
      id: _string(json, 'id'),
      restaurantId: _string(json, 'restaurant_id'),
      name: _string(json, 'name'),
      description: _string(json, 'description'),
      category: _string(json, 'category'),
      vegetarian: _boolean(json, 'vegetarian'),
      basePrice: CatalogMoney.fromJson(json['base_price']),
      available: _boolean(json, 'available'),
      optionGroups: _list(
        json,
        'option_groups',
      ).map(FoodOptionGroup.fromJson).toList(),
    );
  }

  final String id;
  final String restaurantId;
  final String name;
  final String description;
  final String category;
  final bool vegetarian;
  final CatalogMoney basePrice;
  final bool available;
  final List<FoodOptionGroup> optionGroups;
}

final class FoodCartLineRequest {
  const FoodCartLineRequest({
    required this.menuItemId,
    required this.quantity,
    this.optionIds = const [],
    this.note = '',
  });

  final String menuItemId;
  final int quantity;
  final List<String> optionIds;
  final String note;

  Map<String, Object?> toJson() => {
    'menu_item_id': menuItemId,
    'quantity': quantity,
    'option_ids': optionIds,
    if (note.trim().isNotEmpty) 'note': note.trim(),
  };
}

final class FoodCart {
  const FoodCart({
    required this.id,
    required this.revision,
    required this.restaurant,
    required this.lines,
    required this.subtotal,
    required this.deliveryFee,
    required this.tax,
    required this.total,
    required this.pricingVersion,
    required this.expiresAt,
  });

  factory FoodCart.fromJson(Object? value) {
    final json = _object(value, 'food cart');
    final expiresAt = _instant(json, 'expires_at');
    final lines = _list(json, 'lines');
    if (lines.isEmpty) throw const FormatException('Food cart is empty.');
    return FoodCart(
      id: _string(json, 'id'),
      revision: _integer(json, 'revision'),
      restaurant: FoodRestaurant.fromJson(json['restaurant']),
      lines: List.unmodifiable(lines.cast<Map<String, Object?>>()),
      subtotal: CatalogMoney.fromJson(json['subtotal']),
      deliveryFee: CatalogMoney.fromJson(json['delivery_fee']),
      tax: CatalogMoney.fromJson(json['tax']),
      total: CatalogMoney.fromJson(json['total']),
      pricingVersion: _string(json, 'pricing_version'),
      expiresAt: expiresAt,
    );
  }

  final String id;
  final int revision;
  final FoodRestaurant restaurant;
  final List<Map<String, Object?>> lines;
  final CatalogMoney subtotal;
  final CatalogMoney deliveryFee;
  final CatalogMoney tax;
  final CatalogMoney total;
  final String pricingVersion;
  final DateTime expiresAt;

  bool expiredAt(DateTime now) => !expiresAt.isAfter(now.toUtc());
}

final class FoodOrder {
  const FoodOrder({
    required this.id,
    required this.revision,
    required this.restaurantId,
    required this.status,
    required this.total,
    required this.paymentStatus,
    required this.refundState,
    required this.pricingVersion,
    required this.acceptBy,
    required this.allowedActions,
    required this.timeline,
  });

  factory FoodOrder.fromJson(Object? value) {
    final json = _object(value, 'food order');
    final payment = _object(json['payment'], 'food payment');
    return FoodOrder(
      id: _string(json, 'id'),
      revision: _integer(json, 'revision'),
      restaurantId: _string(json, 'restaurant_id'),
      status: _string(json, 'status'),
      total: CatalogMoney.fromJson(json['total']),
      paymentStatus: _string(payment, 'status'),
      refundState: payment['refund_state'] as String? ?? '',
      pricingVersion: _string(json, 'pricing_version'),
      acceptBy: _instant(json, 'accept_by'),
      allowedActions: Set.unmodifiable(_strings(json, 'allowed_actions')),
      timeline: List.unmodifiable(_list(json, 'timeline')),
    );
  }

  final String id;
  final int revision;
  final String restaurantId;
  final String status;
  final CatalogMoney total;
  final String paymentStatus;
  final String refundState;
  final String pricingVersion;
  final DateTime acceptBy;
  final Set<String> allowedActions;
  final List<Object?> timeline;

  bool get isRefunded => refundState == 'REFUNDED';
}

abstract interface class FoodRemote {
  Future<List<FoodRestaurant>> restaurants(String postalCode);
  Future<List<FoodMenuItem>> menu(String restaurantId);
  Future<FoodCart> priceCart({
    required String restaurantId,
    required String postalCode,
    required List<FoodCartLineRequest> lines,
  });
  Future<FoodOrder> placeOrder(String cartId, String paymentMethod);
  Future<List<FoodOrder>> orders();
  Future<FoodOrder> order(String id);
}

final class FoodApi implements FoodRemote {
  const FoodApi(this._client);
  final ApiClient _client;

  @override
  Future<List<FoodRestaurant>> restaurants(String postalCode) async {
    final response = await _client.send(
      ApiRequest.get(
        operation: 'food.list_restaurants',
        path: '/v1/restaurants',
        query: {
          'postal_code': [postalCode],
        },
      ),
      (json) => _decodeWrappedList(json, 'items', FoodRestaurant.fromJson),
    );
    return response.value;
  }

  @override
  Future<List<FoodMenuItem>> menu(String restaurantId) async {
    final response = await _client.send(
      ApiRequest.get(
        operation: 'food.get_menu',
        path: '/v1/restaurants/${Uri.encodeComponent(restaurantId)}/menu',
      ),
      (json) => _decodeWrappedList(json, 'items', FoodMenuItem.fromJson),
    );
    return response.value;
  }

  @override
  Future<FoodCart> priceCart({
    required String restaurantId,
    required String postalCode,
    required List<FoodCartLineRequest> lines,
  }) async {
    final response = await _client.send(
      ApiRequest.command(
        operation: 'food.price_cart',
        method: 'POST',
        path: '/v1/food-carts',
        body: {
          'restaurant_id': restaurantId,
          'postal_code': postalCode,
          'lines': lines.map((line) => line.toJson()).toList(),
        },
      ),
      FoodCart.fromJson,
    );
    return response.value;
  }

  @override
  Future<FoodOrder> placeOrder(String cartId, String paymentMethod) async {
    final response = await _client.send(
      ApiRequest.command(
        operation: 'food.create_order',
        method: 'POST',
        path: '/v1/food-orders',
        body: {'cart_id': cartId, 'payment_method': paymentMethod},
      ),
      FoodOrder.fromJson,
    );
    return response.value;
  }

  @override
  Future<List<FoodOrder>> orders() async {
    final response = await _client.send(
      ApiRequest.get(operation: 'food.list_orders', path: '/v1/food-orders'),
      (json) => _decodeWrappedList(json, 'items', FoodOrder.fromJson),
    );
    return response.value;
  }

  @override
  Future<FoodOrder> order(String id) async {
    final response = await _client.send(
      ApiRequest.get(
        operation: 'food.get_order',
        path: '/v1/food-orders/${Uri.encodeComponent(id)}',
      ),
      FoodOrder.fromJson,
    );
    return response.value;
  }
}

final class FoodExperienceState {
  const FoodExperienceState({
    this.status = FoodExperienceStatus.idle,
    this.restaurants = const [],
    this.menu = const [],
    this.orders = const [],
    this.cart,
    this.activeOrder,
    this.message,
  });

  final FoodExperienceStatus status;
  final List<FoodRestaurant> restaurants;
  final List<FoodMenuItem> menu;
  final List<FoodOrder> orders;
  final FoodCart? cart;
  final FoodOrder? activeOrder;
  final String? message;

  FoodExperienceState copyWith({
    FoodExperienceStatus? status,
    List<FoodRestaurant>? restaurants,
    List<FoodMenuItem>? menu,
    List<FoodOrder>? orders,
    FoodCart? cart,
    FoodOrder? activeOrder,
    String? message,
    bool clearMessage = false,
  }) => FoodExperienceState(
    status: status ?? this.status,
    restaurants: restaurants ?? this.restaurants,
    menu: menu ?? this.menu,
    orders: orders ?? this.orders,
    cart: cart ?? this.cart,
    activeOrder: activeOrder ?? this.activeOrder,
    message: clearMessage ? null : message ?? this.message,
  );
}

final class FoodController extends ChangeNotifier {
  FoodController({required FoodRemote remote, this.postalCode = '600001'})
    : _remote = remote;

  final FoodRemote _remote;
  final String postalCode;
  FoodExperienceState _state = const FoodExperienceState();
  FoodExperienceState get state => _state;

  Future<void> loadRestaurants() => _run(() async {
    final values = await _remote.restaurants(postalCode);
    _state = _state.copyWith(restaurants: values);
  });

  Future<void> openRestaurant(FoodRestaurant restaurant) => _run(() async {
    final values = await _remote.menu(restaurant.id);
    _state = _state.copyWith(menu: values);
  });

  Future<FoodCart?> quote(
    FoodRestaurant restaurant,
    List<FoodCartLineRequest> lines,
  ) async {
    if (lines.isEmpty || lines.any((line) => line.quantity < 1)) return null;
    return _submit(() async {
      final cart = await _remote.priceCart(
        restaurantId: restaurant.id,
        postalCode: postalCode,
        lines: lines,
      );
      _state = _state.copyWith(cart: cart);
      return cart;
    });
  }

  Future<FoodOrder?> place({String paymentMethod = 'WALLET'}) async {
    final cart = _state.cart;
    if (cart == null || cart.expiredAt(DateTime.now())) {
      _fail('The restaurant price expired. Review the cart again.');
      return null;
    }
    return _submit(() async {
      final order = await _remote.placeOrder(cart.id, paymentMethod);
      _state = _state.copyWith(
        activeOrder: order,
        orders: [order, ..._state.orders.where((item) => item.id != order.id)],
      );
      return order;
    });
  }

  Future<void> loadOrders() => _run(() async {
    final values = await _remote.orders();
    _state = _state.copyWith(orders: values);
  });

  Future<void> refreshActiveOrder() async {
    final active = _state.activeOrder;
    if (active == null) return;
    await _run(() async {
      final value = await _remote.order(active.id);
      _state = _state.copyWith(activeOrder: value);
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    _state = _state.copyWith(
      status: FoodExperienceStatus.loading,
      clearMessage: true,
    );
    notifyListeners();
    try {
      await action();
      _state = _state.copyWith(status: FoodExperienceStatus.ready);
    } on ApiTransportFailure {
      _state = _state.copyWith(
        status: FoodExperienceStatus.offline,
        message:
            'You appear to be offline. Saved order details remain visible.',
      );
    } catch (_) {
      _fail('Food service is unavailable. Try again.');
    }
    notifyListeners();
  }

  Future<T?> _submit<T>(Future<T> Function() action) async {
    _state = _state.copyWith(
      status: FoodExperienceStatus.submitting,
      clearMessage: true,
    );
    notifyListeners();
    try {
      final result = await action();
      _state = _state.copyWith(status: FoodExperienceStatus.ready);
      notifyListeners();
      return result;
    } catch (_) {
      _fail('The request could not be completed safely. Try again.');
      notifyListeners();
      return null;
    }
  }

  void _fail(String message) {
    _state = _state.copyWith(
      status: FoodExperienceStatus.failure,
      message: message,
    );
  }
}

Map<String, Object?> _object(Object? value, String label) {
  if (value is! Map<String, Object?>) {
    throw FormatException('$label contract is invalid.');
  }
  return value;
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key is invalid.');
  }
  return value;
}

int _integer(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('$key is invalid.');
  return value;
}

double _number(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! num) throw FormatException('$key is invalid.');
  return value.toDouble();
}

bool _boolean(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('$key is invalid.');
  return value;
}

List<Object?> _list(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List<Object?>) throw FormatException('$key is invalid.');
  return value;
}

List<String> _strings(Map<String, Object?> json, String key) =>
    List.unmodifiable(_list(json, key).cast<String>());

DateTime _instant(Map<String, Object?> json, String key) {
  final value = DateTime.tryParse(_string(json, key));
  if (value == null) throw FormatException('$key is invalid.');
  return value.toUtc();
}

List<T> _decodeList<T>(Object? value, T Function(Object?) decode) {
  if (value is! List<Object?>) throw const FormatException('List is invalid.');
  return List.unmodifiable(value.map(decode));
}

List<T> _decodeWrappedList<T>(
  Object? value,
  String key,
  T Function(Object?) decode,
) => _decodeList(_object(value, 'list response')[key], decode);
