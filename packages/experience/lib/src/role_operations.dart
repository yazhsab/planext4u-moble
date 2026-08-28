import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';

import 'catalog.dart';

enum OperationsStatus { idle, loading, ready, submitting, offline, failure }

final class VendorApplication {
  const VendorApplication({
    required this.id,
    required this.revision,
    required this.status,
    required this.businessName,
    required this.documents,
    required this.zoneCount,
    required this.bankStatus,
    required this.verified,
    required this.allowedActions,
  });

  factory VendorApplication.fromJson(Object? value) {
    final json = _roleObject(value, 'vendor application');
    final bank = json['bank_account'];
    return VendorApplication(
      id: _roleString(json, 'id'),
      revision: _roleInteger(json, 'revision'),
      status: _roleString(json, 'status'),
      businessName: _roleString(json, 'business_name'),
      documents: List.unmodifiable(_roleList(json, 'documents')),
      zoneCount: _roleList(json, 'service_zones').length,
      bankStatus: bank is Map<String, Object?>
          ? bank['status'] as String? ?? 'NOT_CONFIGURED'
          : 'NOT_CONFIGURED',
      verified: _roleBoolean(json, 'verified'),
      allowedActions: Set.unmodifiable(
        _roleList(json, 'allowed_actions').cast<String>(),
      ),
    );
  }

  final String id;
  final int revision;
  final String status;
  final String businessName;
  final List<Object?> documents;
  final int zoneCount;
  final String bankStatus;
  final bool verified;
  final Set<String> allowedActions;
}

final class VendorCatalogItem {
  const VendorCatalogItem({
    required this.id,
    required this.revision,
    required this.kind,
    required this.name,
    required this.sku,
    required this.price,
    required this.stock,
    required this.approvalStatus,
    required this.active,
    required this.schedules,
    required this.allowedActions,
  });

  factory VendorCatalogItem.fromJson(Object? value) {
    final json = _roleObject(value, 'vendor catalog item');
    return VendorCatalogItem(
      id: _roleString(json, 'id'),
      revision: _roleInteger(json, 'revision'),
      kind: _roleString(json, 'kind'),
      name: _roleString(json, 'name'),
      sku: _roleString(json, 'sku'),
      price: CatalogMoney.fromJson(json['price']),
      stock: _roleInteger(json, 'stock'),
      approvalStatus: _roleString(json, 'approval_status'),
      active: _roleBoolean(json, 'active'),
      schedules: List.unmodifiable(_roleList(json, 'schedules')),
      allowedActions: Set.unmodifiable(
        _roleList(json, 'allowed_actions').cast<String>(),
      ),
    );
  }

  final String id;
  final int revision;
  final String kind;
  final String name;
  final String sku;
  final CatalogMoney price;
  final int stock;
  final String approvalStatus;
  final bool active;
  final List<Object?> schedules;
  final Set<String> allowedActions;
}

final class VendorWorkItem {
  const VendorWorkItem({
    required this.id,
    required this.referenceType,
    required this.status,
    required this.total,
    required this.customerLabel,
    required this.allowedActions,
  });

  factory VendorWorkItem.fromJson(Object? value) {
    final json = _roleObject(value, 'vendor work item');
    return VendorWorkItem(
      id: _roleString(json, 'id'),
      referenceType: _roleString(json, 'reference_type'),
      status: _roleString(json, 'status'),
      total: CatalogMoney.fromJson(json['total']),
      customerLabel: _roleString(json, 'customer_label'),
      allowedActions: Set.unmodifiable(
        _roleList(json, 'allowed_actions').cast<String>(),
      ),
    );
  }

  final String id;
  final String referenceType;
  final String status;
  final CatalogMoney total;
  final String customerLabel;
  final Set<String> allowedActions;
}

final class SettlementEntry {
  const SettlementEntry({
    required this.id,
    required this.kind,
    required this.referenceId,
    required this.gross,
    required this.commission,
    required this.tax,
    required this.net,
    required this.calculationVersion,
    required this.availableAt,
  });

  factory SettlementEntry.fromJson(Object? value) {
    final json = _roleObject(value, 'settlement entry');
    return SettlementEntry(
      id: _roleString(json, 'id'),
      kind: _roleString(json, 'kind'),
      referenceId: _roleString(json, 'reference_id'),
      gross: CatalogMoney.fromJson(json['gross']),
      commission: CatalogMoney.fromJson(json['commission']),
      tax: CatalogMoney.fromJson(json['tax']),
      net: CatalogMoney.fromJson(json['net']),
      calculationVersion: _roleString(json, 'calculation_version'),
      availableAt: _roleInstant(json, 'available_at'),
    );
  }

  final String id;
  final String kind;
  final String referenceId;
  final CatalogMoney gross;
  final CatalogMoney commission;
  final CatalogMoney tax;
  final CatalogMoney net;
  final String calculationVersion;
  final DateTime availableAt;
}

final class PayoutRecord {
  const PayoutRecord({
    required this.id,
    required this.revision,
    required this.amount,
    required this.status,
    required this.entryIds,
    required this.attemptCount,
  });

  factory PayoutRecord.fromJson(Object? value) {
    final json = _roleObject(value, 'payout');
    return PayoutRecord(
      id: _roleString(json, 'id'),
      revision: _roleInteger(json, 'revision'),
      amount: CatalogMoney.fromJson(json['amount']),
      status: _roleString(json, 'status'),
      entryIds: List.unmodifiable(_roleList(json, 'entry_ids').cast<String>()),
      attemptCount: _roleInteger(json, 'attempt_count'),
    );
  }

  final String id;
  final int revision;
  final CatalogMoney amount;
  final String status;
  final List<String> entryIds;
  final int attemptCount;
}

