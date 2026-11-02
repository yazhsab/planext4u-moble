import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_experience/planext4u_experience.dart';
import 'package:planext4u_storage/planext4u_storage.dart';

void main() {
  test(
    'form survives new instances, isolates scope, encrypts and expires',
    () async {
      var now = DateTime.utc(2026, 10, 25);
      final records = MemoryBinaryRecordStore();
      final keys = MemoryCacheKeyProvider();
      final encrypted = EncryptedRecordStore(
        records: records,
        keyProvider: keys,
        namespace: 'onboarding-test',
        clock: () => now,
      );
      EncryptedRiderOnboardingProgressStore store(
        String tenant,
        String country,
        String identity,
      ) => EncryptedRiderOnboardingProgressStore(
        tenantId: tenant,
        country: country,
        identityId: identity,
        store: encrypted,
        clock: () => now,
      );
      await store('tenant-a', 'IN', 'rider-a').save(
        const RiderOnboardingProgress(
          fullName: 'Private Rider',
          vehicleNumber: 'TN01AB1234',
          postalCodes: '600001',
        ),
      );
      final restored = await store('tenant-a', 'IN', 'rider-a').read();
      expect(restored?.fullName, 'Private Rider');
      expect(restored?.vehicleNumber, 'TN01AB1234');
      expect(await store('tenant-b', 'IN', 'rider-a').read(), isNull);
      expect(await store('tenant-a', 'SG', 'rider-a').read(), isNull);
      expect(await store('tenant-a', 'IN', 'rider-b').read(), isNull);
      now = now.add(const Duration(days: 7));
      expect(await store('tenant-a', 'IN', 'rider-a').read(), isNull);
    },
  );

  test(
    'queued clear follows outstanding writes from another instance',
    () async {
      final records = MemoryBinaryRecordStore();
      final encrypted = EncryptedRecordStore(
        records: records,
        keyProvider: MemoryCacheKeyProvider(),
      );
      EncryptedRiderOnboardingProgressStore create() =>
          EncryptedRiderOnboardingProgressStore(
            tenantId: 'tenant-a',
            country: 'IN',
            identityId: 'rider-a',
            store: encrypted,
          );
      final saving = create().save(
        const RiderOnboardingProgress(fullName: 'Will be cleared'),
      );
      final clearing = create().clear();
      await saving;
      await clearing;
      expect(await create().read(), isNull);
    },
  );

  test(
    'raw evidence, bank data and stored consent cannot enter form schema',
    () {
      final payload = const RiderOnboardingProgress(fullName: 'Rider').toJson();
      expect(jsonEncode(payload), isNot(contains('bank')));
      for (final forbidden in [
        'documents',
        'bank_reference',
        'account_number',
        'duty_location_consent',
      ]) {
        expect(
          () => RiderOnboardingProgress.fromJson({
            ...payload,
            forbidden: 'restricted',
          }),
          throwsFormatException,
        );
      }
      expect(
        () => RiderOnboardingProgress(fullName: 'x' * 121).toJson(),
        throwsFormatException,
      );
      expect(
        () => const RiderOnboardingProgress(vehicleType: 'PLANE').toJson(),
        throwsFormatException,
      );
    },
  );

  test(
    'rework form scope survives serialization and rejects malformed scope',
    () {
      final saved = const RiderOnboardingProgress(
        fullName: 'Corrected rider',
        vehicleType: 'BICYCLE',
        applicationId: 'rider-review-1',
        applicationRevision: 7,
      ).toJson();
      final restored = RiderOnboardingProgress.fromJson(saved);
      expect(restored.applicationId, 'rider-review-1');
      expect(restored.applicationRevision, 7);
      expect(
        () => RiderOnboardingProgress.fromJson({
          ...saved,
          'application_revision': -1,
        }),
        throwsFormatException,
      );
      expect(
        () => const RiderOnboardingProgress(
          applicationId: 'rider-review-1',
        ).toJson(),
        throwsFormatException,
      );
      final legacy = RiderOnboardingProgress.fromJson({
        'schema': 1,
        'full_name': 'Earlier draft',
        'vehicle_type': 'BICYCLE',
        'vehicle_number': 'CYC123',
        'postal_codes': '600001',
      });
      expect(legacy.applicationId, isEmpty);
      expect(legacy.applicationRevision, 0);
    },
  );

  test(
    'vendor form is encrypted, account scoped and expires after seven days',
    () async {
      var now = DateTime.utc(2026, 10, 25);
      final encrypted = EncryptedRecordStore(
        records: MemoryBinaryRecordStore(),
        keyProvider: MemoryCacheKeyProvider(),
        namespace: 'vendor-onboarding-test',
        clock: () => now,
      );
      EncryptedVendorOnboardingProgressStore store(String identity) =>
          EncryptedVendorOnboardingProgressStore(
            tenantId: 'tenant-a',
            country: 'IN',
            identityId: identity,
            store: encrypted,
            clock: () => now,
          );
      await store('vendor-a').save(
        const VendorOnboardingProgress(
          businessName: 'Updated store',
          businessType: 'Retail store',
          contactName: 'Updated owner',
          applicationId: 'application-1',
          applicationRevision: 4,
        ),
      );
      expect((await store('vendor-a').read())?.contactName, 'Updated owner');
      expect(await store('vendor-b').read(), isNull);
      now = now.add(const Duration(days: 7));
      expect(await store('vendor-a').read(), isNull);
    },
  );

  test('vendor form rejects bank, private evidence and malformed scope', () {
    final payload = const VendorOnboardingProgress().toJson();
    expect(jsonEncode(payload), isNot(contains('bank')));
    for (final forbidden in ['bank_reference', 'documents', 'ocr_status']) {
      expect(
        () => VendorOnboardingProgress.fromJson({
          ...payload,
          forbidden: 'private-value',
        }),
        throwsFormatException,
      );
    }
    expect(
      () => const VendorOnboardingProgress(
        applicationId: 'application-1',
      ).toJson(),
      throwsFormatException,
    );
  });
}
