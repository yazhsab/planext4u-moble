import 'package:flutter/foundation.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';

import 'catalog.dart';
import 'commerce.dart';

final class CustomerAddress {
  const CustomerAddress({
    required this.id,
    required this.label,
    required this.postalCode,
    required this.locality,
  });
  factory CustomerAddress.fromJson(Object? value) {
    final json = _txObject(value, 'address');
    return CustomerAddress(
      id: _txString(json, 'id'),
      label: _txString(json, 'label'),
      postalCode: _txString(json, 'postal_code'),
      locality: _txString(json, 'locality'),
    );
  }
  final String id;
  final String label;
  final String postalCode;
  final String locality;
}

final class CustomerDeliverySlot {
  const CustomerDeliverySlot({
    required this.id,
    required this.country,
    required this.windowStart,
    required this.windowEnd,
    required this.fee,
    required this.capacity,
  });
  factory CustomerDeliverySlot.fromJson(Object? value) {
    final json = _txObject(value, 'delivery slot');
    final start = _txInstant(json, 'window_start');
    final end = _txInstant(json, 'window_end');
    final capacity = _txInteger(json, 'capacity');
    if (!end.isAfter(start) || capacity < 0) {
      throw const FormatException('Delivery slot is invalid.');
    }
    return CustomerDeliverySlot(
      id: _txString(json, 'id'),
      country: _txString(json, 'country'),
      windowStart: start,
      windowEnd: end,
      fee: CatalogMoney.fromJson(json['fee']),
      capacity: capacity,
    );
  }
  final String id;
  final String country;
  final DateTime windowStart;
  final DateTime windowEnd;
  final CatalogMoney fee;
  final int capacity;
}

enum CustomerPaymentMethod { razorpay, paystack, cod, wallet }

extension CustomerPaymentMethodWire on CustomerPaymentMethod {
  String get wireValue => switch (this) {
    CustomerPaymentMethod.razorpay => 'RAZORPAY',
    CustomerPaymentMethod.paystack => 'PAYSTACK',
    CustomerPaymentMethod.cod => 'COD',
    CustomerPaymentMethod.wallet => 'WALLET',
  };
  String get label => switch (this) {
    CustomerPaymentMethod.razorpay => 'Razorpay',
    CustomerPaymentMethod.paystack => 'Paystack',
    CustomerPaymentMethod.cod => 'Cash on delivery',
    CustomerPaymentMethod.wallet => 'Planext points',
  };
}

CustomerPaymentMethod _paymentMethod(Object? value) => switch (value) {
  'RAZORPAY' => CustomerPaymentMethod.razorpay,
  'PAYSTACK' => CustomerPaymentMethod.paystack,
  'COD' => CustomerPaymentMethod.cod,
  'WALLET' => CustomerPaymentMethod.wallet,
  _ => throw const FormatException('Payment method is invalid.'),
};

