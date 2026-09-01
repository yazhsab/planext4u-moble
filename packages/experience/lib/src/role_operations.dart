import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';

import 'catalog.dart';

enum OperationsStatus { idle, loading, ready, submitting, offline, failure }

final class VendorDocumentSummary {
  const VendorDocumentSummary({
    required this.kind,
    required this.ocrStatus,
    this.reviewReason,
  });

  factory VendorDocumentSummary.fromJson(Object? value) {
    final json = _roleObject(value, 'vendor document');
    return VendorDocumentSummary(
      kind: _roleString(json, 'kind'),
      ocrStatus: _roleString(json, 'ocr_status'),
      reviewReason: _optionalRoleString(json, 'review_reason'),
    );
  }

  final String kind;
  final String ocrStatus;
  final String? reviewReason;
}

final class VendorServiceZoneSummary {
  const VendorServiceZoneSummary({
    required this.id,
    required this.postalCodes,
    required this.radiusKm,
    required this.policyVersion,
  });

  factory VendorServiceZoneSummary.fromJson(Object? value) {
    final json = _roleObject(value, 'vendor service zone');
    final radius = json['radius_km'];
    if (radius is! num || !radius.toDouble().isFinite || radius <= 0) {
      throw const FormatException('radius_km is invalid.');
    }
    return VendorServiceZoneSummary(
      id: _roleString(json, 'id'),
      postalCodes: List.unmodifiable(
        _roleList(json, 'postal_codes').cast<String>(),
      ),
      radiusKm: radius.toDouble(),
      policyVersion: _roleString(json, 'policy_version'),
    );
  }

  final String id;
  final List<String> postalCodes;
  final double radiusKm;
  final String policyVersion;
}

final class VendorBankSummary {
  const VendorBankSummary({
    required this.holderName,
    required this.last4,
    required this.ifsc,
    required this.status,
  });

  factory VendorBankSummary.fromJson(Object? value) {
    final json = _roleObject(value, 'vendor bank account');
    return VendorBankSummary(
      holderName: _roleString(json, 'holder_name'),
      last4: _roleString(json, 'last4'),
      ifsc: _roleString(json, 'ifsc'),
      status: _roleString(json, 'status'),
    );
  }

  final String holderName;
  final String last4;
  final String ifsc;
  final String status;
}

final class VendorFieldVisitSummary {
  const VendorFieldVisitSummary({
    required this.id,
    required this.scheduledAt,
    this.checkedInAt,
  });

  factory VendorFieldVisitSummary.fromJson(Object? value) {
    final json = _roleObject(value, 'vendor field visit');
    return VendorFieldVisitSummary(
      id: _roleString(json, 'id'),
      scheduledAt: _roleInstant(json, 'scheduled_at'),
      checkedInAt: _optionalRoleInstant(json, 'checked_in_at'),
    );
  }

  final String id;
  final DateTime scheduledAt;
  final DateTime? checkedInAt;
}

final class VendorTimelineEvent {
  const VendorTimelineEvent({
    required this.status,
    required this.actor,
    required this.createdAt,
    this.reason,
  });

  factory VendorTimelineEvent.fromJson(Object? value) {
    final json = _roleObject(value, 'vendor timeline event');
    return VendorTimelineEvent(
      status: _roleString(json, 'status'),
      actor: _roleString(json, 'actor'),
      createdAt: _roleInstant(json, 'created_at'),
      reason: _optionalRoleString(json, 'reason'),
    );
  }

