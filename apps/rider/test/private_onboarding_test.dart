import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_experience/planext4u_experience.dart';
import 'package:planext4u_storage/planext4u_storage.dart';
import 'package:planext4u_rider/private_onboarding.dart';

void main() {
  test(
    'configured rider bank flow returns only reference and rejects old account completion',
    () async {
      final backend = _MediaBackend(), uploader = _uploader(backend);
      final bank = HostedBankLinkClient(
        client: ApiClient(
          baseUrl: Uri.parse('https://api.example'),
          transport: backend,
        ),
        applicationRole: 'rider',
        allowedOrigins: {Uri.parse('https://bank.example')},
      );
      const proof = VerifiedBankAccount(
        reference: 'bankref_synthetic1234',
        holderName: 'Synthetic Owner',
        last4: '1234',
        ifsc: 'TEST0123456',
      );
      final provider = NativeRiderOnboardingProvider(
        uploader: uploader,
        capture: (_) async => null,
        bankLinks: bank,
        verifyBank: () async => proof,
      );
      expect(provider.canTokenizeBankAccount, isTrue);
      expect(await provider.tokenizeBankAccount(), 'bankref_synthetic1234');
      final gate = Completer<VerifiedBankAccount?>();
      final retired = NativeRiderOnboardingProvider(
        uploader: uploader,
        capture: (_) async => null,
        bankLinks: bank,
        verifyBank: () => gate.future,
      );
      final pending = retired.tokenizeBankAccount();
      bank.dispose();
      gate.complete(proof);
      await expectLater(pending, throwsA(isA<TransportCancelledException>()));
      expect(retired.canTokenizeBankAccount, isFalse);
      expect(backend.uploads, 0);
    },
  );
  test(
    'motor vehicles collect four private references, clear bytes, and never infer OCR approval',
    () async {
      final backend = _MediaBackend();
      final buffers = <Uint8List>[];
      final kinds = <String>[];
      final provider = NativeRiderOnboardingProvider(
        uploader: _uploader(backend),
        capture: (kind) async {
          kinds.add(kind);
          final bytes = Uint8List.fromList([1, 2, 3]);
          buffers.add(bytes);
          return RiderDocumentPhoto(bytes, 'image/png');
        },
      );
      final documents = await provider.collectDocuments(
        vehicleType: 'MOTORBIKE',
      );
      expect(kinds, [
        'IDENTITY',
        'DRIVER_LICENSE',
        'VEHICLE_REGISTRATION',
        'INSURANCE',
      ]);
      expect(documents, hasLength(4));
      expect(
        documents.every((value) => value.toJson()['ocr_status'] == 'PENDING'),
        true,
      );
      expect(buffers.every((value) => value.every((byte) => byte == 0)), true);
      expect(provider.canTokenizeBankAccount, false);
      await expectLater(provider.tokenizeBankAccount(), throwsStateError);
    },
  );
  test(
    'bicycle requires identity only and unsupported vehicle never invokes camera',
    () async {
      final backend = _MediaBackend();
      var captures = 0;
      final provider = NativeRiderOnboardingProvider(
        uploader: _uploader(backend),
        capture: (_) async {
          ++captures;
          return RiderDocumentPhoto(Uint8List.fromList([1]), 'image/png');
        },
      );
      expect(
        await provider.collectDocuments(vehicleType: 'BICYCLE'),
        hasLength(1),
      );
      await expectLater(
        provider.collectDocuments(vehicleType: 'PLANE'),
        throwsFormatException,
      );
      expect(captures, 1);
    },
  );
  test(
    'cancelled multi-document capture discards only already uploaded unsubmitted references',
    () async {
      final backend = _MediaBackend();
      final provider = NativeRiderOnboardingProvider(
        uploader: _uploader(backend),
        capture: (kind) async => kind == 'IDENTITY'
            ? RiderDocumentPhoto(Uint8List.fromList([1]), 'image/png')
            : null,
      );
      await expectLater(
        provider.collectDocuments(vehicleType: 'CAR'),
        throwsA(isA<TransportCancelledException>()),
      );
      expect(backend.uploads, 1);
      expect(backend.deleted, backend.assets.keys.toList());
    },
  );
  test(
    'account retirement during native capture discards its late bytes without uploading',
    () async {
      final backend = _MediaBackend();
      final uploader = _uploader(backend);
      final captured = Completer<RiderDocumentPhoto?>();
      final provider = NativeRiderOnboardingProvider(
        uploader: uploader,
        capture: (_) => captured.future,
      );
      final pending = provider.collectDocuments(vehicleType: 'VAN');
      uploader.dispose();
      final bytes = Uint8List.fromList([8, 9]);
      captured.complete(RiderDocumentPhoto(bytes, 'image/png'));
      await expectLater(pending, throwsA(isA<TransportCancelledException>()));
      expect(bytes, [0, 0]);
      expect(backend.assets, isEmpty);
      expect(provider.canCollectDocuments, false);
    },
  );
  test(
    'legacy combined collection stops before camera when bank adapter is unavailable',
    () async {
      final backend = _MediaBackend();
      var captures = 0;
      final provider = NativeRiderOnboardingProvider(
        uploader: _uploader(backend),
        capture: (_) async {
          ++captures;
          return null;
        },
      );
      await expectLater(
        provider.collectEvidence(vehicleType: 'MOTORBIKE'),
        throwsStateError,
      );
      expect(captures, 0);
      expect(backend.assets, isEmpty);
    },
  );
  test(
    'interrupted document collection resumes verified references after reconstructing the normal provider',
    () async {
      final backend = _MediaBackend(),
          records = MemoryBinaryRecordStore(),
          keys = MemoryCacheKeyProvider();
      PrivateOnboardingProgressStore journal() =>
          EncryptedPrivateOnboardingProgressStore(
            tenantId: 'tenant-a',
            country: 'IN',
            identityId: 'rider-a',
            applicationRole: 'rider',
            store: EncryptedRecordStore(
              records: records,
              keyProvider: keys,
              namespace: 'native-rider-progress-test',
            ),
          );
      final first = NativeRiderOnboardingProvider(
        uploader: _uploader(backend),
        progress: journal(),
        capture: (kind) async => kind == 'IDENTITY'
            ? RiderDocumentPhoto(Uint8List.fromList([1]), 'image/png')
            : null,
      );
      await expectLater(
        first.collectDocuments(vehicleType: 'MOTORBIKE'),
        throwsA(isA<TransportCancelledException>()),
      );
      expect(backend.uploads, 1);
      expect(backend.deleted, isEmpty);
      expect((await journal().read())?.documents.keys, ['IDENTITY']);
      final captured = <String>[];
      final resumed = NativeRiderOnboardingProvider(
        uploader: _uploader(backend),
        progress: journal(),
        capture: (kind) async {
          captured.add(kind);
          return RiderDocumentPhoto(Uint8List.fromList([1]), 'image/png');
        },
      );
      final documents = await resumed.collectDocuments(
        vehicleType: 'MOTORBIKE',
      );
      expect(captured, ['DRIVER_LICENSE', 'VEHICLE_REGISTRATION', 'INSURANCE']);
      expect(documents, hasLength(4));
      expect(backend.uploads, 4);
      final ids = documents.map((value) => value.assetId).toSet();
      await resumed.prepareDocumentSubmission(ids);
      expect((await journal().read())?.submissionStarted, true);
      await expectLater(
        resumed.collectDocuments(vehicleType: 'MOTORBIKE'),
        throwsStateError,
      );
      await resumed.discardSavedDocuments();
      expect(await journal().read(), isNull);
      expect(
        backend.deleted,
        isEmpty,
        reason:
            'A possibly submitted application may already retain the evidence.',
      );
    },
  );

  test(
    'changing vehicle cannot reuse an incompatible journal and explicit clearing removes unsubmitted references',
    () async {
      final backend = _MediaBackend(),
          records = MemoryBinaryRecordStore(),
          keys = MemoryCacheKeyProvider();
      final journal = EncryptedPrivateOnboardingProgressStore(
        tenantId: 'tenant-a',
        country: 'IN',
        identityId: 'rider-a',
        applicationRole: 'rider',
        store: EncryptedRecordStore(records: records, keyProvider: keys),
      );
      final provider = NativeRiderOnboardingProvider(
        uploader: _uploader(backend),
        progress: journal,
        capture: (kind) async => kind == 'IDENTITY'
            ? RiderDocumentPhoto(Uint8List.fromList([1]), 'image/png')
            : null,
      );
      await expectLater(
        provider.collectDocuments(vehicleType: 'CAR'),
        throwsA(isA<TransportCancelledException>()),
      );
      final previous = (await journal.read())!.assetIds.single;
      await expectLater(
        provider.collectDocuments(vehicleType: 'BICYCLE'),
        throwsStateError,
      );
      expect(backend.uploads, 1);
      await provider.discardSavedDocuments();
      expect(backend.deleted, [previous]);
      expect(await journal.read(), isNull);
      final bicycle = await provider.collectDocuments(vehicleType: 'BICYCLE');
      expect(bicycle, hasLength(1));
      expect(bicycle.single.assetId, isNot(previous));
      await expectLater(
        provider.prepareDocumentSubmission({previous}),
        throwsStateError,
      );
      expect((await journal.read())?.submissionStarted, false);
    },
  );
}