abstract interface class VendorOperationsRemote {
  Future<VendorApplication> register({
    required String businessName,
    required String businessType,
    required String contactName,
  });
  Future<VendorApplication> application();
  Future<VendorApplication> submitDocuments(
    int revision,
    List<Map<String, Object?>> documents,
  );
  Future<VendorApplication> scheduleVisit(int revision, DateTime scheduledAt);
  Future<VendorApplication> setZones(
    int revision,
    List<Map<String, Object?>> zones,
  );
  Future<VendorApplication> setBank(int revision, Map<String, Object?> bank);
  Future<Map<String, Object?>> dashboard();
  Future<List<VendorCatalogItem>> catalog();
  Future<VendorCatalogItem> createCatalog(Map<String, Object?> value);
  Future<VendorCatalogItem> setInventory(VendorCatalogItem item, int stock);
  Future<VendorCatalogItem> setSchedule(
    VendorCatalogItem item,
    List<Map<String, Object?>> schedules,
  );
  Future<List<VendorWorkItem>> work();
  Future<VendorWorkItem> transitionWork(String id, String status);
  Future<void> createPromotion(Map<String, Object?> value);
  Future<List<SettlementEntry>> ledger();
  Future<List<PayoutRecord>> payouts();
  Future<PayoutRecord> requestPayout(List<String> entryIds);
}

final class VendorOperationsApi implements VendorOperationsRemote {
  const VendorOperationsApi(this._client);
  final ApiClient _client;

  @override
  Future<VendorApplication> register({
    required String businessName,
    required String businessType,
    required String contactName,
  }) => _command('supply.register_vendor', '/v1/vendor/applications', {
    'business_name': businessName,
    'business_type': businessType,
    'contact_name': contactName,
  }, VendorApplication.fromJson);

  @override
  Future<VendorApplication> application() => _get(
    'supply.get_application',
    '/v1/vendor/application',
    VendorApplication.fromJson,
  );

  @override
  Future<VendorApplication> submitDocuments(
    int revision,
    List<Map<String, Object?>> documents,
  ) => _revisionCommand(
    'supply.submit_documents',
    '/v1/vendor/application/documents',
    revision,
    {'documents': documents},
    VendorApplication.fromJson,
  );

  @override
  Future<VendorApplication> scheduleVisit(int revision, DateTime scheduledAt) =>
      _revisionCommand(
        'supply.schedule_visit',
        '/v1/vendor/application/field-visit',
        revision,
        {
          'scheduled_at': scheduledAt.toUtc().toIso8601String(),
          'latitude': 13.0827,
          'longitude': 80.2707,
          'allowed_radius_m': 200,
        },
        VendorApplication.fromJson,
      );

  @override
  Future<VendorApplication> setZones(
    int revision,
    List<Map<String, Object?>> zones,
  ) => _revisionCommand(
    'supply.set_zones',
    '/v1/vendor/application/zones',
    revision,
    {'zones': zones},
    VendorApplication.fromJson,
  );

  @override
  Future<VendorApplication> setBank(int revision, Map<String, Object?> bank) =>
      _revisionCommand(
        'supply.set_bank',
        '/v1/vendor/application/bank',
        revision,
        bank,
        VendorApplication.fromJson,
      );

  @override
  Future<Map<String, Object?>> dashboard() => _get(
    'supply.get_dashboard',
    '/v1/vendor/dashboard',
    (value) => _roleObject(value, 'vendor dashboard'),
  );

  @override
  Future<List<VendorCatalogItem>> catalog() => _get(
    'supply.list_catalog',
    '/v1/vendor/catalog',
    (value) =>
        _roleDecodeWrappedList(value, 'items', VendorCatalogItem.fromJson),
  );

  @override
  Future<VendorCatalogItem> createCatalog(Map<String, Object?> value) =>
      _command(
        'supply.create_catalog',
        '/v1/vendor/catalog',
        value,
        VendorCatalogItem.fromJson,
      );

  @override
  Future<VendorCatalogItem> setInventory(VendorCatalogItem item, int stock) =>
      _revisionCommand(
        'supply.set_inventory',
        '/v1/vendor/catalog/${Uri.encodeComponent(item.id)}/inventory',
        item.revision,
        {'stock': stock},
        VendorCatalogItem.fromJson,
      );

  @override
  Future<VendorCatalogItem> setSchedule(
    VendorCatalogItem item,
    List<Map<String, Object?>> schedules,
  ) => _revisionCommand(
    'supply.set_schedule',
    '/v1/vendor/catalog/${Uri.encodeComponent(item.id)}/schedule',
    item.revision,
    {'windows': schedules},
    VendorCatalogItem.fromJson,
  );

  @override
  Future<List<VendorWorkItem>> work() => _get(
    'supply.list_work',
    '/v1/vendor/work',
    (value) => _roleDecodeWrappedList(value, 'items', VendorWorkItem.fromJson),
  );

  @override
  Future<VendorWorkItem> transitionWork(String id, String status) => _command(
    'supply.transition_work',
    '/v1/vendor/work/${Uri.encodeComponent(id)}/transition',
    {'status': status},
    VendorWorkItem.fromJson,
  );

  @override
  Future<void> createPromotion(Map<String, Object?> value) async {
    await _command<Object?>(
      'supply.create_promotion',
      '/v1/vendor/promotions',
      value,
      (json) => json,
    );
  }

  @override
  Future<List<SettlementEntry>> ledger() => _get(
    'settlement.list_ledger',
    '/v1/settlements/ledger',
    (value) => _roleDecodeWrappedList(value, 'items', SettlementEntry.fromJson),
  );