  final String status;
  final String actor;
  final DateTime createdAt;
  final String? reason;
}

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
    this.businessType = '',
    this.contactName = '',
    this.documentSummaries = const [],
    this.serviceZones = const [],
    this.bank,
    this.fieldVisit,
    this.timeline = const [],
    this.updatedAt,
  });

  factory VendorApplication.fromJson(Object? value) {
    final json = _roleObject(value, 'vendor application');
    final bank = json['bank_account'];
    final documents = _roleList(json, 'documents');
    final documentSummaries = documents
        .map(VendorDocumentSummary.fromJson)
        .toList(growable: false);
    final serviceZones = _roleList(json, 'service_zones');
    return VendorApplication(
      id: _roleString(json, 'id'),
      revision: _roleInteger(json, 'revision'),
      status: _roleString(json, 'status'),
      businessName: _roleString(json, 'business_name'),
      businessType: _roleString(json, 'business_type'),
      contactName: _roleString(json, 'contact_name'),
      documents: List.unmodifiable([
        for (final document in documentSummaries)
          <String, Object?>{
            'kind': document.kind,
            'ocr_status': document.ocrStatus,
            if (document.reviewReason != null)
              'review_reason': document.reviewReason,
          },
      ]),
      documentSummaries: List.unmodifiable(documentSummaries),
      zoneCount: serviceZones.length,
      serviceZones: List.unmodifiable(
        serviceZones.map(VendorServiceZoneSummary.fromJson),
      ),
      bankStatus: bank is Map<String, Object?>
          ? bank['status'] as String? ?? 'NOT_CONFIGURED'
          : 'NOT_CONFIGURED',
      bank: bank == null ? null : VendorBankSummary.fromJson(bank),
      fieldVisit: json['field_visit'] == null
          ? null
          : VendorFieldVisitSummary.fromJson(json['field_visit']),
      timeline: List.unmodifiable(
        _roleList(json, 'timeline').map(VendorTimelineEvent.fromJson),
      ),
      updatedAt: _roleInstant(json, 'updated_at'),
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
  final String businessType;
  final String contactName;
  final List<Object?> documents;
  final List<VendorDocumentSummary> documentSummaries;
  final int zoneCount;
  final List<VendorServiceZoneSummary> serviceZones;
  final String bankStatus;
  final VendorBankSummary? bank;
  final VendorFieldVisitSummary? fieldVisit;
  final List<VendorTimelineEvent> timeline;
  final DateTime? updatedAt;
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
    this.description = '',
    this.updatedAt,
  });

  factory VendorCatalogItem.fromJson(Object? value) {
    final json = _roleObject(value, 'vendor catalog item');
    return VendorCatalogItem(
      id: _roleString(json, 'id'),
      revision: _roleInteger(json, 'revision'),
      kind: _roleString(json, 'kind'),
      name: _roleString(json, 'name'),
      description: _roleString(json, 'description'),
      sku: _roleString(json, 'sku'),
      price: CatalogMoney.fromJson(json['price']),
      stock: _roleInteger(json, 'stock'),
      approvalStatus: _roleString(json, 'approval_status'),
      active: _roleBoolean(json, 'active'),
      schedules: List.unmodifiable(_roleList(json, 'schedules')),
      allowedActions: Set.unmodifiable(
        _roleList(json, 'allowed_actions').cast<String>(),
      ),
      updatedAt: _roleInstant(json, 'updated_at'),
    );
  }

  final String id;
  final int revision;
  final String kind;
  final String name;
  final String description;
  final String sku;
  final CatalogMoney price;
  final int stock;
  final String approvalStatus;
  final bool active;
  final List<Object?> schedules;
  final Set<String> allowedActions;
  final DateTime? updatedAt;
}

final class VendorWorkItem {
  const VendorWorkItem({
    required this.id,
    required this.referenceType,
    required this.status,
    required this.total,
    required this.customerLabel,
    required this.allowedActions,
    this.referenceId = '',
    this.updatedAt,
  });

  factory VendorWorkItem.fromJson(Object? value) {
    final json = _roleObject(value, 'vendor work item');
    return VendorWorkItem(
      id: _roleString(json, 'id'),
      referenceType: _roleString(json, 'reference_type'),
      referenceId: _roleString(json, 'reference_id'),
      status: _roleString(json, 'status'),
      total: CatalogMoney.fromJson(json['total']),
      customerLabel: _roleString(json, 'customer_label'),
      allowedActions: Set.unmodifiable(
        _roleList(json, 'allowed_actions').cast<String>(),
      ),
      updatedAt: _roleInstant(json, 'updated_at'),
    );
  }

  final String id;
  final String referenceType;
  final String referenceId;
  final String status;
  final CatalogMoney total;
  final String customerLabel;
  final Set<String> allowedActions;
  final DateTime? updatedAt;
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
  Future<VendorCatalogItem> updateCatalog(
    VendorCatalogItem item,
    Map<String, Object?> value,
  );
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
  Future<VendorCatalogItem> updateCatalog(
    VendorCatalogItem item,
    Map<String, Object?> value,
  ) => _revisionPutCommand(
    'supply.update_catalog',
    '/v1/vendor/catalog/${Uri.encodeComponent(item.id)}',
    item.revision,
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

  Future<T> _revisionPutCommand<T>(
    String operation,
    String path,
    int revision,
    Object? body,
    T Function(Object?) decode,
  ) async => (await _client.send(
    ApiRequest.command(
      operation: operation,
      method: 'PUT',
      path: path,
      headers: {'If-Match': '"$revision"'},
      body: body,
    ),
    decode,
  )).value;
}

enum VendorDraftSyncStatus {
  none,
  draft,
  syncing,
  synced,
  offline,
  conflict,
  failure,
}

final class VendorCatalogDraft {
  const VendorCatalogDraft({
    required this.kind,
    required this.name,
    required this.description,
    required this.sku,
    required this.amountMinor,
  });

  final String kind;
  final String name;
  final String description;
  final String sku;
  final int amountMinor;
}

final class VendorScheduleDraft {
  const VendorScheduleDraft({
    required this.itemId,
    required this.baseRevision,
    required this.schedules,
  });

  final String itemId;
  final int baseRevision;
  final List<Map<String, Object?>> schedules;
}

final class VendorPromotionDraft {
  const VendorPromotionDraft({
    required this.title,
    required this.budgetMinor,
    required this.durationDays,
  });

