import 'package:planext4u_experience/planext4u_experience.dart';
import 'package:planext4u_storage/planext4u_storage.dart';

abstract interface class CustomerLocationStore {
  Future<ServiceLocation?> read();
  Future<void> write(ServiceLocation value);
}

/// Personal caches survive reauthentication by the same account, while tenant,
/// country and account switches use separate files, encryption keys and AAD.
final class CustomerCacheScope {
  CustomerCacheScope({
    required this.tenantId,
    required this.country,
    required this.identityId,
  }) {
    if (!_uuid.hasMatch(tenantId) ||
        !_uuid.hasMatch(identityId) ||
        !RegExp(r'^[A-Z]{2}$').hasMatch(country)) {
      throw const FormatException('Account cache scope is invalid.');
    }
  }
  final String tenantId;
  final String country;
  final String identityId;
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  String namespace(String purpose) {
    if (!const {'payment', 'bootstrap', 'location'}.contains(purpose)) {
      throw const FormatException('Unsupported account cache.');
    }
    return 'customer.$purpose.v2.${tenantId.toLowerCase()}.${country.toLowerCase()}.${identityId.toLowerCase()}';
  }
}

EncryptedRecordStore _platformStore(CustomerCacheScope scope, String purpose) {
  final namespace = scope.namespace(purpose);
  return EncryptedRecordStore(
    records: FileBinaryRecordStore(namespace: namespace),
    keyProvider: PlatformCacheKeyProvider(namespace: namespace),
    namespace: namespace,
  );
}

final class CustomerPaymentRecoveryStore implements PaymentRecoveryStore {
  CustomerPaymentRecoveryStore(this._store);
  factory CustomerPaymentRecoveryStore.platform(CustomerCacheScope scope) =>
      CustomerPaymentRecoveryStore(_platformStore(scope, 'payment'));

  static const _key = 'pending.payment';
  final EncryptedRecordStore _store;

  @override
  Future<void> clear() => _store.delete(_key);

  @override
  Future<String?> read() async =>
      (await _store.get<String>(_key, (value) => value! as String)).value;

  @override
  Future<void> save(String paymentId) {
    final now = DateTime.now().toUtc();
    return _store.put(
      _key,
      paymentId,
      expiresAt: now.add(const Duration(days: 7)),
      staleUntil: now.add(const Duration(days: 7)),
    );
  }
}

final class CustomerBootstrapCache implements BootstrapCache {
  CustomerBootstrapCache(this._store);
  factory CustomerBootstrapCache.platform(CustomerCacheScope scope) =>
      CustomerBootstrapCache(_platformStore(scope, 'bootstrap'));

  static const _key = 'configuration';
  final EncryptedRecordStore _store;

  @override
  Future<BootstrapConfig?> read() async => (await _store.get<BootstrapConfig>(
    _key,
    (value) => BootstrapConfig.fromJson(value),
  )).value;

  @override
  Future<void> write(BootstrapConfig value) {
    final now = DateTime.now().toUtc();
    return _store.put(
      _key,
      value.toJson(),
      expiresAt: now.add(const Duration(hours: 24)),
      staleUntil: now.add(const Duration(days: 7)),
    );
  }
}

final class CustomerLocationStoreEncrypted implements CustomerLocationStore {
  CustomerLocationStoreEncrypted(this._store);
  factory CustomerLocationStoreEncrypted.platform(CustomerCacheScope scope) =>
      CustomerLocationStoreEncrypted(_platformStore(scope, 'location'));

  static const _key = 'serviceability.location';
  final EncryptedRecordStore _store;

  @override
  Future<ServiceLocation?> read() async =>
      (await _store.get<ServiceLocation>(_key, (value) {
        if (value is! Map<String, Object?> ||
            value['latitude'] is! num ||
            value['longitude'] is! num ||
            value['accuracy_metres'] is! num ||
            value['captured_at'] is! String ||
            value['label'] is! String) {
          throw const FormatException('Stored location is invalid.');
        }
        final capturedAt = DateTime.tryParse(value['captured_at']! as String);
        if (capturedAt == null) {
          throw const FormatException('Stored location time is invalid.');
        }
        return ServiceLocation(
          latitude: (value['latitude']! as num).toDouble(),
          longitude: (value['longitude']! as num).toDouble(),
          accuracyMetres: (value['accuracy_metres']! as num).toDouble(),
          capturedAt: capturedAt.toUtc(),
          label: value['label']! as String,
          postalCode: value['postal_code'] as String?,
        );
      })).value;

  @override
  Future<void> write(ServiceLocation value) {
    final now = DateTime.now().toUtc();
    return _store.put(
      _key,
      {
        'latitude': value.latitude,
        'longitude': value.longitude,
        'accuracy_metres': value.accuracyMetres,
        'captured_at': value.capturedAt.toIso8601String(),
        'label': value.label,
        if (value.postalCode != null) 'postal_code': value.postalCode,
      },
      expiresAt: now.add(const Duration(days: 30)),
      staleUntil: now.add(const Duration(days: 30)),
    );
  }
}