final class CheckoutQuote {
  const CheckoutQuote({
    required this.id,
    required this.cartRevision,
    required this.items,
    required this.address,
    required this.delivery,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.fees,
    required this.walletApplied,
    required this.walletPointsRedeemed,
    required this.total,
    required this.promotionCode,
    required this.pricingPolicyVersion,
    required this.paymentMethods,
    required this.warnings,
    required this.allowedActions,
    required this.expiresAt,
  });
  factory CheckoutQuote.fromJson(Object? value) {
    final json = _txObject(value, 'checkout quote');
    final methods = _txList(
      json,
      'payment_methods',
    ).map(_paymentMethod).toList(growable: false);
    final actions = _txList(json, 'allowed_actions').cast<String>().toSet();
    if (!actions.contains('PLACE_ORDER') || methods.isEmpty) {
      throw const FormatException('Quote has no allowed placement action.');
    }
    return CheckoutQuote(
      id: _txString(json, 'id'),
      cartRevision: _txInteger(json, 'cart_revision'),
      items: List<CartLine>.unmodifiable(
        _txList(json, 'items').map(CartLine.fromJson),
      ),
      address: CustomerAddress.fromJson(json['address']),
      delivery: CustomerDeliverySlot.fromJson(json['delivery']),
      subtotal: CatalogMoney.fromJson(json['subtotal']),
      discount: CatalogMoney.fromJson(json['discount']),
      tax: CatalogMoney.fromJson(json['tax']),
      fees: CatalogMoney.fromJson(json['fees']),
      walletApplied: CatalogMoney.fromJson(json['wallet_applied']),
      walletPointsRedeemed: _txInteger(json, 'wallet_points_redeemed'),
      total: CatalogMoney.fromJson(json['total']),
      promotionCode: json['promotion_code'] as String? ?? '',
      pricingPolicyVersion: _txString(json, 'pricing_policy_version'),
      paymentMethods: List.unmodifiable(methods),
      warnings: List<String>.unmodifiable(
        _txList(json, 'warnings').cast<String>(),
      ),
      allowedActions: Set.unmodifiable(actions),
      expiresAt: _txInstant(json, 'expires_at'),
    );
  }
  final String id;
  final int cartRevision;
  final List<CartLine> items;
  final CustomerAddress address;
  final CustomerDeliverySlot delivery;
  final CatalogMoney subtotal;
  final CatalogMoney discount;
  final CatalogMoney tax;
  final CatalogMoney fees;
  final CatalogMoney walletApplied;
  final int walletPointsRedeemed;
  final CatalogMoney total;
  final String promotionCode;
  final String pricingPolicyVersion;
  final List<CustomerPaymentMethod> paymentMethods;
  final List<String> warnings;
  final Set<String> allowedActions;
  final DateTime expiresAt;
}

final class CustomerPayment {
  const CustomerPayment({
    required this.id,
    required this.orderReference,
    required this.method,
    required this.status,
    required this.amount,
    required this.allowedActions,
    required this.updatedAt,
    this.providerReference,
  });
  factory CustomerPayment.fromJson(Object? value) {
    final json = _txObject(value, 'payment');
    return CustomerPayment(
      id: _txString(json, 'id'),
      orderReference: _txString(json, 'order_reference'),
      method: _paymentMethod(json['method']),
      status: _txString(json, 'status'),
      amount: CatalogMoney.fromJson(json['amount']),
      providerReference: json['provider_reference'] as String?,
      allowedActions: Set.unmodifiable(
        _txList(json, 'allowed_actions').cast<String>(),
      ),
      updatedAt: _txInstant(json, 'updated_at'),
    );
  }
  final String id;
  final String orderReference;
  final CustomerPaymentMethod method;
  final String status;
  final CatalogMoney amount;
  final String? providerReference;
  final Set<String> allowedActions;
  final DateTime updatedAt;
  bool get pending => const {
    'PROVIDER_ORDER_CREATED',
    'AUTHORISATION_PENDING',
    'AUTHORISED',
    'FAILED_RETRYABLE',
  }.contains(status);
}

final class OrderTimelineEvent {
  const OrderTimelineEvent({
    required this.status,
    required this.actor,
    required this.createdAt,
    this.reason = '',
  });
  factory OrderTimelineEvent.fromJson(Object? value) {
    final json = _txObject(value, 'timeline event');
    return OrderTimelineEvent(
      status: _txString(json, 'status'),
      actor: _txString(json, 'actor'),
      createdAt: _txInstant(json, 'created_at'),
      reason: json['reason'] as String? ?? '',
    );
  }
  final String status;
  final String actor;
  final DateTime createdAt;
  final String reason;
}

final class CustomerOrder {
  const CustomerOrder({
    required this.id,
    required this.revision,
    required this.status,
    required this.total,
    required this.paymentMethod,
    required this.allowedActions,
    required this.timeline,
    required this.createdAt,
    this.returnState,
    this.rating,
  });
  factory CustomerOrder.fromJson(Object? value) {
    final json = _txObject(value, 'order');
    final snapshot = _txObject(json['snapshot'], 'checkout snapshot');
    final returnValue = json['return'];
    final ratingValue = json['rating'];
    return CustomerOrder(
      id: _txString(json, 'id'),
      revision: _txInteger(json, 'revision'),
      status: _txString(json, 'status'),
      total: CatalogMoney.fromJson(snapshot['total']),
      paymentMethod: _paymentMethod(snapshot['payment_method']),
      allowedActions: Set.unmodifiable(
        _txList(json, 'allowed_actions').cast<String>(),
      ),
      timeline: List<OrderTimelineEvent>.unmodifiable(
        _txList(json, 'timeline').map(OrderTimelineEvent.fromJson),
      ),
      createdAt: _txInstant(json, 'created_at'),
      returnState: returnValue is Map<String, Object?>
          ? returnValue['status'] as String?
          : null,
      rating: ratingValue is Map<String, Object?>
          ? ratingValue['score'] as int?
          : null,
    );
  }
  final String id;
  final int revision;
  final String status;
  final CatalogMoney total;
  final CustomerPaymentMethod paymentMethod;
  final Set<String> allowedActions;
  final List<OrderTimelineEvent> timeline;
  final DateTime createdAt;
  final String? returnState;
  final int? rating;
}