  final String title;
  final int budgetMinor;
  final int durationDays;
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
    this.catalogDraft,
    this.scheduleDraft,
    this.promotionDraft,
    this.catalogDraftStatus = VendorDraftSyncStatus.none,
    this.scheduleDraftStatus = VendorDraftSyncStatus.none,
    this.promotionDraftStatus = VendorDraftSyncStatus.none,
    this.message,
  });
  final OperationsStatus status;
  final VendorApplication? application;
  final Map<String, Object?> dashboard;
  final List<VendorCatalogItem> catalog;
  final List<VendorWorkItem> work;
  final List<SettlementEntry> ledger;
  final List<PayoutRecord> payouts;
  final VendorCatalogDraft? catalogDraft;
  final VendorScheduleDraft? scheduleDraft;
  final VendorPromotionDraft? promotionDraft;
  final VendorDraftSyncStatus catalogDraftStatus;
  final VendorDraftSyncStatus scheduleDraftStatus;
  final VendorDraftSyncStatus promotionDraftStatus;
  final String? message;

  VendorOperationsState copyWith({
    OperationsStatus? status,
    VendorApplication? application,
    Map<String, Object?>? dashboard,
    List<VendorCatalogItem>? catalog,
    List<VendorWorkItem>? work,
    List<SettlementEntry>? ledger,
    List<PayoutRecord>? payouts,
    VendorCatalogDraft? catalogDraft,
    VendorScheduleDraft? scheduleDraft,
    VendorPromotionDraft? promotionDraft,
    VendorDraftSyncStatus? catalogDraftStatus,
    VendorDraftSyncStatus? scheduleDraftStatus,
    VendorDraftSyncStatus? promotionDraftStatus,
    bool clearCatalogDraft = false,
    bool clearScheduleDraft = false,
    bool clearPromotionDraft = false,
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
    catalogDraft: clearCatalogDraft ? null : catalogDraft ?? this.catalogDraft,
    scheduleDraft: clearScheduleDraft
        ? null
        : scheduleDraft ?? this.scheduleDraft,
    promotionDraft: clearPromotionDraft
        ? null
        : promotionDraft ?? this.promotionDraft,
    catalogDraftStatus: catalogDraftStatus ?? this.catalogDraftStatus,
    scheduleDraftStatus: scheduleDraftStatus ?? this.scheduleDraftStatus,
    promotionDraftStatus: promotionDraftStatus ?? this.promotionDraftStatus,
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

  Future<void> submitDocuments(List<Map<String, Object?>> documents) {
    if (documents.isEmpty || documents.length > 10) {
      throw const FormatException('Vendor documents are invalid.');
    }
    final normalizedDocuments = <Map<String, Object?>>[];
    final kinds = <String>{};
    for (final document in documents) {
      final kind = document['kind'];
      final assetId = document['asset_id'];
      if (kind is! String ||
          !const {
            'BUSINESS_REGISTRATION',
            'OWNER_IDENTITY',
            'TAX_REGISTRATION',
            'ADDRESS_PROOF',
          }.contains(kind) ||
          assetId is! String ||
          !_validPrivateReference(assetId)) {
        throw const FormatException('Vendor document reference is invalid.');
      }
      if (!kinds.add(kind)) {
        throw const FormatException('Vendor document kinds must be unique.');
      }
      normalizedDocuments.add({'kind': kind, 'asset_id': assetId});
    }
    if (!kinds.containsAll(const {'BUSINESS_REGISTRATION', 'OWNER_IDENTITY'})) {
      throw const FormatException(
        'Vendor business and owner identity documents are required.',
      );
    }
    return _applicationCommand(
      (application) => _remote.submitDocuments(
        application.revision,
        List.unmodifiable(normalizedDocuments),
      ),
    );
  }

  Future<void> scheduleFieldVisit() => _applicationCommand(
    (application) => _remote.scheduleVisit(
      application.revision,
      DateTime.now().toUtc().add(const Duration(days: 1)),
    ),
  );

  Future<void> configureZones(List<Map<String, Object?>> zones) {
    if (zones.isEmpty || zones.length > 20) {
      throw const FormatException('Vendor service zones are invalid.');
    }
    final normalizedZones = <Map<String, Object?>>[];
    final zoneIds = <String>{};
    for (final zone in zones) {
      final id = zone['id'];
      final postalCodes = zone['postal_codes'];
      final latitude = zone['latitude'];
      final longitude = zone['longitude'];
      final radius = zone['radius_km'];
      final policy = zone['policy_version'];
      if (id is! String ||
          id.trim().isEmpty ||
          postalCodes is! List<Object?> ||
          postalCodes.isEmpty ||
          postalCodes.any(
            (value) =>
                value is! String || !RegExp(r'^[0-9]{4,10}$').hasMatch(value),
          ) ||
          latitude is! num ||
          latitude < -90 ||
          latitude > 90 ||
          longitude is! num ||
          longitude < -180 ||
          longitude > 180 ||
          radius is! num ||
          radius <= 0 ||
          radius > 250 ||
          policy is! String ||
          policy.trim().isEmpty) {
        throw const FormatException('Vendor service zone is invalid.');
      }
      if (!zoneIds.add(id)) {
        throw const FormatException('Vendor service-zone IDs must be unique.');
      }
      normalizedZones.add({
        'id': id,
        'postal_codes': List<String>.unmodifiable(
          postalCodes.whereType<String>(),
        ),
        'latitude': latitude,
        'longitude': longitude,
        'radius_km': radius,
        'policy_version': policy,
      });
    }
    return _applicationCommand(
      (application) => _remote.setZones(
        application.revision,
        List.unmodifiable(normalizedZones),
      ),
    );
  }

  Future<void> configureBank(Map<String, Object?> bank) {
    final reference = bank['reference'];
    final holderName = bank['holder_name'];
    final last4 = bank['last4'];
    final ifsc = bank['ifsc'];
    if (reference is! String ||
        !_validPrivateReference(reference) ||
        holderName is! String ||
        holderName.trim().length < 2 ||
        last4 is! String ||
        !RegExp(r'^[0-9]{4}$').hasMatch(last4) ||
        ifsc is! String ||
        !RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(ifsc)) {
      throw const FormatException(
        'Tokenized vendor bank reference is invalid.',
      );
    }
    return _applicationCommand(
      (application) => _remote.setBank(
        application.revision,
        Map.unmodifiable({
          'reference': reference,
          'holder_name': holderName.trim(),
          'last4': last4,
          'ifsc': ifsc,
        }),
      ),
    );
  }

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
    String? description,
    String? sku,
  }) async {
    saveCatalogDraft(
      kind: kind,
      name: name,
      description: description,
      sku: sku,
      amountMinor: amountMinor,
    );
    await publishCatalogDraft();
  }

  void saveCatalogDraft({
    required String kind,
    required String name,
    required int amountMinor,
    String? description,
    String? sku,
  }) {
    final normalizedKind = kind.trim().toUpperCase();
    final normalizedName = name.trim();
    final normalizedDescription = description?.trim().isNotEmpty == true
        ? description!.trim()
        : '$normalizedName published from the vendor mobile app';
    final generatedPrefix = normalizedKind.isEmpty
        ? 'I'
        : normalizedKind.substring(0, 1);
    final normalizedSku = sku?.trim().isNotEmpty == true
        ? sku!.trim()
        : '$generatedPrefix-${DateTime.now().millisecondsSinceEpoch}';
    if (!{'PRODUCT', 'SERVICE', 'FOOD'}.contains(normalizedKind) ||
        normalizedName.length < 3 ||
        normalizedName.length > 120 ||
        normalizedDescription.length < 3 ||
        normalizedDescription.length > 500 ||
        !_vendorSafeId.hasMatch(normalizedSku) ||
        amountMinor < 1) {
      throw const FormatException('Catalog draft is invalid.');
    }
    _state = _state.copyWith(
      catalogDraft: VendorCatalogDraft(
        kind: normalizedKind,
        name: normalizedName,
        description: normalizedDescription,
        sku: normalizedSku,
        amountMinor: amountMinor,
      ),
      catalogDraftStatus: VendorDraftSyncStatus.draft,
      clearMessage: true,
    );
    notifyListeners();
  }

  Future<void> publishCatalogDraft() async {
    final draft = _state.catalogDraft;
    if (draft == null) throw StateError('A catalog draft is required.');
    _state = _state.copyWith(
      status: OperationsStatus.submitting,
      catalogDraftStatus: VendorDraftSyncStatus.syncing,
      clearMessage: true,
    );
    notifyListeners();
    try {
      final value = await _remote.createCatalog({
        'kind': draft.kind,
        'name': draft.name,
        'description': draft.description,
        'sku': draft.sku,
        'price': {'amount_minor': draft.amountMinor, 'currency': 'INR'},
      });
      _state = _state.copyWith(
        status: OperationsStatus.ready,
        catalog: [value, ..._state.catalog],
        catalogDraftStatus: VendorDraftSyncStatus.synced,
        clearCatalogDraft: true,
        message:
            'Catalog item submitted with server revision ${value.revision}.',
      );
    } catch (error) {
      _state = _state.copyWith(
        status: _draftOperationStatus(error),
        catalogDraftStatus: _draftFailureStatus(error),
        message: _draftFailureMessage(error),
      );
    }
    notifyListeners();
  }

  Future<void> updateCatalog({
    required VendorCatalogItem item,
    required String kind,
    required String name,
    required String description,
    required String sku,
    required int amountMinor,
    String currency = 'INR',
  }) {
    final normalizedKind = kind.trim().toUpperCase();
    final normalizedName = name.trim();
    final normalizedDescription = description.trim();
    final normalizedSku = sku.trim();
    final normalizedCurrency = currency.trim().toUpperCase();
    if (!item.allowedActions.contains('EDIT') ||
        !{'PRODUCT', 'SERVICE', 'FOOD'}.contains(normalizedKind) ||
        normalizedName.length < 3 ||
        normalizedName.length > 120 ||
        normalizedDescription.length < 3 ||
        normalizedDescription.length > 500 ||
        !_vendorSafeId.hasMatch(normalizedSku) ||
        amountMinor < 0 ||
        !RegExp(r'^[A-Z]{3}$').hasMatch(normalizedCurrency)) {
      throw const FormatException('Catalog update is invalid.');
    }
    return _run(() async {
      final updated = await _remote.updateCatalog(item, {
        'kind': normalizedKind,
        'name': normalizedName,
        'description': normalizedDescription,
        'sku': normalizedSku,
        'price': {'amount_minor': amountMinor, 'currency': normalizedCurrency},
      });
      _replaceCatalog(updated);
    });
  }

  Future<void> setInventory(VendorCatalogItem item, int stock) {
    if (!item.allowedActions.contains('SET_INVENTORY') ||
        stock < 0 ||
        stock > 1000000) {
      throw const FormatException('Inventory quantity is invalid.');
    }
    return _run(() async {
      final updated = await _remote.setInventory(item, stock);
      _replaceCatalog(updated);
    });
  }

  Future<void> setSchedule(VendorCatalogItem item) async {
    saveScheduleDraft(item);
    await publishScheduleDraft();
  }

  void saveScheduleDraft(
    VendorCatalogItem item, {
    List<Map<String, Object?>> schedules = const [
      {
        'weekday': 1,
        'starts_minute': 540,
        'ends_minute': 1020,
        'time_zone': 'Asia/Kolkata',
        'capacity': 4,
        'buffer_minutes': 30,
      },
    ],
  }) {
    if (!item.allowedActions.contains('SET_SCHEDULE')) {
      throw const FormatException('Schedule changes are not allowed.');
    }
    final normalizedSchedules = _normalizeVendorSchedules(schedules);
    _state = _state.copyWith(
      scheduleDraft: VendorScheduleDraft(
        itemId: item.id,
        baseRevision: item.revision,
        schedules: normalizedSchedules,
      ),
      scheduleDraftStatus: VendorDraftSyncStatus.draft,
      clearMessage: true,
    );
    notifyListeners();
  }

  Future<void> publishScheduleDraft() async {
    final draft = _state.scheduleDraft;
    if (draft == null) throw StateError('A schedule draft is required.');
    final item = _state.catalog
        .where((value) => value.id == draft.itemId)
        .firstOrNull;
    if (item == null || item.revision != draft.baseRevision) {
      _state = _state.copyWith(
        status: OperationsStatus.failure,
        scheduleDraftStatus: VendorDraftSyncStatus.conflict,
        message: 'This schedule changed. Refresh and review the saved draft.',
      );
      notifyListeners();
      return;
    }
    _state = _state.copyWith(
      status: OperationsStatus.submitting,
      scheduleDraftStatus: VendorDraftSyncStatus.syncing,
      clearMessage: true,
    );
    notifyListeners();
    try {
      final updated = await _remote.setSchedule(item, draft.schedules);
      _replaceCatalog(updated);
      _state = _state.copyWith(
        status: OperationsStatus.ready,
        scheduleDraftStatus: VendorDraftSyncStatus.synced,
        clearScheduleDraft: true,
        message: 'Availability synced at revision ${updated.revision}.',
      );
    } catch (error) {
      _state = _state.copyWith(
        status: _draftOperationStatus(error),
        scheduleDraftStatus: _draftFailureStatus(error),
        message: _draftFailureMessage(error),
      );
    }
    notifyListeners();
  }

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

  Future<void> createPromotion({
    String title = 'Local launch offer',
    int budgetMinor = 100000,
    int durationDays = 7,
  }) async {
    savePromotionDraft(
      title: title,
      budgetMinor: budgetMinor,
      durationDays: durationDays,
    );
    await publishPromotionDraft();
  }

  void savePromotionDraft({
    required String title,
    required int budgetMinor,
    required int durationDays,
  }) {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty ||
        normalizedTitle.length > 120 ||
        budgetMinor < 1 ||
        durationDays < 1 ||
        durationDays > 90) {
      throw const FormatException('Promotion draft is invalid.');
    }
    _state = _state.copyWith(
      promotionDraft: VendorPromotionDraft(
        title: normalizedTitle,
        budgetMinor: budgetMinor,
        durationDays: durationDays,
      ),
      promotionDraftStatus: VendorDraftSyncStatus.draft,
      clearMessage: true,
    );
    notifyListeners();
  }

  Future<void> publishPromotionDraft() async {
    final draft = _state.promotionDraft;
    if (draft == null) throw StateError('A promotion draft is required.');
    _state = _state.copyWith(
      status: OperationsStatus.submitting,
      promotionDraftStatus: VendorDraftSyncStatus.syncing,
      clearMessage: true,
    );
    notifyListeners();
    final now = DateTime.now().toUtc();
    try {
      await _remote.createPromotion({
        'title': draft.title,
        'kind': 'DISCOUNT',
        'budget': {'amount_minor': draft.budgetMinor, 'currency': 'INR'},
        'starts_at': now.toIso8601String(),
        'ends_at': now
            .add(Duration(days: draft.durationDays))
            .toIso8601String(),
      });
      _state = _state.copyWith(
        status: OperationsStatus.ready,
        promotionDraftStatus: VendorDraftSyncStatus.synced,
        clearPromotionDraft: true,
        message: 'Promotion submitted for server review.',
      );
    } catch (error) {
      _state = _state.copyWith(
        status: _draftOperationStatus(error),
        promotionDraftStatus: _draftFailureStatus(error),
        message: _draftFailureMessage(error),
      );
    }
    notifyListeners();
  }

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

  OperationsStatus _draftOperationStatus(Object error) =>
      error is ApiTransportFailure
      ? OperationsStatus.offline
      : OperationsStatus.failure;

  VendorDraftSyncStatus _draftFailureStatus(Object error) => switch (error) {
    ApiTransportFailure() => VendorDraftSyncStatus.offline,
    ApiConflictFailure() => VendorDraftSyncStatus.conflict,
    _ => VendorDraftSyncStatus.failure,
  };

  String _draftFailureMessage(Object error) => switch (error) {
    ApiTransportFailure() =>
      'Saved as a draft while offline. Reconnect to sync it.',
    ApiConflictFailure() =>
      'The server revision changed. Refresh and review the saved draft.',
    _ => 'The saved draft could not be submitted safely.',
  };

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
  static const terminalStatuses = {
    'DELIVERED',
    'COMPLETED',
    'CANCELLED',
    'EXPIRED',
    'REASSIGNED',
  };

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
    this.requiredEvidence = const {'OTP', 'PHOTO'},
    this.pickupLatitude,
    this.pickupLongitude,
    this.dropoffLatitude,
    this.dropoffLongitude,
  });
  factory RiderTask.fromJson(Object? value) {
    final json = _roleObject(value, 'rider task');
    final pickup = _roleObject(json['pickup'], 'pickup');
    final dropoff = _roleObject(json['dropoff'], 'dropoff');
    final pickupPoint = pickup['point'] == null
        ? null
        : _roleObject(pickup['point'], 'pickup point');
    final dropoffPoint = dropoff['point'] == null
        ? null
        : _roleObject(dropoff['point'], 'dropoff point');
    final rawEvidence = json['required_evidence'];
    if (rawEvidence != null &&
        (rawEvidence is! List<Object?> ||
            rawEvidence.any(
              (value) =>
                  value is! String ||
                  !{'OTP', 'PHOTO', 'SIGNATURE'}.contains(value),
            ))) {
      throw const FormatException('Delivery evidence policy is invalid.');
    }
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
      requiredEvidence: rawEvidence == null
          ? const {'OTP', 'PHOTO'}
          : Set.unmodifiable((rawEvidence as List<Object?>).cast<String>()),
      pickupLatitude: _roleCoordinate(pickupPoint, 'latitude', latitude: true),
      pickupLongitude: _roleCoordinate(
        pickupPoint,
        'longitude',
        latitude: false,
      ),
      dropoffLatitude: _roleCoordinate(
        dropoffPoint,
        'latitude',
        latitude: true,
      ),
      dropoffLongitude: _roleCoordinate(
        dropoffPoint,
        'longitude',
        latitude: false,
      ),
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
  final Set<String> requiredEvidence;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? dropoffLatitude;
  final double? dropoffLongitude;

  ({double latitude, double longitude})? get navigationDestination {
    final pickup = allowedActions.contains('NAVIGATE_PICKUP');
    final latitude = pickup ? pickupLatitude : dropoffLatitude;
    final longitude = pickup ? pickupLongitude : dropoffLongitude;
    if (latitude == null || longitude == null) return null;
    return (latitude: latitude, longitude: longitude);
  }

  bool get isTerminal => terminalStatuses.contains(status);

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

  void validate() {
    if (deviceSequence < 1 ||
        deviceSequence > 0x7fffffff ||
        !RegExp(r'^[a-zA-Z0-9._:-]{8,160}$').hasMatch(commandId) ||
        !const {'ACCEPT', 'PICKUP', 'COMPLETE'}.contains(kind) ||
        taskId.trim().isEmpty ||
        taskId.length > 160 ||
        revision < 0 ||
        payload.length > 8) {
      throw const FormatException('Rider offline command is invalid.');
    }
  }
}

