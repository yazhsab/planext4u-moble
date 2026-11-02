import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:planext4u_storage/planext4u_storage.dart';

/// Form progress only. Raw identity images, bank data, consent grants and
/// submitted evidence never belong in this cache.
final class RiderOnboardingProgress {
  const RiderOnboardingProgress({
    this.fullName = '',
    this.vehicleType = 'MOTORBIKE',
    this.vehicleNumber = '',
    this.postalCodes = '',
    this.applicationId = '',
    this.applicationRevision = 0,
  });

  factory RiderOnboardingProgress.fromJson(Object? value) {
    if (value is! Map<String, Object?> ||
        !{1, 2}.contains(value['schema']) ||
        value.keys.any(
          (key) => !{
            'schema',
            'full_name',
            'vehicle_type',
            'vehicle_number',
            'postal_codes',
            if (value['schema'] == 2) 'application_id',
            if (value['schema'] == 2) 'application_revision',
          }.contains(key),
        ) ||
        value['full_name'] is! String ||
        value['vehicle_type'] is! String ||
        value['vehicle_number'] is! String ||
        value['postal_codes'] is! String ||
        (value['schema'] == 2 &&
            (value['application_id'] is! String ||
                value['application_revision'] is! int))) {
      throw const FormatException('Onboarding form progress is invalid.');
    }
    final result = RiderOnboardingProgress(
      fullName: value['full_name']! as String,
      vehicleType: value['vehicle_type']! as String,
      vehicleNumber: value['vehicle_number']! as String,
      postalCodes: value['postal_codes']! as String,
      applicationId: value['schema'] == 2
          ? value['application_id']! as String
          : '',
      applicationRevision: value['schema'] == 2
          ? value['application_revision']! as int
          : 0,
    );
    result.toJson();
    return result;
  }

  final String fullName;
  final String vehicleType;
  final String vehicleNumber;
  final String postalCodes;

  /// Empty for the first registration. Rework drafts belong to one server revision.
  final String applicationId;
  final int applicationRevision;

  Map<String, Object?> toJson() {
    if (fullName.length > 120 ||
        vehicleNumber.length > 20 ||
        postalCodes.length > 240 ||
        applicationId.length > 128 ||
        applicationRevision < 0 ||
        (applicationId.isEmpty != (applicationRevision == 0)) ||
        !{'MOTORBIKE', 'BICYCLE', 'CAR', 'VAN'}.contains(vehicleType)) {
      throw const FormatException(
        'Onboarding form progress exceeds its limits.',
      );
    }
    return {
      'schema': 2,
      'full_name': fullName,
      'vehicle_type': vehicleType,
      'vehicle_number': vehicleNumber,
      'postal_codes': postalCodes,
      'application_id': applicationId,
      'application_revision': applicationRevision,
    };
  }
}

abstract interface class RiderOnboardingProgressStore {
  Future<RiderOnboardingProgress?> read();
  Future<void> save(RiderOnboardingProgress value);
  Future<void> clear();
}

final class EncryptedRiderOnboardingProgressStore
    implements RiderOnboardingProgressStore {
  EncryptedRiderOnboardingProgressStore({
    required String tenantId,
    required String country,
    required String identityId,
    EncryptedRecordStore? store,
    DateTime Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().toUtc()),
       _key =
           'rider-${sha256.convert(utf8.encode(jsonEncode([tenantId, country, identityId])))}',
       _store =
           store ??
           EncryptedRecordStore(
             records: FileBinaryRecordStore(namespace: 'onboarding-forms-v1'),
             keyProvider: PlatformCacheKeyProvider(
               namespace: 'planext4u.onboarding.forms.v1',
             ),
             namespace: 'onboarding-forms-v1',
             maxPlaintextBytes: 4096,
           ) {
    if (tenantId.isEmpty ||
        identityId.isEmpty ||
        !RegExp(r'^[A-Z]{2}$').hasMatch(country)) {
      throw const FormatException('Onboarding account scope is incomplete.');
    }
  }

  final String _key;
  final EncryptedRecordStore _store;
  final DateTime Function() _clock;
  static final Map<String, Future<void>> _tails = {};

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = (_tails[_key] ?? Future<void>.value()).then(
      (_) => operation(),
    );
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _tails[_key] = tail;
    unawaited(
      tail.whenComplete(() {
        if (identical(_tails[_key], tail)) _tails.remove(_key);
      }),
    );
    return result;
  }

  @override
  Future<RiderOnboardingProgress?> read() => _serialize(() async {
    final result = await _store.get(_key, RiderOnboardingProgress.fromJson);
    return result.value;
  });

  @override
  Future<void> save(RiderOnboardingProgress value) {
    // Validate and capture a value before entering the asynchronous queue.
    final document = value.toJson();
    return _serialize(() {
      final expires = _clock().toUtc().add(const Duration(days: 7));
      return _store.put(
        _key,
        document,
        expiresAt: expires,
        staleUntil: expires,
      );
    });
  }

  @override
  Future<void> clear() => _serialize(() => _store.delete(_key));
}

