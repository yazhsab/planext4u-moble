import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';

import 'catalog.dart';
import 'phase5.dart' show EmergencyAssistance;

enum OperationsStatus { idle, loading, ready, submitting, offline, failure }

/// Opaque document references returned by a private onboarding provider.
///
/// The mobile application never receives or persists extracted KYC fields.
final class VendorOnboardingDocument {
  const VendorOnboardingDocument({required this.kind, required this.assetId});

  final String kind;
  final String assetId;

  Map<String, Object?> toJson() => {'kind': kind, 'asset_id': assetId};
}

/// Masked bank metadata plus the provider-owned token used by the backend.
final class VendorOnboardingBankAccount {
  const VendorOnboardingBankAccount({
    required this.reference,
    required this.holderName,
    required this.last4,
    required this.ifsc,
  });

  final String reference;
  final String holderName;
  final String last4;
  final String ifsc;

  Map<String, Object?> toJson() => {
    'reference': reference,
    'holder_name': holderName,
    'last4': last4,
    'ifsc': ifsc,
  };
}

/// Integration boundary for OCR/KYC and bank-tokenization SDKs.
///
/// Production apps leave this unset until the approved private providers are
/// configured. The UI then fails closed instead of accepting raw documents or
/// bank account numbers.
abstract interface class VendorOnboardingProvider {
  Future<List<VendorOnboardingDocument>> collectDocuments();
  Future<VendorOnboardingBankAccount> tokenizeBankAccount();
}

final class VendorFieldVisitDraft {
  const VendorFieldVisitDraft({
    required this.scheduledAt,
    required this.latitude,
    required this.longitude,
    required this.allowedRadiusMeters,
  });

  final DateTime scheduledAt;
  final double latitude;
  final double longitude;
  final int allowedRadiusMeters;

  Map<String, Object?> toJson() => {
    'scheduled_at': scheduledAt.toUtc().toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    'allowed_radius_m': allowedRadiusMeters,
  };
}

final class RiderOnboardingEvidence {
  const RiderOnboardingEvidence({
    required this.documents,
    required this.bankReference,
  });

  final List<RiderDocumentDraft> documents;
  final String bankReference;
}

/// Integration boundary for rider KYC, private uploads and bank tokenization.
abstract interface class RiderOnboardingProvider {
  Future<RiderOnboardingEvidence> collectEvidence({
    required String vehicleType,
  });
}

enum RiderPodEvidenceKind { blurredPhoto, signature }

final class RiderPodBinaryEvidence {
  const RiderPodBinaryEvidence({
    required this.bytes,
    required this.contentType,
  });

  final Uint8List bytes;
  final String contentType;
}

/// Device-camera boundary. Returning `null` means the rider cancelled capture.
abstract interface class RiderPodPhotoSource {
  Future<RiderPodBinaryEvidence?> capture(RiderTask task);
}

/// Private upload/processing boundary. Photo implementations must return only
/// the server-owned reference for the privacy-processed (blurred) result.
abstract interface class RiderPodEvidenceUploader {
  Future<String> upload({
    required RiderTask task,
    required RiderPodEvidenceKind kind,
    required RiderPodBinaryEvidence evidence,
  });
}

final class RiderPodCaptureCoordinator {
  const RiderPodCaptureCoordinator({
    required RiderPodPhotoSource photoSource,
    required RiderPodEvidenceUploader uploader,
  }) : _photoSource = photoSource,
       _uploader = uploader;

  static const int maxPhotoBytes = 10 * 1024 * 1024;
  static const int maxSignatureBytes = 1024 * 1024;

  final RiderPodPhotoSource _photoSource;
  final RiderPodEvidenceUploader _uploader;

  Future<String?> capturePhoto(RiderTask task) async {
    final evidence = await _photoSource.capture(task);
    if (evidence == null) return null;
    _validateEvidence(
      evidence,
      kind: RiderPodEvidenceKind.blurredPhoto,
      maximumBytes: maxPhotoBytes,
      allowedContentTypes: const {'image/jpeg', 'image/png'},
    );
    return _upload(task, RiderPodEvidenceKind.blurredPhoto, evidence);
  }

  Future<String?> uploadSignature(RiderTask task, Uint8List bytes) async {
    final evidence = RiderPodBinaryEvidence(
      bytes: bytes,
      contentType: 'image/png',
    );
    _validateEvidence(
      evidence,
      kind: RiderPodEvidenceKind.signature,
      maximumBytes: maxSignatureBytes,
      allowedContentTypes: const {'image/png'},
    );
    return _upload(task, RiderPodEvidenceKind.signature, evidence);
  }