abstract final class RiderCommandQueuePolicy {
  static const maxCommands = 100;
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

enum RiderLocationIssue {
  serviceDisabled,
  permissionDenied,
  permissionPermanentlyDenied,
  unavailable,
}

final class RiderLocationException implements Exception {
  const RiderLocationException(this.issue, this.message);

  final RiderLocationIssue issue;
  final String message;

  @override
  String toString() => message;
}

enum RiderLocationStatus {
  unknown,
  ready,
  tracking,
  serviceDisabled,
  permissionDenied,
  permissionPermanentlyDenied,
  unavailable,
}

/// Platform location streams live in the rider application. Keeping the
/// boundary here lets the controller tie tracking strictly to an active duty
/// session without making unit tests depend on device plugins.
abstract interface class RiderLocationTracker {
  Future<void> start(
    Future<void> Function(RiderTrackedPosition position) onPosition,
  );
  Future<void> stop();
  Future<void> openAppSettings();
  Future<void> openServiceSettings();
}

final class MemoryRiderCommandStore implements RiderCommandStore {
  final List<RiderOfflineCommand> _commands = [];
  @override
  Future<void> enqueue(RiderOfflineCommand command) async {
    command.validate();
    if (_commands.every((value) => value.commandId != command.commandId)) {
      if (_commands.length >= RiderCommandQueuePolicy.maxCommands) {
        throw StateError('Rider offline command queue is full.');
      }
      _commands.add(command);
      _commands.sort((a, b) => a.deviceSequence.compareTo(b.deviceSequence));
    }
  }