final class WalletEntry {
  const WalletEntry({
    required this.id,
    required this.type,
    required this.category,
    required this.sourceReference,
    required this.deltaPoints,
    required this.balanceAfter,
    required this.createdAt,
    this.originalExpiryAt,
  });
  factory WalletEntry.fromJson(Object? value) {
    final json = _txObject(value, 'wallet entry');
    return WalletEntry(
      id: _txString(json, 'id'),
      type: _txString(json, 'type'),
      category: _txString(json, 'category'),
      sourceReference: _txString(json, 'source_reference'),
      deltaPoints: _txInteger(json, 'delta_points'),
      balanceAfter: _txInteger(json, 'balance_after'),
      createdAt: _txInstant(json, 'created_at'),
      originalExpiryAt: json['original_expiry_at'] == null
          ? null
          : DateTime.parse(json['original_expiry_at']! as String).toUtc(),
    );
  }
  final String id;
  final String type;
  final String category;
  final String sourceReference;
  final int deltaPoints;
  final int balanceAfter;
  final DateTime createdAt;
  final DateTime? originalExpiryAt;
}

final class WalletAccount {
  const WalletAccount({required this.balance, required this.entries});
  factory WalletAccount.fromJson(Object? value) {
    final json = _txObject(value, 'wallet account');
    final account = WalletAccount(
      balance: _txInteger(json, 'balance'),
      entries: List<WalletEntry>.unmodifiable(
        _txList(json, 'entries').map(WalletEntry.fromJson),
      ),
    );
    if (!account.reconciles) {
      throw const FormatException('Wallet ledger does not reconcile.');
    }
    return account;
  }
  final int balance;
  final List<WalletEntry> entries;
  bool get reconciles {
    var expected = 0;
    for (final entry in entries) {
      expected += entry.deltaPoints;
      if (expected != entry.balanceAfter || expected < 0) return false;
    }
    return expected == balance;
  }
}

final class PlaceOrderResult {
  const PlaceOrderResult({
    required this.quote,
    required this.payment,
    required this.order,
  });
  factory PlaceOrderResult.fromJson(Object? value) {
    final json = _txObject(value, 'place order result');
    return PlaceOrderResult(
      quote: CheckoutQuote.fromJson(json['quote']),
      payment: CustomerPayment.fromJson(json['payment']),
      order: CustomerOrder.fromJson(json['order']),
    );
  }
  final CheckoutQuote quote;
  final CustomerPayment payment;
  final CustomerOrder order;
}

abstract interface class TransactionRemote {
  Future<List<CustomerAddress>> addresses();
  Future<List<CustomerDeliverySlot>> deliverySlots();
  Future<CheckoutQuote> quote({
    required int cartRevision,
    required String addressId,
    required String deliverySlotId,
    required String promotionCode,
    required int walletPoints,
    String? idempotencyKey,
  });
  Future<PlaceOrderResult> place({
    required String quoteId,
    required CustomerPaymentMethod method,
    String? idempotencyKey,
  });
  Future<CustomerPayment> payment(String id);
  Future<List<CustomerOrder>> orders();
  Future<CustomerOrder> order(String id);
  Future<CustomerOrder> cancel({
    required CustomerOrder order,
    required String reason,
  });
  Future<CustomerOrder> confirmDelivery(CustomerOrder order);
  Future<CustomerOrder> requestReturn({
    required CustomerOrder order,
    required List<Map<String, Object?>> lines,
    required String reason,
  });
  Future<CustomerOrder> rate({
    required CustomerOrder order,
    required int score,
    required String comment,
  });
  Future<WalletAccount> wallet();
}