  @override
  Future<List<PayoutRecord>> payouts() => _get(
    'settlement.list_payouts',
    '/v1/payouts',
    (value) => _roleDecodeWrappedList(value, 'items', PayoutRecord.fromJson),
  );

  @override
  Future<PayoutRecord> requestPayout(List<String> entryIds) => _command(
    'settlement.request_payout',
    '/v1/payouts',
    {'entry_ids': entryIds},
    PayoutRecord.fromJson,
  );

  Future<T> _get<T>(
    String operation,
    String path,
    T Function(Object?) decode,
  ) async => (await _client.send(
    ApiRequest.get(operation: operation, path: path),
    decode,
  )).value;

  Future<T> _command<T>(
    String operation,
    String path,
    Object? body,
    T Function(Object?) decode,
  ) async => (await _client.send(
    ApiRequest.command(
      operation: operation,
      method: 'POST',
      path: path,
      body: body,
    ),
    decode,
  )).value;

  Future<T> _revisionCommand<T>(
    String operation,
    String path,
    int revision,
    Object? body,
    T Function(Object?) decode,
  ) async => (await _client.send(
    ApiRequest.command(
      operation: operation,
      method: 'POST',
      path: path,
      headers: {'If-Match': '"$revision"'},
      body: body,
    ),
    decode,
  )).value;
}

final class VendorOperationsState {
  const VendorOperationsState({
    this.status = OperationsStatus.idle,
    this.application,
    this.dashboard = const {},
    this.catalog = const [],
    this.work = const [],
    this.ledger = const [],
    this.payouts = const [],
    this.message,
  });
  final OperationsStatus status;
  final VendorApplication? application;
  final Map<String, Object?> dashboard;
  final List<VendorCatalogItem> catalog;
  final List<VendorWorkItem> work;
  final List<SettlementEntry> ledger;
  final List<PayoutRecord> payouts;
  final String? message;

  VendorOperationsState copyWith({
    OperationsStatus? status,
    VendorApplication? application,
    Map<String, Object?>? dashboard,
    List<VendorCatalogItem>? catalog,
    List<VendorWorkItem>? work,
    List<SettlementEntry>? ledger,
    List<PayoutRecord>? payouts,
    String? message,
    bool clearMessage = false,
  }) => VendorOperationsState(
    status: status ?? this.status,
    application: application ?? this.application,
    dashboard: dashboard ?? this.dashboard,
    catalog: catalog ?? this.catalog,
    work: work ?? this.work,
    ledger: ledger ?? this.ledger,
    payouts: payouts ?? this.payouts,
    message: clearMessage ? null : message ?? this.message,
  );
}

final class VendorOperationsController extends ChangeNotifier {
  VendorOperationsController(this._remote);
  final VendorOperationsRemote _remote;
  VendorOperationsState _state = const VendorOperationsState();
  VendorOperationsState get state => _state;

  Future<void> loadAll() => _run(() async {
    VendorApplication? application;
    try {
      application = await _remote.application();
    } catch (error) {
      if (error is! StateError &&
          (error is! ApiFailure || error.statusCode != 404)) {
        rethrow;
      }
      // A first-time vendor has no application yet.
    }
    final dashboard = application == null
        ? const <String, Object?>{}
        : await _remote.dashboard();
    final catalog = application?.verified == true
        ? await _remote.catalog()
        : const <VendorCatalogItem>[];
    final work = application?.verified == true
        ? await _remote.work()
        : const <VendorWorkItem>[];
    _state = _state.copyWith(
      application: application,
      dashboard: dashboard,
      catalog: catalog,
      work: work,
    );
  });

  Future<void> register({
    required String businessName,
    required String businessType,
    required String contactName,
  }) => _run(() async {
    final value = await _remote.register(
      businessName: businessName,
      businessType: businessType,
      contactName: contactName,
    );
    _state = _state.copyWith(application: value);
  });

  Future<void> submitDocuments() => _applicationCommand(
    (application) => _remote.submitDocuments(application.revision, const [
      {
        'kind': 'BUSINESS_REGISTRATION',
        'asset_id': 'asset-private-business-registration',
      },
      {'kind': 'OWNER_IDENTITY', 'asset_id': 'asset-private-owner-identity'},
    ]),
  );

  Future<void> scheduleFieldVisit() => _applicationCommand(
    (application) => _remote.scheduleVisit(
      application.revision,
      DateTime.now().toUtc().add(const Duration(days: 1)),
    ),
  );

  Future<void> configureZone() => _applicationCommand(
    (application) => _remote.setZones(application.revision, const [
      {
        'id': 'zone-chennai-core',
        'postal_codes': ['600001'],
        'latitude': 13.0827,
        'longitude': 80.2707,
        'radius_km': 25,
        'policy_version': 'zone-policy-v1',
      },
    ]),
  );

  Future<void> configureBank() => _applicationCommand(
    (application) => _remote.setBank(application.revision, const {
      'reference': 'bank-reference-tokenized',
      'holder_name': 'Planext4u Vendor',
      'last4': '1234',
      'ifsc': 'HDFC0001234',
    }),
  );

  Future<void> _applicationCommand(
    Future<VendorApplication> Function(VendorApplication application) action,
  ) => _run(() async {
    final current = _state.application;
    if (current == null) throw StateError('Vendor application is required.');
    _state = _state.copyWith(application: await action(current));
  });

  Future<void> createCatalog({
    required String kind,
    required String name,
    required int amountMinor,
  }) => _run(() async {
    final value = await _remote.createCatalog({
      'kind': kind,
      'name': name,
      'description': '$name published from the vendor mobile app',
      'sku': '${kind.substring(0, 1)}-${DateTime.now().millisecondsSinceEpoch}',
      'price': {'amount_minor': amountMinor, 'currency': 'INR'},
    });
    _state = _state.copyWith(catalog: [value, ..._state.catalog]);
  });