  @override
  Future<List<RiderOfflineCommand>> pending() async =>
      List.unmodifiable(_commands);

  @override
  Future<void> replace(List<RiderOfflineCommand> commands) async {
    if (commands.length > RiderCommandQueuePolicy.maxCommands) {
      throw StateError('Rider offline command queue is full.');
    }
    for (final command in commands) {
      command.validate();
    }
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
    this.locationStatus = RiderLocationStatus.unknown,
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
  final RiderLocationStatus locationStatus;
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
    RiderLocationStatus? locationStatus,
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
    locationStatus: locationStatus ?? this.locationStatus,
    message: clearMessage ? null : message ?? this.message,
  );
}

final class RiderDocumentDraft {
  const RiderDocumentDraft({required this.kind, required this.assetId});

  final String kind;
  final String assetId;

  Map<String, Object?> toJson() => {
    'kind': kind,
    'asset_id': assetId,
    'ocr_status': 'PENDING',
  };
}

final class RiderRegistrationDraft {
  const RiderRegistrationDraft({
    required this.fullName,
    required this.vehicleType,
    required this.vehicleNumber,
    required this.documents,
    required this.bankReference,
    required this.zones,
  });

  final String fullName;
  final String vehicleType;
  final String vehicleNumber;
  final List<RiderDocumentDraft> documents;
  final String bankReference;
  final List<String> zones;