final class TransactionApi implements TransactionRemote {
  const TransactionApi(this._client);
  final ApiClient _client;
  @override
  Future<List<CustomerAddress>> addresses() => _list(
    '/v1/addresses',
    'transaction.list_addresses',
    CustomerAddress.fromJson,
  );
  @override
  Future<List<CustomerDeliverySlot>> deliverySlots() => _list(
    '/v1/delivery-slots',
    'transaction.list_delivery_slots',
    CustomerDeliverySlot.fromJson,
  );
  Future<List<T>> _list<T>(
    String path,
    String operation,
    T Function(Object?) decode,
  ) async => (await _client.send(
    ApiRequest.get(operation: operation, path: path),
    (value) => List<T>.unmodifiable(
      _txList(_txObject(value, 'list'), 'items').map(decode),
    ),
  )).value;
  @override
  Future<CheckoutQuote> quote({
    required int cartRevision,
    required String addressId,
    required String deliverySlotId,
    required String promotionCode,
    required int walletPoints,
    String? idempotencyKey,
  }) async => (await _client.send(
    ApiRequest.command(
      operation: 'transaction.create_quote',
      method: 'POST',
      path: '/v1/checkout/quotes',
      body: {
        'cart_revision': cartRevision,
        'address_id': addressId,
        'delivery_slot_id': deliverySlotId,
        if (promotionCode.isNotEmpty) 'promotion_code': promotionCode,
        'wallet_points': walletPoints,
      },
      idempotencyKey: idempotencyKey,
    ),
    CheckoutQuote.fromJson,
  )).value;
  @override
  Future<PlaceOrderResult> place({
    required String quoteId,
    required CustomerPaymentMethod method,
    String? idempotencyKey,
  }) async => (await _client.send(
    ApiRequest.command(
      operation: 'transaction.place_order',
      method: 'POST',
      path: '/v1/checkout/orders',
      body: {'quote_id': quoteId, 'payment_method': method.wireValue},
      idempotencyKey: idempotencyKey,
    ),
    PlaceOrderResult.fromJson,
  )).value;
  @override
  Future<CustomerPayment> payment(String id) async => (await _client.send(
    ApiRequest.get(
      operation: 'transaction.get_payment',
      path: '/v1/payments/${Uri.encodeComponent(id)}',
    ),
    CustomerPayment.fromJson,
  )).value;
  @override
  Future<List<CustomerOrder>> orders() =>
      _list('/v1/orders', 'transaction.list_orders', CustomerOrder.fromJson);
  @override
  Future<CustomerOrder> order(String id) async => (await _client.send(
    ApiRequest.get(
      operation: 'transaction.get_order',
      path: '/v1/orders/${Uri.encodeComponent(id)}',
    ),
    CustomerOrder.fromJson,
  )).value;
  Future<CustomerOrder> _orderCommand(
    CustomerOrder value,
    String suffix,
    Object? body,
  ) async => (await _client.send(
    ApiRequest.command(
      operation: 'transaction.$suffix',
      method: 'POST',
      path: '/v1/orders/${Uri.encodeComponent(value.id)}/$suffix',
      body: body,
      headers: {'If-Match': '"${value.revision}"'},
    ),
    CustomerOrder.fromJson,
  )).value;
  @override
  Future<CustomerOrder> cancel({
    required CustomerOrder order,
    required String reason,
  }) => _orderCommand(order, 'cancel', {'reason': reason});
  @override
  Future<CustomerOrder> confirmDelivery(CustomerOrder order) =>
      _orderCommand(order, 'confirm-delivery', <String, Object?>{});
  @override
  Future<CustomerOrder> requestReturn({
    required CustomerOrder order,
    required List<Map<String, Object?>> lines,
    required String reason,
  }) => _orderCommand(order, 'returns', {'lines': lines, 'reason': reason});
  @override
  Future<CustomerOrder> rate({
    required CustomerOrder order,
    required int score,
    required String comment,
  }) => _orderCommand(order, 'rating', {'score': score, 'comment': comment});
  @override
  Future<WalletAccount> wallet() async => (await _client.send(
    ApiRequest.get(operation: 'transaction.get_wallet', path: '/v1/wallet'),
    WalletAccount.fromJson,
  )).value;
}