  Future<void> setInventory(VendorCatalogItem item, int stock) =>
      _run(() async {
        final updated = await _remote.setInventory(item, stock);
        _replaceCatalog(updated);
      });

  Future<void> setSchedule(VendorCatalogItem item) => _run(() async {
    final updated = await _remote.setSchedule(item, const [
      {
        'weekday': 1,
        'starts_minute': 540,
        'ends_minute': 1020,
        'time_zone': 'Asia/Kolkata',
        'capacity': 4,
        'buffer_minutes': 30,
      },
    ]);
    _replaceCatalog(updated);
  });

  Future<void> transitionWork(VendorWorkItem item, String status) =>
      _run(() async {
        final updated = await _remote.transitionWork(item.id, status);
        _state = _state.copyWith(
          work: [
            for (final value in _state.work)
              if (value.id == updated.id) updated else value,
          ],
        );
      });

  Future<void> createPromotion() => _run(() async {
    final now = DateTime.now().toUtc();
    await _remote.createPromotion({
      'title': 'Local launch offer',
      'kind': 'DISCOUNT',
      'budget': {'amount_minor': 100000, 'currency': 'INR'},
      'starts_at': now.toIso8601String(),
      'ends_at': now.add(const Duration(days: 7)).toIso8601String(),
    });
    _state = _state.copyWith(message: 'Promotion submitted for review.');
  });

  Future<void> loadSettlements() => _run(() async {
    final results = await Future.wait([_remote.ledger(), _remote.payouts()]);
    _state = _state.copyWith(
      ledger: results[0] as List<SettlementEntry>,
      payouts: results[1] as List<PayoutRecord>,
    );
  });

  Future<void> requestPayout() => _run(() async {
    final now = DateTime.now().toUtc();
    final ids = _state.ledger
        .where((entry) => !entry.availableAt.isAfter(now))
        .map((entry) => entry.id)
        .toList();
    if (ids.isEmpty) throw StateError('No cooled settlement entries.');
    final payout = await _remote.requestPayout(ids);
    _state = _state.copyWith(payouts: [payout, ..._state.payouts]);
  });

  void _replaceCatalog(VendorCatalogItem updated) {
    _state = _state.copyWith(
      catalog: [
        for (final value in _state.catalog)
          if (value.id == updated.id) updated else value,
      ],
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    _state = _state.copyWith(
      status: OperationsStatus.loading,
      clearMessage: true,
    );
    notifyListeners();
    try {
      await action();
      _state = _state.copyWith(status: OperationsStatus.ready);
    } on ApiTransportFailure {
      _state = _state.copyWith(
        status: OperationsStatus.offline,
        message: 'Offline. The last safe snapshot remains available.',
      );
    } on ApiConflictFailure {
      _state = _state.copyWith(
        status: OperationsStatus.failure,
        message: 'This record changed elsewhere. Refresh before retrying.',
      );
    } catch (_) {
      _state = _state.copyWith(
        status: OperationsStatus.failure,
        message: 'The operation could not be completed.',
      );
    }
    notifyListeners();
  }
}

final class RiderProfile {
  const RiderProfile({
    required this.id,
    required this.revision,
    required this.status,
    required this.fullName,
    required this.vehicleNumber,
    required this.bankStatus,
    required this.zones,
    required this.maxConcurrent,
    required this.allowedActions,
  });
  factory RiderProfile.fromJson(Object? value) {
    final json = _roleObject(value, 'rider profile');
    return RiderProfile(
      id: _roleString(json, 'id'),
      revision: _roleInteger(json, 'revision'),
      status: _roleString(json, 'status'),
      fullName: _roleString(json, 'full_name'),
      vehicleNumber: _roleString(json, 'vehicle_number'),
      bankStatus: json['bank_status'] as String? ?? 'NOT_CONFIGURED',
      zones: List.unmodifiable(_roleList(json, 'zones').cast<String>()),
      maxConcurrent: _roleInteger(json, 'max_concurrent'),
      allowedActions: Set.unmodifiable(
        _roleList(json, 'allowed_actions').cast<String>(),
      ),
    );
  }
  final String id;
  final int revision;
  final String status;
  final String fullName;
  final String vehicleNumber;
  final String bankStatus;
  final List<String> zones;
  final int maxConcurrent;
  final Set<String> allowedActions;
}

final class RiderDuty {
  const RiderDuty({
    required this.id,
    required this.revision,
    required this.status,
    required this.zoneId,
    required this.activeTasks,
    required this.lastSeenAt,
  });
  factory RiderDuty.fromJson(Object? value) {
    final json = _roleObject(value, 'rider duty');
    return RiderDuty(
      id: _roleString(json, 'id'),
      revision: _roleInteger(json, 'revision'),
      status: _roleString(json, 'status'),
      zoneId: _roleString(json, 'zone_id'),
      activeTasks: _roleInteger(json, 'active_tasks'),
      lastSeenAt: _roleInstant(json, 'last_seen_at'),
    );
  }
  final String id;
  final int revision;
  final String status;
  final String zoneId;
  final int activeTasks;
  final DateTime lastSeenAt;
}

final class RiderTask {
  const RiderTask({
    required this.id,
    required this.revision,
    required this.orderId,
    required this.orderType,
    required this.status,
    required this.pickupLabel,
    required this.dropoffLabel,
    required this.distanceMeters,
    required this.earning,
    required this.offerExpiresAt,
    required this.allowedActions,
    required this.podAssetId,
  });
  factory RiderTask.fromJson(Object? value) {
    final json = _roleObject(value, 'rider task');
    final pickup = _roleObject(json['pickup'], 'pickup');
    final dropoff = _roleObject(json['dropoff'], 'dropoff');
    return RiderTask(
      id: _roleString(json, 'id'),
      revision: _roleInteger(json, 'revision'),
      orderId: _roleString(json, 'order_id'),
      orderType: _roleString(json, 'order_type'),
      status: _roleString(json, 'status'),
      pickupLabel: _roleString(pickup, 'label'),
      dropoffLabel: _roleString(dropoff, 'label'),
      distanceMeters: _roleInteger(json, 'distance_meters'),
      earning: CatalogMoney.fromJson(json['earning']),
      offerExpiresAt: json['offer_expires_at'] is String
          ? DateTime.parse(json['offer_expires_at']! as String).toUtc()
          : null,
      allowedActions: Set.unmodifiable(
        _roleList(json, 'allowed_actions').cast<String>(),
      ),
      podAssetId: json['pod_blurred_asset_id'] as String? ?? '',
    );
  }
  final String id;
  final int revision;
  final String orderId;
  final String orderType;
  final String status;
  final String pickupLabel;
  final String dropoffLabel;
  final int distanceMeters;
  final CatalogMoney earning;
  final DateTime? offerExpiresAt;
  final Set<String> allowedActions;
  final String podAssetId;

