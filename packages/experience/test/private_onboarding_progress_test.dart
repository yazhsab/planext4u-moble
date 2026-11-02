import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_experience/planext4u_experience.dart';
import 'package:planext4u_storage/planext4u_storage.dart';

PrivateUploadCheckpoint _upload(int suffix) => PrivateUploadCheckpoint(
  assetId: '00000000-0000-4000-8000-${suffix.toString().padLeft(12, '0')}',
  purpose: PrivateMediaPurpose.identityDocument,
  contentType: 'image/png',
  sizeBytes: 3,
  sha256: 'a' * 64,
);
PrivateOnboardingProgress _vendor() => PrivateOnboardingProgress(
  workflow: 'VENDOR',
  documents: {
    'OWNER_IDENTITY': _upload(1),
    'BUSINESS_REGISTRATION': _upload(2),
  },
);

void main() {
  test(
    'reference journal encrypts, reconstructs, isolates every account dimension and expires',
    () async {
      var now = DateTime.utc(2026, 10, 26);
      final records = MemoryBinaryRecordStore(),
          keys = MemoryCacheKeyProvider();
      EncryptedPrivateOnboardingProgressStore open({
        String tenant = 'tenant-a',
        String country = 'IN',
        String identity = 'owner-a',
        String role = 'vendor',
      }) => EncryptedPrivateOnboardingProgressStore(
        tenantId: tenant,
        country: country,
        identityId: identity,
        applicationRole: role,
        store: EncryptedRecordStore(
          records: records,
          keyProvider: keys,
          namespace: 'private-progress-test',
          clock: () => now,
        ),
        clock: () => now,
      );
      await open().write(_vendor());
      expect((await open().read())?.assetIds, _vendor().assetIds);
      final encrypted = await records.read(open().scopeKey);
      expect(encrypted, isNotNull);
      expect(utf8.decode(encrypted!), isNot(contains(_upload(1).assetId)));
      expect(await open(tenant: 'tenant-b').read(), isNull);
      expect(await open(country: 'NG').read(), isNull);
      expect(await open(identity: 'owner-b').read(), isNull);
      expect(await open(role: 'rider').read(), isNull);
      now = now.add(const Duration(days: 7));
      expect(await open().read(), isNull);
    },
  );

  test(
    'malformed, raw, bank, consent and approval fields cannot enter progress',
    () {
      final document = _vendor().toJson();
      expect(PrivateOnboardingProgress.fromJson(document).toJson(), document);
      for (final field in [
        'bytes',
        'bank_reference',
        'consent',
        'approved',
        'upload_url',
      ]) {
        expect(
          () => PrivateOnboardingProgress.fromJson({
            ...document,
            field: 'forbidden',
          }),
          throwsFormatException,
        );
      }
      expect(
        () => PrivateOnboardingProgress(
          workflow: 'VENDOR',
          documents: {'OWNER_IDENTITY': _upload(1)},
          submissionStarted: true,
        ),
        throwsFormatException,
      );
      expect(
        () => PrivateOnboardingProgress(
          workflow: 'VENDOR',
          documents: {
            'OWNER_IDENTITY': _upload(1),
            'BUSINESS_REGISTRATION': _upload(1),
          },
        ),
        throwsFormatException,
      );
      expect(
        () => PrivateOnboardingProgress(
          workflow: 'RIDER_BICYCLE',
          documents: {'BUSINESS_REGISTRATION': _upload(1)},
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'queued clearing follows an issued write from another journal instance',
    () async {
      final records = MemoryBinaryRecordStore(),
          keys = MemoryCacheKeyProvider();
      EncryptedPrivateOnboardingProgressStore open() =>
          EncryptedPrivateOnboardingProgressStore(
            tenantId: 'tenant-a',
            country: 'IN',
            identityId: 'owner-a',
            applicationRole: 'vendor',
            store: EncryptedRecordStore(records: records, keyProvider: keys),
          );
      final saving = open().write(_vendor()), clearing = open().clear();
      await saving;
      await clearing;
      expect(await open().read(), isNull);
    },
  );

  test(
    'corrupt progress fails closed and role-mismatched writes are rejected',
    () async {
      final records = MemoryBinaryRecordStore(),
          keys = MemoryCacheKeyProvider();
      final store = EncryptedPrivateOnboardingProgressStore(
        tenantId: 'tenant-a',
        country: 'IN',
        identityId: 'owner-a',
        applicationRole: 'rider',
        store: EncryptedRecordStore(records: records, keyProvider: keys),
      );
      expect(() => store.write(_vendor()), throwsFormatException);
      await store.write(
        PrivateOnboardingProgress(
          workflow: 'RIDER_BICYCLE',
          documents: {'IDENTITY': _upload(1)},
        ),
      );
      records.corrupt(store.scopeKey);
      await expectLater(store.read(), throwsStateError);
      await store.clear();
      expect(await store.read(), isNull);
    },
  );
}