abstract interface class PaymentRecoveryStore {
  Future<String?> read();
  Future<void> save(String paymentId);
  Future<void> clear();
}

final class MemoryPaymentRecoveryStore implements PaymentRecoveryStore {
  String? _value;
  @override
  Future<void> clear() async => _value = null;
  @override
  Future<String?> read() async => _value;
  @override
  Future<void> save(String paymentId) async => _value = paymentId;
}

enum TransactionStatus {
  idle,
  loading,
  ready,
  quoting,
  placing,
  paymentPending,
  success,
  conflict,
  failure,
}

final class TransactionState {
  const TransactionState({
    required this.status,
    this.addresses = const [],
    this.slots = const [],
    this.quote,
    this.payment,
    this.order,
    this.orders = const [],
    this.wallet,
    this.message,
  });
  final TransactionStatus status;
  final List<CustomerAddress> addresses;
  final List<CustomerDeliverySlot> slots;
  final CheckoutQuote? quote;
  final CustomerPayment? payment;
  final CustomerOrder? order;
  final List<CustomerOrder> orders;
  final WalletAccount? wallet;
  final String? message;
}

final class TransactionController extends ChangeNotifier {
  TransactionController({
    required TransactionRemote remote,
    PaymentRecoveryStore? recoveryStore,
  }) : _remote = remote,
       _recovery = recoveryStore ?? MemoryPaymentRecoveryStore();
  final TransactionRemote _remote;
  final PaymentRecoveryStore _recovery;
  TransactionState _state = const TransactionState(
    status: TransactionStatus.idle,
  );
  TransactionState get state => _state;
  Future<void> loadCheckout() async {
    _set(
      TransactionState(status: TransactionStatus.loading, quote: _state.quote),
    );
    try {
      final values = await Future.wait<Object>([
        _remote.addresses(),
        _remote.deliverySlots(),
        _remote.wallet(),
      ]);
      _set(
        TransactionState(
          status: TransactionStatus.ready,
          addresses: values[0] as List<CustomerAddress>,
          slots: values[1] as List<CustomerDeliverySlot>,
          wallet: values[2] as WalletAccount,
        ),
      );
    } catch (_) {
      _set(
        const TransactionState(
          status: TransactionStatus.failure,
          message: 'Couldn’t load checkout. Try again.',
        ),
      );
    }
  }

  Future<bool> createQuote({
    required int cartRevision,
    required String addressId,
    required String slotId,
    String promotionCode = '',
    int walletPoints = 0,
  }) async {
    _set(
      TransactionState(
        status: TransactionStatus.quoting,
        addresses: _state.addresses,
        slots: _state.slots,
        wallet: _state.wallet,
        quote: _state.quote,
      ),
    );
    try {
      final value = await _remote.quote(
        cartRevision: cartRevision,
        addressId: addressId,
        deliverySlotId: slotId,
        promotionCode: promotionCode.trim().toUpperCase(),
        walletPoints: walletPoints,
      );
      _set(
        TransactionState(
          status: TransactionStatus.ready,
          addresses: _state.addresses,
          slots: _state.slots,
          wallet: _state.wallet,
          quote: value,
          message: value.warnings.contains('CART_REPRICED')
              ? 'Prices changed. Review the latest total.'
              : null,
        ),
      );
      return true;
    } on ApiConflictFailure {
      _set(
        TransactionState(
          status: TransactionStatus.conflict,
          addresses: _state.addresses,
          slots: _state.slots,
          wallet: _state.wallet,
          message: 'Checkout changed. Refresh the cart and review again.',
        ),
      );
      return false;
    } catch (_) {
      _set(
        TransactionState(
          status: TransactionStatus.failure,
          addresses: _state.addresses,
          slots: _state.slots,
          wallet: _state.wallet,
          message: 'Couldn’t calculate checkout.',
        ),
      );
      return false;
    }
  }