PrivateMediaUploader _uploader(_MediaBackend backend) => PrivateMediaUploader(
  client: ApiClient(
    baseUrl: Uri.parse('https://api.example'),
    transport: backend,
    authSession: const _Session(),
  ),
  allowedOrigins: {Uri.parse('https://uploads.example')},
  uploadTransport: backend,
);

final class _Session implements ApiAuthSession {
  const _Session();
  @override
  Future<String?> accessToken() async => 'synthetic-owner-access';
  @override
  Future<bool> refresh() async => false;
}

final class _MediaBackend implements ApiTransport {
  final assets = <String, Map<String, Object?>>{};
  final deleted = <String>[];
  int uploads = 0;
  @override
  Future<TransportResponse> send(
    TransportRequest request, {
    required Duration timeout,
    required ApiCancellationToken cancellationToken,
  }) async {
    if (request.url.host == 'uploads.example') {
      expect(request.headers.containsKey('Authorization'), false);
      uploads++;
      return _response(200, null);
    }
    if (request.url.path == '/v1/media/uploads') {
      final id =
          '00000000-0000-4000-8000-${(assets.length + 1).toString().padLeft(12, '0')}';
      final metadata =
          jsonDecode(utf8.decode(request.body!)) as Map<String, Object?>;
      final asset = <String, Object?>{
        ...metadata,
        'id': id,
        'state': 'PENDING_UPLOAD',
      };
      assets[id] = asset;
      return _response(201, {
        'asset': asset,
        'upload_url': 'https://uploads.example/$id?signature=synthetic',
        'expires_at': DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 10))
            .toIso8601String(),
        'headers': {
          'content-type': metadata['content_type'],
          'x-amz-checksum-sha256': base64Encode(
            _hex(metadata['sha256']! as String),
          ),
          'x-amz-meta-sha256': metadata['sha256'],
          'if-none-match': '*',
        },
      });
    }
    final id = request.url.pathSegments[2];
    if (request.method == 'DELETE') {
      deleted.add(id);
      return _response(204, null);
    }
    return _response(200, {...assets[id]!, 'state': 'READY'});
  }
}

List<int> _hex(String value) => [
  for (var index = 0; index < value.length; index += 2)
    int.parse(value.substring(index, index + 2), radix: 16),
];
TransportResponse _response(int status, Object? data) => TransportResponse(
  statusCode: status,
  headers: const {'content-type': 'application/json'},
  body: Uint8List.fromList(data == null ? [] : utf8.encode(jsonEncode(data))),
);