  Map<String, Object?> toJson() {
    final name = fullName.trim();
    final vehicle = vehicleNumber.trim().toUpperCase();
    final documentKinds = documents.map((value) => value.kind).toSet();
    final requiredDocumentKinds = <String>{'IDENTITY'};
    if (vehicleType != 'BICYCLE') {
      requiredDocumentKinds.addAll(const {
        'DRIVER_LICENSE',
        'VEHICLE_REGISTRATION',
        'INSURANCE',
      });
    }
    if (name.length < 2 ||
        name.length > 120 ||
        !const {'BICYCLE', 'MOTORBIKE', 'CAR', 'VAN'}.contains(vehicleType) ||
        !RegExp(r'^[A-Z0-9 -]{4,20}$').hasMatch(vehicle) ||
        documents.isEmpty ||
        documents.length > 8 ||
        documentKinds.length != documents.length ||
        !documentKinds.containsAll(requiredDocumentKinds) ||
        documents.any(
          (document) =>
              !const {
                'DRIVER_LICENSE',
                'IDENTITY',
                'VEHICLE_REGISTRATION',
                'INSURANCE',
              }.contains(document.kind) ||
              !_validPrivateReference(document.assetId),
        ) ||
        !_validPrivateReference(bankReference) ||
        zones.isEmpty ||
        zones.length > 20 ||
        zones.any((zone) => !RegExp(r'^[0-9]{4,10}$').hasMatch(zone))) {
      throw const FormatException('Rider registration draft is invalid.');
    }
    return {
      'full_name': name,
      'vehicle_type': vehicleType,
      'vehicle_number': vehicle,
      'documents': documents.map((value) => value.toJson()).toList(),
      'bank_reference': bankReference,
      'zones': List<String>.unmodifiable(zones),
    };
  }
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
    final pendingCommands = await _commandStore.pending();
    for (final command in pendingCommands) {
      command.validate();
      if (command.deviceSequence > _deviceSequence) {
        _deviceSequence = command.deviceSequence;
      }
    }
    _state = _state.copyWith(
      profile: profile,
      duty: duty,
      pendingCommands: pendingCommands.length,
      locationStatus: _locationTracker == null
          ? RiderLocationStatus.unavailable
          : RiderLocationStatus.ready,
    );
    if (_dutyIsActive(duty)) {
      await _locationTracker?.start(_publishTrackedPosition);
      if (_locationTracker != null) {
        _state = _state.copyWith(locationStatus: RiderLocationStatus.tracking);
      }
    }
  });

  Future<void> register(RiderRegistrationDraft draft) => _run(() async {
    final profile = await _remote.register(draft.toJson());
    _state = _state.copyWith(profile: profile);
  });

  Future<void> startDuty({String? zoneId}) => _run(() async {
    final profile = _state.profile;
    if (profile == null || profile.status != 'APPROVED') {
      throw StateError('An approved rider profile is required.');
    }
    final selectedZone = zoneId ?? profile.zones.firstOrNull;
    if (selectedZone == null || !profile.zones.contains(selectedZone)) {
      throw const FormatException('Select an approved rider service zone.');
    }
    await _locationTracker?.start(_publishTrackedPosition);
    try {
      _state = _state.copyWith(
        duty: await _remote.startDuty(selectedZone),
        locationStatus: _locationTracker == null
            ? RiderLocationStatus.unavailable
            : RiderLocationStatus.tracking,
      );
    } catch (_) {
      await _locationTracker?.stop();
      rethrow;
    }
    await _refreshTasks();
  });

  Future<void> endDuty() => _run(() async {
    final duty = _state.duty;
    if (duty == null) return;
    _state = _state.copyWith(
      duty: await _remote.endDuty(duty.revision),
      locationStatus: _locationTracker == null
          ? RiderLocationStatus.unavailable
          : RiderLocationStatus.ready,
    );
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
    String blurredPhotoAssetId = '',
    String signatureAssetId = '',
  }) {
    if (task.requiredEvidence.contains('OTP') &&
        !RegExp(r'^\d{4,8}$').hasMatch(otp)) {
      throw const FormatException('A valid delivery OTP is required.');
    }
    if (task.requiredEvidence.contains('PHOTO') &&
        blurredPhotoAssetId.isEmpty) {
      throw const FormatException('A private delivery photo is required.');
    }
    if (task.requiredEvidence.contains('SIGNATURE') &&
        signatureAssetId.isEmpty) {
      throw const FormatException('A recipient signature is required.');
    }
    return _taskCommand(
      task,
      'COMPLETE',
      () => _remote.complete(
        task,
        otp: otp,
        blurredPhotoAssetId: blurredPhotoAssetId,
        signatureAssetId: signatureAssetId,
      ),
      payload: {
        if (otp.isNotEmpty) 'otp': otp,
        if (blurredPhotoAssetId.isNotEmpty)
          'blurred_photo_asset_id': blurredPhotoAssetId,
        if (signatureAssetId.isNotEmpty) 'signature_asset_id': signatureAssetId,
      },
    );
  }

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
    if (!_dutyIsActive(_state.duty)) return;
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

  Future<void> openLocationSettings() async {
    final tracker = _locationTracker;
    if (tracker == null) return;
    if (_state.locationStatus == RiderLocationStatus.serviceDisabled) {
      await tracker.openServiceSettings();
    } else {
      await tracker.openAppSettings();
    }
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
    } on RiderLocationException catch (error) {
      _state = _state.copyWith(
        status: OperationsStatus.failure,
        locationStatus: switch (error.issue) {
          RiderLocationIssue.serviceDisabled =>
            RiderLocationStatus.serviceDisabled,
          RiderLocationIssue.permissionDenied =>
            RiderLocationStatus.permissionDenied,
          RiderLocationIssue.permissionPermanentlyDenied =>
            RiderLocationStatus.permissionPermanentlyDenied,
          RiderLocationIssue.unavailable => RiderLocationStatus.unavailable,
        },
        message: error.message,
      );
    } catch (_) {
      _state = _state.copyWith(
        status: OperationsStatus.failure,
        message: 'The operation could not be completed safely.',
      );
    }
    notifyListeners();
  }

  bool _dutyIsActive(RiderDuty? duty) =>
      duty != null && {'ACTIVE', 'ONLINE'}.contains(duty.status);

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

