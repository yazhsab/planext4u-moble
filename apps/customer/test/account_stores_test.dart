import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_customer/account_stores.dart';
import 'package:planext4u_experience/planext4u_experience.dart';
import 'package:planext4u_storage/planext4u_storage.dart';

void main() {
  const tenant = '00000000-0000-4000-8000-000000000001';
  const identity = '00000000-0000-4000-8000-000000000002';
  CustomerCacheScope scope({
    String tenantId = tenant,
    String country = 'IN',
    String identityId = identity,
  }) => CustomerCacheScope(
    tenantId: tenantId,
    country: country,
    identityId: identityId,
  );

  test(
    'pending payment survives same-account recreation without crossing account, country or tenant',
    () async {
      final stores = <String, MemoryBinaryRecordStore>{};
      EncryptedRecordStore records(CustomerCacheScope owner, String purpose) {
        final name = owner.namespace(purpose);
        return EncryptedRecordStore(
          records: stores.putIfAbsent(name, MemoryBinaryRecordStore.new),
          keyProvider: MemoryCacheKeyProvider(),
          namespace: name,
        );
      }

      final original = CustomerPaymentRecoveryStore(
        records(scope(), 'payment'),
      );
      await original.save('payment-owned-by-first-account');
      final otherScopes = [
        scope(identityId: '00000000-0000-4000-8000-000000000003'),
        scope(country: 'NG'),
        scope(tenantId: '00000000-0000-4000-8000-000000000004'),
      ];
      for (final owner in otherScopes) {
        final other = CustomerPaymentRecoveryStore(records(owner, 'payment'));
        expect(await other.read(), isNull);
        await other.save('payment-owned-by-another-account');
        await other.clear();
      }
      final restarted = CustomerPaymentRecoveryStore(
        records(scope(), 'payment'),
      );
      expect(await restarted.read(), 'payment-owned-by-first-account');
    },
  );

  test(
    'copied ciphertext cannot disclose another account even with the same key material',
    () async {
      final firstRecords = MemoryBinaryRecordStore();
      final otherRecords = MemoryBinaryRecordStore();
      EncryptedRecordStore records(
        MemoryBinaryRecordStore physical,
        CustomerCacheScope owner,
      ) => EncryptedRecordStore(
        records: physical,
        keyProvider: MemoryCacheKeyProvider(),
        namespace: owner.namespace('payment'),
      );
      final first = CustomerPaymentRecoveryStore(
        records(firstRecords, scope()),
      );
      final other = CustomerPaymentRecoveryStore(
        records(otherRecords, scope(country: 'NG')),
      );
      await first.save('private-first-payment');
      await otherRecords.writeAtomic(
        'pending.payment',
        (await firstRecords.read('pending.payment'))!,
      );
      expect(await other.read(), isNull);
      expect(await first.read(), 'private-first-payment');
    },
  );

  test(
    'selected address and bootstrap caches remain separate by account and purpose',
    () async {
      final stores = <String, MemoryBinaryRecordStore>{};
      EncryptedRecordStore records(CustomerCacheScope owner, String purpose) {
        final name = owner.namespace(purpose);
        return EncryptedRecordStore(
          records: stores.putIfAbsent(name, MemoryBinaryRecordStore.new),
          keyProvider: MemoryCacheKeyProvider(),
          namespace: name,
        );
      }

      final first = scope();
      final second = scope(identityId: '00000000-0000-4000-8000-000000000003');
      await CustomerLocationStoreEncrypted(records(first, 'location')).write(
        ServiceLocation(
          latitude: 13,
          longitude: 80,
          accuracyMetres: 10,
          capturedAt: DateTime.now().toUtc(),
          label: 'Private home',
        ),
      );
      await CustomerBootstrapCache(records(first, 'bootstrap')).write(
        BootstrapConfig.fromJson({
          ...BootstrapConfig.safeOffline().toJson(),
          'revision': 1,
        }),
      );
      expect(
        await CustomerLocationStoreEncrypted(
          records(second, 'location'),
        ).read(),
        isNull,
      );
      expect(
        await CustomerBootstrapCache(records(second, 'bootstrap')).read(),
        isNull,
      );
      expect(
        (await CustomerLocationStoreEncrypted(
          records(first, 'location'),
        ).read())?.label,
        'Private home',
      );
      expect(
        await CustomerBootstrapCache(records(first, 'bootstrap')).read(),
        isNotNull,
      );
    },
  );
}