  Duration offerRemaining(DateTime now) {
    final expiry = offerExpiresAt;
    if (expiry == null) return Duration.zero;
    final value = expiry.difference(now.toUtc());
    return value.isNegative ? Duration.zero : value;
  }
}

final class ChatMessageRecord {
  const ChatMessageRecord({
    required this.id,
    required this.senderId,
    required this.body,
    required this.redacted,
    required this.createdAt,
  });
  factory ChatMessageRecord.fromJson(Object? value) {
    final json = _roleObject(value, 'chat message');
    return ChatMessageRecord(
      id: _roleString(json, 'id'),
      senderId: _roleString(json, 'sender_id'),
      body: _roleString(json, 'body'),
      redacted: _roleBoolean(json, 'redacted'),
      createdAt: _roleInstant(json, 'created_at'),
    );
  }
  final String id;
  final String senderId;
  final String body;
  final bool redacted;
  final DateTime createdAt;
}

final class OrderConversation {
  const OrderConversation({
    required this.id,
    required this.orderId,
    required this.expiresAt,
    required this.blocked,
    required this.messages,
  });
  factory OrderConversation.fromJson(Object? value) {
    final json = _roleObject(value, 'order chat');
    return OrderConversation(
      id: _roleString(json, 'id'),
      orderId: _roleString(json, 'order_id'),
      expiresAt: _roleInstant(json, 'expires_at'),
      blocked: _roleBoolean(json, 'blocked'),
      messages: _roleList(
        json,
        'messages',
      ).map(ChatMessageRecord.fromJson).toList(),
    );
  }
  final String id;
  final String orderId;
  final DateTime expiresAt;
  final bool blocked;
  final List<ChatMessageRecord> messages;
  bool availableAt(DateTime now) => !blocked && expiresAt.isAfter(now.toUtc());
}

final class RiderLocationCommand {
  const RiderLocationCommand({
    required this.sequence,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAt,
  });
  final int sequence;
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime capturedAt;
  Map<String, Object?> toJson() => {
    'sequence': sequence,
    'point': {'latitude': latitude, 'longitude': longitude},
    'accuracy_m': accuracyMeters,
    'captured_at': capturedAt.toUtc().toIso8601String(),
  };
}

final class RiderOfflineCommand {
  const RiderOfflineCommand({
    required this.deviceSequence,
    required this.commandId,
    required this.kind,
    required this.taskId,
    required this.revision,
    this.payload = const {},
  });
  final int deviceSequence;
  final String commandId;
  final String kind;
  final String taskId;
  final int revision;
  final Map<String, Object?> payload;
  Map<String, Object?> toJson() => {
    'device_sequence': deviceSequence,
    'command_id': commandId,
    'kind': kind,
    'task_id': taskId,
    'revision': revision,
    if (payload.isNotEmpty) 'payload': payload,
  };
}

abstract interface class RiderCommandStore {
  Future<void> enqueue(RiderOfflineCommand command);
  Future<List<RiderOfflineCommand>> pending();
  Future<void> replace(List<RiderOfflineCommand> commands);
}

final class RiderTrackedPosition {
  const RiderTrackedPosition({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAt,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime capturedAt;
}

/// Platform location streams live in the rider application. Keeping the
/// boundary here lets the controller tie tracking strictly to an active duty
/// session without making unit tests depend on device plugins.
abstract interface class RiderLocationTracker {
  Future<void> start(
    Future<void> Function(RiderTrackedPosition position) onPosition,
  );
  Future<void> stop();
}

final class MemoryRiderCommandStore implements RiderCommandStore {
  final List<RiderOfflineCommand> _commands = [];
  @override
  Future<void> enqueue(RiderOfflineCommand command) async {
    if (_commands.every((value) => value.commandId != command.commandId)) {
      _commands.add(command);
      _commands.sort((a, b) => a.deviceSequence.compareTo(b.deviceSequence));
    }
  }

  @override
  Future<List<RiderOfflineCommand>> pending() async =>
      List.unmodifiable(_commands);

  @override
  Future<void> replace(List<RiderOfflineCommand> commands) async {
    _commands
      ..clear()
      ..addAll(commands);
  }
}

abstract interface class RiderOperationsRemote {
  Future<RiderProfile> register(Map<String, Object?> value);
  Future<RiderProfile> profile();
  Future<RiderDuty> startDuty(String zoneId);
  Future<RiderDuty> duty();
  Future<RiderDuty> endDuty(int revision);
  Future<List<RiderTask>> offers();
  Future<List<RiderTask>> tasks();
  Future<RiderTask> accept(RiderTask task);
  Future<RiderTask> pickup(RiderTask task);
  Future<RiderTask> complete(
    RiderTask task, {
    required String otp,
    required String blurredPhotoAssetId,
    String signatureAssetId,
  });
  Future<void> updateLocation(RiderLocationCommand command);
  Future<List<Map<String, Object?>>> recover(
    List<RiderOfflineCommand> commands,
  );
  Future<OrderConversation> conversation(String orderId);
  Future<ChatMessageRecord> sendMessage(String conversationId, String body);
  Future<List<SettlementEntry>> ledger();
  Future<List<PayoutRecord>> payouts();
  Future<PayoutRecord> requestPayout(List<String> entryIds);
}

final class RiderOperationsApi implements RiderOperationsRemote {
  const RiderOperationsApi(this._client);
  final ApiClient _client;

  @override
  Future<RiderProfile> register(Map<String, Object?> value) => _command(
    'rider.register',
    '/v1/rider/applications',
    value,
    RiderProfile.fromJson,
  );
  @override
  Future<RiderProfile> profile() =>
      _get('rider.get_profile', '/v1/rider/profile', RiderProfile.fromJson);
  @override
  Future<RiderDuty> startDuty(String zoneId) => _command(
    'rider.start_duty',
    '/v1/rider/duty/start',
    {'zone_id': zoneId},
    RiderDuty.fromJson,
  );
  @override
  Future<RiderDuty> duty() =>
      _get('rider.get_duty', '/v1/rider/duty', RiderDuty.fromJson);
  @override
  Future<RiderDuty> endDuty(int revision) => _revisionCommand(
    'rider.end_duty',
    '/v1/rider/duty/end',
    revision,
    const {},
    RiderDuty.fromJson,
  );
  @override
  Future<List<RiderTask>> offers() => _get(
    'rider.list_offers',
    '/v1/rider/offers',
    (value) => _roleDecodeWrappedList(value, 'items', RiderTask.fromJson),
  );
  @override
  Future<List<RiderTask>> tasks() => _get(
    'rider.list_tasks',
    '/v1/rider/tasks',
    (value) => _roleDecodeWrappedList(value, 'items', RiderTask.fromJson),
  );
  @override
  Future<RiderTask> accept(RiderTask task) => _revisionCommand(
    'rider.accept_offer',
    '/v1/rider/tasks/${Uri.encodeComponent(task.id)}/accept',
    task.revision,
    const {},
    RiderTask.fromJson,
  );
  @override
  Future<RiderTask> pickup(RiderTask task) => _revisionCommand(
    'rider.pickup',
    '/v1/rider/tasks/${Uri.encodeComponent(task.id)}/pickup',
    task.revision,
    const {},
    RiderTask.fromJson,
  );
  @override
  Future<RiderTask> complete(
    RiderTask task, {
    required String otp,
    required String blurredPhotoAssetId,
    String signatureAssetId = '',
  }) => _revisionCommand(
    'rider.complete',
    '/v1/rider/tasks/${Uri.encodeComponent(task.id)}/completion',
    task.revision,
    {
      'otp': otp,
      'blurred_photo_asset_id': blurredPhotoAssetId,
      if (signatureAssetId.isNotEmpty) 'signature_asset_id': signatureAssetId,
    },
    RiderTask.fromJson,
  );
  @override
  Future<void> updateLocation(RiderLocationCommand command) async {
    await _command<Object?>(
      'rider.update_location',
      '/v1/rider/location',
      command.toJson(),
      (value) => value,
    );
  }

  @override
  Future<List<Map<String, Object?>>> recover(
    List<RiderOfflineCommand> commands,
  ) => _command(
    'rider.offline_recovery',
    '/v1/rider/offline-recovery',
    {'commands': commands.map((value) => value.toJson()).toList()},
    (value) => _roleDecodeWrappedList(
      value,
      'items',
      (item) => _roleObject(item, 'recovery result'),
    ),
  );
  @override
  Future<OrderConversation> conversation(String orderId) => _get(
    'chat.get_conversation',
    '/v1/order-chats/${Uri.encodeComponent(orderId)}',
    OrderConversation.fromJson,
  );
  @override
  Future<ChatMessageRecord> sendMessage(String conversationId, String body) =>
      _command(
        'chat.send_message',
        '/v1/order-chats/${Uri.encodeComponent(conversationId)}/messages',
        {'body': body},
        ChatMessageRecord.fromJson,
      );
  @override
  Future<List<SettlementEntry>> ledger() => _get(
    'settlement.list_ledger',
    '/v1/settlements/ledger',
    (value) => _roleDecodeWrappedList(value, 'items', SettlementEntry.fromJson),
  );
  @override
  Future<List<PayoutRecord>> payouts() => _get(
    'settlement.list_payouts',
    '/v1/payouts',
    (value) => _roleDecodeWrappedList(value, 'items', PayoutRecord.fromJson),
  );
  @override
  Future<PayoutRecord> requestPayout(List<String> entryIds) => _command(
    'settlement.request_payout',
    '/v1/payouts',
    {'entry_ids': entryIds},
    PayoutRecord.fromJson,
  );

  Future<T> _get<T>(
    String operation,
    String path,
    T Function(Object?) decode,
  ) async => (await _client.send(
    ApiRequest.get(operation: operation, path: path),
    decode,
  )).value;
  Future<T> _command<T>(
    String operation,
    String path,
    Object? body,
    T Function(Object?) decode,
  ) async => (await _client.send(
    ApiRequest.command(
      operation: operation,
      method: 'POST',
      path: path,
      body: body,
    ),
    decode,
  )).value;
  Future<T> _revisionCommand<T>(
    String operation,
    String path,
    int revision,
    Object? body,
    T Function(Object?) decode,
  ) async => (await _client.send(
    ApiRequest.command(
      operation: operation,
      method: 'POST',
      path: path,
      headers: {'If-Match': '"$revision"'},
      body: body,
    ),
    decode,
  )).value;
}

final class RiderOperationsState {
  const RiderOperationsState({
    this.status = OperationsStatus.idle,
    this.profile,
    this.duty,
    this.offers = const [],
    this.tasks = const [],
    this.ledger = const [],
    this.payouts = const [],
    this.conversation,
    this.pendingCommands = 0,
    this.message,
  });
  final OperationsStatus status;
  final RiderProfile? profile;
  final RiderDuty? duty;
  final List<RiderTask> offers;
  final List<RiderTask> tasks;
  final List<SettlementEntry> ledger;
  final List<PayoutRecord> payouts;
  final OrderConversation? conversation;
  final int pendingCommands;
  final String? message;

  RiderOperationsState copyWith({
    OperationsStatus? status,
    RiderProfile? profile,
    RiderDuty? duty,
    List<RiderTask>? offers,
    List<RiderTask>? tasks,
    List<SettlementEntry>? ledger,
    List<PayoutRecord>? payouts,
    OrderConversation? conversation,
    int? pendingCommands,
    String? message,
    bool clearMessage = false,
  }) => RiderOperationsState(
    status: status ?? this.status,
    profile: profile ?? this.profile,
    duty: duty ?? this.duty,
    offers: offers ?? this.offers,
    tasks: tasks ?? this.tasks,
    ledger: ledger ?? this.ledger,
    payouts: payouts ?? this.payouts,
    conversation: conversation ?? this.conversation,
    pendingCommands: pendingCommands ?? this.pendingCommands,
    message: clearMessage ? null : message ?? this.message,
  );
}

final class RiderOperationsController extends ChangeNotifier {
  RiderOperationsController(
    this._remote, {
    RiderCommandStore? commandStore,
    RiderLocationTracker? locationTracker,
  }) : _commandStore = commandStore ?? MemoryRiderCommandStore(),
       _locationTracker = locationTracker;
  final RiderOperationsRemote _remote;
  final RiderCommandStore _commandStore;
  final RiderLocationTracker? _locationTracker;
  RiderOperationsState _state = const RiderOperationsState();
  RiderOperationsState get state => _state;
  int _deviceSequence = 0;
  int _locationSequence = 0;

  Future<void> load() => _run(() async {
    RiderProfile? profile;
    RiderDuty? duty;
    try {
      profile = await _remote.profile();
    } catch (error) {
      if (error is! StateError &&
          (error is! ApiFailure || error.statusCode != 404)) {
        rethrow;
      }
      // Registration UI remains available for a first-time rider.
    }
    if (profile?.status == 'APPROVED') {
      try {
        duty = await _remote.duty();
      } catch (error) {
        if (error is! StateError &&
            (error is! ApiFailure || error.statusCode != 404)) {
          rethrow;
        }
        // No active duty is a valid state.
      }
    }
    _state = _state.copyWith(
      profile: profile,
      duty: duty,
      pendingCommands: (await _commandStore.pending()).length,
    );
    if (duty?.status == 'ONLINE') {
      await _locationTracker?.start(_publishTrackedPosition);
    }
  });

  Future<void> register() => _run(() async {
    final profile = await _remote.register(const {
      'full_name': 'Planext4u Rider',
      'phone_masked': '******1234',
      'vehicle_type': 'MOTORBIKE',
      'vehicle_number': 'TN01AB1234',
      'documents': [
        {
          'kind': 'DRIVER_LICENSE',
          'asset_id': 'asset-private-rider-license',
          'ocr_status': 'PENDING',
        },
        {
          'kind': 'IDENTITY',
          'asset_id': 'asset-private-rider-identity',
          'ocr_status': 'PENDING',
        },
      ],
      'bank_reference': 'bankref-rider-tokenized',
      'zones': ['600001'],
    });
    _state = _state.copyWith(profile: profile);
  });

  Future<void> startDuty({String zoneId = '600001'}) => _run(() async {
    await _locationTracker?.start(_publishTrackedPosition);
    try {
      _state = _state.copyWith(duty: await _remote.startDuty(zoneId));
    } catch (_) {
      await _locationTracker?.stop();
      rethrow;
    }
    await _refreshTasks();
  });

  Future<void> endDuty() => _run(() async {
    final duty = _state.duty;
    if (duty == null) return;
    _state = _state.copyWith(duty: await _remote.endDuty(duty.revision));
    await _locationTracker?.stop();
  });

  Future<void> refreshTasks() => _run(_refreshTasks);

  Future<void> _refreshTasks() async {
    final results = await Future.wait([_remote.offers(), _remote.tasks()]);
    _state = _state.copyWith(offers: results[0], tasks: results[1]);
  }

  Future<void> accept(RiderTask task) =>
      _taskCommand(task, 'ACCEPT', () => _remote.accept(task));
  Future<void> pickup(RiderTask task) =>
      _taskCommand(task, 'PICKUP', () => _remote.pickup(task));
  Future<void> complete(
    RiderTask task, {
    required String otp,
    String blurredPhotoAssetId = 'asset-blurred-pod-mobile',
    String signatureAssetId = '',
  }) => _taskCommand(
    task,
    'COMPLETE',
    () => _remote.complete(
      task,
      otp: otp,
      blurredPhotoAssetId: blurredPhotoAssetId,
      signatureAssetId: signatureAssetId,
    ),
    payload: {
      'otp': otp,
      'blurred_photo_asset_id': blurredPhotoAssetId,
      if (signatureAssetId.isNotEmpty) 'signature_asset_id': signatureAssetId,
    },
  );

  Future<void> _taskCommand(
    RiderTask task,
    String kind,
    Future<RiderTask> Function() operation, {
    Map<String, Object?> payload = const {},
  }) async {
    _state = _state.copyWith(
      status: OperationsStatus.submitting,
      clearMessage: true,
    );
    notifyListeners();
    try {
      final updated = await operation();
      _replaceTask(updated);
      _state = _state.copyWith(status: OperationsStatus.ready);
    } on ApiTransportFailure {
      final command = RiderOfflineCommand(
        deviceSequence: ++_deviceSequence,
        commandId: 'mobile-${DateTime.now().microsecondsSinceEpoch}',
        kind: kind,
        taskId: task.id,
        revision: task.revision,
        payload: payload,
      );
      await _commandStore.enqueue(command);
      _state = _state.copyWith(
        status: OperationsStatus.offline,
        pendingCommands: (await _commandStore.pending()).length,
        message: 'Saved offline. Commands will replay in order when connected.',
      );
    } catch (_) {
      _state = _state.copyWith(
        status: OperationsStatus.failure,
        message: 'Task changed or the action is no longer available.',
      );
    }
    notifyListeners();
  }

  Future<void> recoverOffline() => _run(() async {
    final commands = await _commandStore.pending();
    if (commands.isEmpty) return;
    final results = await _remote.recover(commands);
    final completedIds = results
        .where((value) => value['status'] == 'APPLIED')
        .map((value) => value['command_id'])
        .whereType<String>()
        .toSet();
    await _commandStore.replace(
      commands
          .where((value) => !completedIds.contains(value.commandId))
          .toList(),
    );
    _state = _state.copyWith(
      pendingCommands: (await _commandStore.pending()).length,
    );
    await _refreshTasks();
  });

  Future<void> updateLocation({
    required double latitude,
    required double longitude,
    required double accuracyMeters,
  }) => _run(
    () => _publishTrackedPosition(
      RiderTrackedPosition(
        latitude: latitude,
        longitude: longitude,
        accuracyMeters: accuracyMeters,
        capturedAt: DateTime.now().toUtc(),
      ),
    ),
  );

  Future<void> _publishTrackedPosition(RiderTrackedPosition position) async {
    if (_state.duty?.status != 'ONLINE') return;
    if (position.accuracyMeters <= 0 || position.accuracyMeters > 100) {
      throw const FormatException('Location accuracy is unsafe.');
    }
    await _remote.updateLocation(
      RiderLocationCommand(
        sequence: ++_locationSequence,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracyMeters,
        capturedAt: position.capturedAt.toUtc(),
      ),
    );
  }

  Future<void> openChat(String orderId) => _run(() async {
    _state = _state.copyWith(conversation: await _remote.conversation(orderId));
  });

  Future<void> sendMessage(String body) => _run(() async {
    final conversation = _state.conversation;
    if (conversation == null || !conversation.availableAt(DateTime.now())) {
      throw StateError('Chat window is unavailable.');
    }
    await _remote.sendMessage(conversation.id, body.trim());
    _state = _state.copyWith(
      conversation: await _remote.conversation(conversation.orderId),
    );
  });

  Future<void> loadSettlements() => _run(() async {
    final results = await Future.wait([_remote.ledger(), _remote.payouts()]);
    _state = _state.copyWith(
      ledger: results[0] as List<SettlementEntry>,
      payouts: results[1] as List<PayoutRecord>,
    );
  });

  Future<void> requestPayout() => _run(() async {
    final now = DateTime.now().toUtc();
    final ids = _state.ledger
        .where((entry) => !entry.availableAt.isAfter(now))
        .map((entry) => entry.id)
        .toList();
    if (ids.isEmpty) throw StateError('No earnings are ready for payout.');
    final payout = await _remote.requestPayout(ids);
    _state = _state.copyWith(payouts: [payout, ..._state.payouts]);
  });

  void _replaceTask(RiderTask updated) {
    _state = _state.copyWith(
      offers: _state.offers.where((item) => item.id != updated.id).toList(),
      tasks: [updated, ..._state.tasks.where((item) => item.id != updated.id)],
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    _state = _state.copyWith(
      status: OperationsStatus.loading,
      clearMessage: true,
    );
    notifyListeners();
    try {
      await action();
      _state = _state.copyWith(status: OperationsStatus.ready);
    } on ApiTransportFailure {
      _state = _state.copyWith(
        status: OperationsStatus.offline,
        message: 'Offline. Live data will resume when connected.',
      );
    } catch (_) {
      _state = _state.copyWith(
        status: OperationsStatus.failure,
        message: 'The operation could not be completed safely.',
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_locationTracker?.stop());
    super.dispose();
  }
}

Map<String, Object?> _roleObject(Object? value, String label) {
  if (value is! Map<String, Object?>) {
    throw FormatException('$label contract is invalid.');
  }
  return value;
}

String _roleString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key is invalid.');
  }
  return value;
}

int _roleInteger(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('$key is invalid.');
  return value;
}

bool _roleBoolean(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('$key is invalid.');
  return value;
}

List<Object?> _roleList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List<Object?>) throw FormatException('$key is invalid.');
  return value;
}

DateTime _roleInstant(Map<String, Object?> json, String key) {
  final value = DateTime.tryParse(_roleString(json, key));
  if (value == null) throw FormatException('$key is invalid.');
  return value.toUtc();
}

List<T> _roleDecodeWrappedList<T>(
  Object? value,
  String key,
  T Function(Object?) decode,
) {
  final json = _roleObject(value, 'list response');
  return _roleList(json, key).map(decode).toList(growable: false);
}