final RegExp _vendorSafeId = RegExp(r'^[A-Za-z0-9._:-]{1,128}$');

bool _validPrivateReference(String value) =>
    RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._:-]{7,159}$').hasMatch(value);

String _roleString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key is invalid.');
  }
  return value;
}

String? _optionalRoleString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('$key is invalid.');
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
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

DateTime? _optionalRoleInstant(Map<String, Object?> json, String key) {
  if (json[key] == null) return null;
  return _roleInstant(json, key);
}

List<Map<String, Object?>> _normalizeVendorSchedules(
  List<Map<String, Object?>> schedules,
) {
  if (schedules.isEmpty || schedules.length > 28) {
    throw const FormatException('Schedule draft is invalid.');
  }
  final normalized = <Map<String, Object?>>[];
  for (final schedule in schedules) {
    final weekday = schedule['weekday'];
    final startsMinute = schedule['starts_minute'];
    final endsMinute = schedule['ends_minute'];
    final timeZone = schedule['time_zone'];
    final capacity = schedule['capacity'];
    final bufferMinutes = schedule['buffer_minutes'];
    if (weekday is! int ||
        weekday < 1 ||
        weekday > 7 ||
        startsMinute is! int ||
        startsMinute < 0 ||
        endsMinute is! int ||
        endsMinute > 1440 ||
        endsMinute <= startsMinute ||
        timeZone is! String ||
        timeZone.trim().isEmpty ||
        capacity is! int ||
        capacity < 1 ||
        bufferMinutes is! int ||
        bufferMinutes < 0) {
      throw const FormatException('Schedule draft is invalid.');
    }
    normalized.add(
      Map.unmodifiable({
        'weekday': weekday,
        'starts_minute': startsMinute,
        'ends_minute': endsMinute,
        'time_zone': timeZone.trim(),
        'capacity': capacity,
        'buffer_minutes': bufferMinutes,
      }),
    );
  }
  for (var index = 0; index < normalized.length; index++) {
    final value = normalized[index];
    for (var other = index + 1; other < normalized.length; other++) {
      final candidate = normalized[other];
      if (value['weekday'] == candidate['weekday'] &&
          (value['starts_minute']! as int) <
              (candidate['ends_minute']! as int) &&
          (candidate['starts_minute']! as int) <
              (value['ends_minute']! as int)) {
        throw const FormatException('Schedule windows cannot overlap.');
      }
    }
  }
  return List.unmodifiable(normalized);
}

double? _roleCoordinate(
  Map<String, Object?>? json,
  String key, {
  required bool latitude,
}) {
  if (json == null) return null;
  final value = json[key];
  if (value is! num) throw FormatException('$key must be a number.');
  final coordinate = value.toDouble();
  final limit = latitude ? 90 : 180;
  if (!coordinate.isFinite || coordinate < -limit || coordinate > limit) {
    throw FormatException('$key is outside the valid coordinate range.');
  }
  return coordinate;
}

List<T> _roleDecodeWrappedList<T>(
  Object? value,
  String key,
  T Function(Object?) decode,
) {
  final json = _roleObject(value, 'list response');
  return _roleList(json, key).map(decode).toList(growable: false);
}