  Future<String> _upload(
    RiderTask task,
    RiderPodEvidenceKind kind,
    RiderPodBinaryEvidence evidence,
  ) async {
    final reference = (await _uploader.upload(
      task: task,
      kind: kind,
      evidence: evidence,
    )).trim();
    if (!_validPrivateReference(reference)) {
      throw const FormatException(
        'POD provider returned an invalid private asset reference.',
      );
    }
    return reference;
  }

  static void _validateEvidence(
    RiderPodBinaryEvidence evidence, {
    required RiderPodEvidenceKind kind,
    required int maximumBytes,
    required Set<String> allowedContentTypes,
  }) {
    if (evidence.bytes.isEmpty ||
        evidence.bytes.length > maximumBytes ||
        !allowedContentTypes.contains(evidence.contentType)) {
      throw FormatException('Invalid ${kind.name} evidence payload.');
    }
  }
}

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
  Future<VendorApplication> scheduleVisit(
    int revision,
    VendorFieldVisitDraft visit,
  );
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
  Future<VendorApplication> scheduleVisit(
    int revision,
    VendorFieldVisitDraft visit,
  ) => _revisionCommand(
    'supply.schedule_visit',
    '/v1/vendor/application/field-visit',
    revision,
    visit.toJson(),
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

  Future<void> submitOnboardingDocuments(
    List<VendorOnboardingDocument> documents,
  ) => submitDocuments(
    documents.map((document) => document.toJson()).toList(growable: false),
  );

  Future<void> scheduleFieldVisit(VendorFieldVisitDraft visit) {
    final now = DateTime.now().toUtc();
    final scheduledAt = visit.scheduledAt.toUtc();
    if (!visit.latitude.isFinite ||
        visit.latitude < -90 ||
        visit.latitude > 90 ||
        !visit.longitude.isFinite ||
        visit.longitude < -180 ||
        visit.longitude > 180 ||
        visit.allowedRadiusMeters < 25 ||
        visit.allowedRadiusMeters > 1000 ||
        !scheduledAt.isAfter(now) ||
        scheduledAt.isAfter(now.add(const Duration(days: 90)))) {
      throw const FormatException('Vendor field visit details are invalid.');
    }
    return _applicationCommand(
      (application) => _remote.scheduleVisit(application.revision, visit),
    );
  }

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

  Future<void> configureOnboardingBank(VendorOnboardingBankAccount bank) =>
      configureBank(bank.toJson());

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

enum RiderOfferDeclineReason {
  tooFar('TOO_FAR', 'Pickup is too far'),
  vehicleOrCapacity('VEHICLE_OR_CAPACITY', 'Vehicle or capacity mismatch'),
  endingDuty('ENDING_DUTY', 'Ending duty soon'),
  safetyConcern('SAFETY_CONCERN', 'Safety concern'),
  other('OTHER', 'Other');

  const RiderOfferDeclineReason(this.code, this.label);
  final String code;
  final String label;
}

final class RiderOfferDecline {
  const RiderOfferDecline({
    required this.taskId,
    required this.taskRevision,
    required this.reason,
    required this.declinedAt,
    this.note = '',
  });

  factory RiderOfferDecline.fromJson(Object? value) {
    final json = _roleObject(value, 'rider offer decline');
    final reasonCode = _roleString(json, 'reason_code');
    final reasons = RiderOfferDeclineReason.values.where(
      (reason) => reason.code == reasonCode,
    );
    if (reasons.isEmpty) {
      throw const FormatException('Rider offer decline reason is invalid.');
    }
    return RiderOfferDecline(
      taskId: _roleString(json, 'task_id'),
      taskRevision: _roleInteger(json, 'task_revision'),
      reason: reasons.single,
      declinedAt: _roleInstant(json, 'declined_at'),
      note: json['note'] as String? ?? '',
    );
  }

  final String taskId;
  final int taskRevision;
  final RiderOfferDeclineReason reason;
  final DateTime declinedAt;
  final String note;
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
  Future<RiderOfferDecline> decline(
    RiderTask task, {
    required RiderOfferDeclineReason reason,
    String note,
  });
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
  Future<EmergencyAssistance> createEmergencyIncident({
    required String category,
    required String description,
    required RiderTrackedPosition location,
  });
  Future<EmergencyAssistance> emergencyIncident(String incidentId);
  Future<EmergencyAssistance> updateEmergencyIncidentLocation(
    String incidentId, {
    required bool consent,
    RiderTrackedPosition? location,
  });
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
  Future<RiderOfferDecline> decline(
    RiderTask task, {
    required RiderOfferDeclineReason reason,
    String note = '',
  }) => _revisionCommand(
    'rider.decline_offer',
    '/v1/rider/offers/${Uri.encodeComponent(task.id)}/decline',
    task.revision,
    {
      'reason_code': reason.code,
      if (note.trim().isNotEmpty) 'note': note.trim(),
    },
    RiderOfferDecline.fromJson,
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
      if (otp.isNotEmpty) 'otp': otp,
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
  @override
  Future<EmergencyAssistance> createEmergencyIncident({
    required String category,
    required String description,
    required RiderTrackedPosition location,
  }) => _command(
    'rider.create_emergency_incident',
    '/v1/rider/emergency-incidents',
    {
      'category': category,
      'description': description.trim(),
      'priority': 'CRITICAL',
      'location_consent': true,
      'location': {
        'latitude': location.latitude,
        'longitude': location.longitude,
        'accuracy_m': location.accuracyMeters,
      },
    },
    EmergencyAssistance.fromJson,
  );
  @override
  Future<EmergencyAssistance> emergencyIncident(String incidentId) => _get(
    'rider.get_emergency_incident',
    '/v1/rider/emergency-incidents/${Uri.encodeComponent(incidentId)}',
    EmergencyAssistance.fromJson,
  );
  @override
  Future<EmergencyAssistance> updateEmergencyIncidentLocation(
    String incidentId, {
    required bool consent,
    RiderTrackedPosition? location,
  }) => _command(
    'rider.update_emergency_location',
    '/v1/rider/emergency-incidents/${Uri.encodeComponent(incidentId)}/location',
    {
      'consent': consent,
      'location': {
        'latitude': location?.latitude ?? 0,
        'longitude': location?.longitude ?? 0,
        'accuracy_m': location?.accuracyMeters ?? 0,
      },
    },
    EmergencyAssistance.fromJson,
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
    this.emergencyIncident,
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
  final EmergencyAssistance? emergencyIncident;
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
    EmergencyAssistance? emergencyIncident,
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
    emergencyIncident: emergencyIncident ?? this.emergencyIncident,
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
    required this.dutyLocationConsent,
  });

  final String fullName;
  final String vehicleType;
  final String vehicleNumber;
  final List<RiderDocumentDraft> documents;
  final String bankReference;
  final List<String> zones;
  final bool dutyLocationConsent;

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
        !dutyLocationConsent ||
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
  RiderTrackedPosition? _lastTrackedPosition;
  final Set<String> _submittedCompletions = {};

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
  Future<void> decline(
    RiderTask task, {
    required RiderOfferDeclineReason reason,
    String note = '',
  }) async {
    final normalizedNote = note.trim();
    if (normalizedNote.length > 240 ||
        (reason == RiderOfferDeclineReason.other &&
            normalizedNote.length < 3)) {
      throw const FormatException('Provide a valid offer decline reason.');
    }
    _state = _state.copyWith(
      status: OperationsStatus.submitting,
      clearMessage: true,
    );
    notifyListeners();
    try {
      await _remote.decline(task, reason: reason, note: normalizedNote);
      _state = _state.copyWith(
        status: OperationsStatus.ready,
        offers: _state.offers
            .where((item) => item.id != task.id)
            .toList(growable: false),
        message: 'Offer declined.',
      );
    } on ApiTransportFailure {
      _state = _state.copyWith(
        status: OperationsStatus.offline,
        message:
            'Decline was not queued because this offer may expire. Reconnect and refresh offers.',
      );
    } catch (_) {
      _state = _state.copyWith(
        status: OperationsStatus.failure,
        message: 'The offer changed or is no longer available.',
      );
    }
    notifyListeners();
  }

  Future<void> pickup(RiderTask task) =>
      _taskCommand(task, 'PICKUP', () => _remote.pickup(task));
  Future<void> complete(
    RiderTask task, {
    required String otp,
    String blurredPhotoAssetId = '',
    String signatureAssetId = '',
  }) {
    final required = task.requiredEvidence;
    final requiresOtp = required.contains('OTP');
    final requiresPhoto = required.contains('PHOTO');
    final requiresSignature = required.contains('SIGNATURE');
    if (!task.allowedActions.contains('COMPLETE') || task.isTerminal) {
      throw StateError('This task cannot accept proof of delivery.');
    }
    if (required.any(
          (value) => !const {'OTP', 'PHOTO', 'SIGNATURE'}.contains(value),
        ) ||
        !requiresPhoto ||
        (!requiresOtp && !requiresSignature)) {
      throw const FormatException(
        'The server supplied an unsupported delivery evidence policy.',
      );
    }
    if (requiresOtp && !RegExp(r'^\d{4,8}$').hasMatch(otp)) {
      throw const FormatException('A valid delivery OTP is required.');
    }
    if (!requiresOtp && otp.isNotEmpty) {
      throw const FormatException('Unexpected delivery OTP evidence.');
    }
    if (!_validPrivateReference(blurredPhotoAssetId)) {
      throw const FormatException('A private delivery photo is required.');
    }
    if (requiresSignature && !_validPrivateReference(signatureAssetId)) {
      throw const FormatException('A recipient signature is required.');
    }
    if (!requiresSignature && signatureAssetId.isNotEmpty) {
      throw const FormatException('Unexpected recipient signature evidence.');
    }
    final submissionKey = '${task.id}:${task.revision}';
    if (!_submittedCompletions.add(submissionKey)) return Future<void>.value();
    final current = _state.tasks
        .where((value) => value.id == task.id)
        .firstOrNull;
    if (current != null &&
        (current.revision != task.revision ||
            current.isTerminal ||
            !current.allowedActions.contains('COMPLETE'))) {
      _submittedCompletions.remove(submissionKey);
      throw StateError(
        'Refresh this task before submitting delivery evidence.',
      );
    }
    return _completeOnce(
      task,
      submissionKey: submissionKey,
      otp: otp,
      blurredPhotoAssetId: blurredPhotoAssetId,
      signatureAssetId: signatureAssetId,
    );
  }

  Future<void> _completeOnce(
    RiderTask task, {
    required String submissionKey,
    required String otp,
    required String blurredPhotoAssetId,
    required String signatureAssetId,
  }) async {
    try {
      await _taskCommand(
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
          'blurred_photo_asset_id': blurredPhotoAssetId,
          if (signatureAssetId.isNotEmpty)
            'signature_asset_id': signatureAssetId,
        },
      );
    } finally {
      // Keep the key while an offline completion is queued. Online results
      // advance the task revision, so stale retries are rejected by state.
      if (_state.status != OperationsStatus.offline) {
        _submittedCompletions.remove(submissionKey);
      }
    }
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
    _lastTrackedPosition = position;
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

  Future<void> createEmergencyIncident({
    required String category,
    required String description,
    required bool locationConsent,
  }) => _emergencyMutation(() async {
    if (!_dutyIsActive(_state.duty)) {
      throw StateError('Start duty before requesting emergency assistance.');
    }
    if (!locationConsent) {
      throw const FormatException(
        'Explicit location consent is required for an emergency incident.',
      );
    }
    final normalizedCategory = category.trim().toUpperCase();
    final normalizedDescription = description.trim();
    if (!const {
          'MEDICAL',
          'SAFETY',
          'FIRE',
          'ACCIDENT',
          'OTHER',
        }.contains(normalizedCategory) ||
        normalizedDescription.length < 5 ||
        normalizedDescription.length > 2000) {
      throw const FormatException('Emergency incident details are invalid.');
    }
    _state = _state.copyWith(
      emergencyIncident: await _remote.createEmergencyIncident(
        category: normalizedCategory,
        description: normalizedDescription,
        location: _freshEmergencyPosition(),
      ),
      message: 'Emergency incident created. Keep your phone available.',
    );
  });

  Future<void> refreshEmergencyIncident() => _run(() async {
    final incident = _state.emergencyIncident;
    if (incident == null) return;
    _state = _state.copyWith(
      emergencyIncident: await _remote.emergencyIncident(incident.id),
    );
  });

  Future<void> setEmergencyLocationConsent(bool consent) =>
      _emergencyMutation(() async {
        final incident = _state.emergencyIncident;
        if (incident == null || incident.status == 'RESOLVED') return;
        _state = _state.copyWith(
          emergencyIncident: await _remote.updateEmergencyIncidentLocation(
            incident.id,
            consent: consent,
            location: consent ? _freshEmergencyPosition() : null,
          ),
          message: consent
              ? 'Emergency location refreshed.'
              : 'Emergency location sharing stopped.',
        );
      });

  RiderTrackedPosition _freshEmergencyPosition() {
    final position = _lastTrackedPosition;
    if (position == null ||
        DateTime.now().toUtc().difference(position.capturedAt.toUtc()) >
            const Duration(minutes: 2)) {
      throw StateError(
        'A fresh on-duty location is required. Check location permissions and try again.',
      );
    }
    return position;
  }

  Future<void> _emergencyMutation(Future<void> Function() action) async {
    _state = _state.copyWith(
      status: OperationsStatus.submitting,
      clearMessage: true,
    );
    notifyListeners();
    try {
      await action();
      _state = _state.copyWith(status: OperationsStatus.ready);
    } on ApiTransportFailure {
      _state = _state.copyWith(
        status: OperationsStatus.offline,
        message:
            'Emergency incidents are never queued offline. Contact local emergency services now and retry when connected.',
      );
    } on FormatException catch (error) {
      _state = _state.copyWith(
        status: OperationsStatus.failure,
        message: error.message,
      );
    } on StateError catch (error) {
      _state = _state.copyWith(
        status: OperationsStatus.failure,
        message: error.message,
      );
    } catch (_) {
      _state = _state.copyWith(
        status: OperationsStatus.failure,
        message: 'The emergency incident could not be updated safely.',
      );
    }
    notifyListeners();
  }

  void clearMessage() {
    if (_state.message == null) return;
    _state = _state.copyWith(clearMessage: true);
    notifyListeners();
  }

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