  Future<PlaceOrderResult?> place(CustomerPaymentMethod method) async {
    final quote = _state.quote;
    if (quote == null || !quote.paymentMethods.contains(method)) return null;
    _set(
      TransactionState(
        status: TransactionStatus.placing,
        addresses: _state.addresses,
        slots: _state.slots,
        quote: quote,
        wallet: _state.wallet,
      ),
    );
    try {
      final value = await _remote.place(quoteId: quote.id, method: method);
      if (value.payment.pending) {
        await _recovery.save(value.payment.id);
      } else {
        await _recovery.clear();
      }
      _set(
        TransactionState(
          status: value.payment.pending
              ? TransactionStatus.paymentPending
              : TransactionStatus.success,
          quote: quote,
          payment: value.payment,
          order: value.order,
          wallet: _state.wallet,
        ),
      );
      return value;
    } catch (_) {
      _set(
        TransactionState(
          status: TransactionStatus.failure,
          quote: quote,
          wallet: _state.wallet,
          message: 'Order wasn’t placed. No duplicate charge was created.',
        ),
      );
      return null;
    }
  }

  Future<void> recoverPayment() async {
    final id = await _recovery.read();
    if (id == null) return;
    try {
      final value = await _remote.payment(id);
      if (!value.pending) await _recovery.clear();
      _set(
        TransactionState(
          status: value.pending
              ? TransactionStatus.paymentPending
              : TransactionStatus.success,
          payment: value,
          quote: _state.quote,
          wallet: _state.wallet,
        ),
      );
    } catch (_) {
      _set(
        TransactionState(
          status: TransactionStatus.failure,
          message: 'Payment status is temporarily unavailable.',
        ),
      );
    }
  }

  Future<void> loadActivity() async {
    _set(
      TransactionState(
        status: TransactionStatus.loading,
        orders: _state.orders,
        wallet: _state.wallet,
      ),
    );
    try {
      final values = await Future.wait<Object>([
        _remote.orders(),
        _remote.wallet(),
      ]);
      _set(
        TransactionState(
          status: TransactionStatus.ready,
          orders: values[0] as List<CustomerOrder>,
          wallet: values[1] as WalletAccount,
        ),
      );
    } catch (_) {
      _set(
        TransactionState(
          status: TransactionStatus.failure,
          orders: _state.orders,
          wallet: _state.wallet,
          message: 'Couldn’t refresh activity.',
        ),
      );
    }
  }

  Future<CustomerOrder?> cancel(CustomerOrder order, String reason) =>
      _mutateOrder(() => _remote.cancel(order: order, reason: reason));
  Future<CustomerOrder?> confirmDelivery(CustomerOrder order) =>
      _mutateOrder(() => _remote.confirmDelivery(order));
  Future<CustomerOrder?> requestReturn(
    CustomerOrder order,
    List<Map<String, Object?>> lines,
    String reason,
  ) => _mutateOrder(
    () => _remote.requestReturn(order: order, lines: lines, reason: reason),
  );
  Future<CustomerOrder?> rate(CustomerOrder order, int score, String comment) =>
      _mutateOrder(
        () => _remote.rate(order: order, score: score, comment: comment),
      );
  Future<CustomerOrder?> _mutateOrder(
    Future<CustomerOrder> Function() action,
  ) async {
    try {
      final value = await action();
      final values = [
        ..._state.orders.where((item) => item.id != value.id),
        value,
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _set(
        TransactionState(
          status: TransactionStatus.ready,
          orders: values,
          order: value,
          wallet: _state.wallet,
        ),
      );
      return value;
    } catch (_) {
      _set(
        TransactionState(
          status: TransactionStatus.failure,
          orders: _state.orders,
          wallet: _state.wallet,
          message: 'The order changed. Refresh and try again.',
        ),
      );
      return null;
    }
  }

  void _set(TransactionState value) {
    _state = value;
    notifyListeners();
  }
}

Map<String, Object?> _txObject(Object? value, String label) {
  if (value is! Map<String, Object?>) {
    throw FormatException('$label must be an object.');
  }
  return value;
}

List<Object?> _txList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List<Object?>) throw FormatException('$key must be a list.');
  return value;
}

String _txString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return value;
}

int _txInteger(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('$key must be an integer.');
  return value;
}

DateTime _txInstant(Map<String, Object?> json, String key) {
  final value = DateTime.tryParse(_txString(json, key));
  if (value == null || !value.isUtc) throw FormatException('$key must be UTC.');
  return value;
}