/// Business form text only. Private document IDs, bank data and reviewer notes
/// are deliberately excluded; those have separate server-owned lifecycles.
final class VendorOnboardingProgress {
  const VendorOnboardingProgress({
    this.businessName = '',
    this.businessType = '',
    this.contactName = '',
    this.applicationId = '',
    this.applicationRevision = 0,
  });

  factory VendorOnboardingProgress.fromJson(Object? value) {
    if (value is! Map<String, Object?> ||
        value['schema'] != 1 ||
        value.keys.any(
          (key) => !{
            'schema',
            'business_name',
            'business_type',
            'contact_name',
            'application_id',
            'application_revision',
          }.contains(key),
        ) ||
        value['business_name'] is! String ||
        value['business_type'] is! String ||
        value['contact_name'] is! String ||
        value['application_id'] is! String ||
        value['application_revision'] is! int) {
      throw const FormatException('Vendor form progress is invalid.');
    }
    final result = VendorOnboardingProgress(
      businessName: value['business_name']! as String,
      businessType: value['business_type']! as String,
      contactName: value['contact_name']! as String,
      applicationId: value['application_id']! as String,
      applicationRevision: value['application_revision']! as int,
    );
    result.toJson();
    return result;
  }

  final String businessName;
  final String businessType;
  final String contactName;
  final String applicationId;
  final int applicationRevision;

  Map<String, Object?> toJson() {
    if (businessName.length > 120 ||
        businessType.length > 120 ||
        contactName.length > 120 ||
        applicationId.length > 128 ||
        applicationRevision < 0 ||
        (applicationId.isEmpty != (applicationRevision == 0))) {
      throw const FormatException('Vendor form progress exceeds its limits.');
    }
    return {
      'schema': 1,
      'business_name': businessName,
      'business_type': businessType,
      'contact_name': contactName,
      'application_id': applicationId,
      'application_revision': applicationRevision,
    };
  }
}

abstract interface class VendorOnboardingProgressStore {
  Future<VendorOnboardingProgress?> read();
  Future<void> save(VendorOnboardingProgress value);
  Future<void> clear();
}

final class EncryptedVendorOnboardingProgressStore
    implements VendorOnboardingProgressStore {
  EncryptedVendorOnboardingProgressStore({
    required String tenantId,
    required String country,
    required String identityId,
    EncryptedRecordStore? store,
    DateTime Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().toUtc()),
       _key =
           'vendor-${sha256.convert(utf8.encode(jsonEncode([tenantId, country, identityId])))}',
       _store =
           store ??
           EncryptedRecordStore(
             records: FileBinaryRecordStore(namespace: 'vendor-forms-v1'),
             keyProvider: PlatformCacheKeyProvider(
               namespace: 'planext4u.vendor.forms.v1',
             ),
             namespace: 'vendor-forms-v1',
             maxPlaintextBytes: 4096,
           ) {
    if (tenantId.isEmpty ||
        identityId.isEmpty ||
        !RegExp(r'^[A-Z]{2}$').hasMatch(country)) {
      throw const FormatException('Onboarding account scope is incomplete.');
    }
  }

  final String _key;
  final EncryptedRecordStore _store;
  final DateTime Function() _clock;
  static final Map<String, Future<void>> _tails = {};

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = (_tails[_key] ?? Future<void>.value()).then(
      (_) => operation(),
    );
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _tails[_key] = tail;
    unawaited(
      tail.whenComplete(() {
        if (identical(_tails[_key], tail)) _tails.remove(_key);
      }),
    );
    return result;
  }

  @override
  Future<VendorOnboardingProgress?> read() => _serialize(() async {
    final result = await _store.get(_key, VendorOnboardingProgress.fromJson);
    return result.value;
  });

  @override
  Future<void> save(VendorOnboardingProgress value) {
    final document = value.toJson();
    return _serialize(() {
      final expires = _clock().toUtc().add(const Duration(days: 7));
      return _store.put(
        _key,
        document,
        expiresAt: expires,
        staleUntil: expires,
      );
    });
  }

  @override
  Future<void> clear() => _serialize(() => _store.delete(_key));
}
