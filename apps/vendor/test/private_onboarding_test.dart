import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_experience/planext4u_experience.dart';
import 'package:planext4u_storage/planext4u_storage.dart';
import 'package:planext4u_vendor/private_onboarding.dart';

void main() {
  test(
    'configured vendor bank flow maps masked proof and rejects old account completion',
    () async {
      final backend = _MediaBackend(), uploader = _uploader(backend);
      final bank = HostedBankLinkClient(
        client: ApiClient(
          baseUrl: Uri.parse('https://api.example'),
          transport: backend,
        ),
        applicationRole: 'vendor',
        allowedOrigins: {Uri.parse('https://bank.example')},
      );
      const proof = VerifiedBankAccount(
        reference: 'bankref_synthetic1234',
        holderName: 'Synthetic Owner',
        last4: '1234',
        ifsc: 'TEST0123456',
      );
      final provider = NativeVendorOnboardingProvider(
        uploader: uploader,
        capture: (_) async => null,
        bankLinks: bank,
        verifyBank: () async => proof,
      );
      expect(provider.canTokenizeBankAccount, isTrue);
      expect((await provider.tokenizeBankAccount()).toJson(), {
        'reference': 'bankref_synthetic1234',
        'holder_name': 'Synthetic Owner',
        'last4': '1234',
        'ifsc': 'TEST0123456',
      });
      final gate = Completer<VerifiedBankAccount?>();
      final retired = NativeVendorOnboardingProvider(
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
    'normal private document collection returns scanned references and clears capture buffers',
    () async {
      final backend = _MediaBackend();
      final captures = <Uint8List>[];
      final kinds = <String>[];
      final provider = NativeVendorOnboardingProvider(
        uploader: _uploader(backend),
        capture: (kind) async {
          kinds.add(kind);
          final bytes = Uint8List.fromList([1, 2, 3]);
          captures.add(bytes);
          return VendorDocumentPhoto(bytes, 'image/png');
        },
      );
      final documents = await provider.collectDocuments();
      expect(kinds, ['OWNER_IDENTITY', 'BUSINESS_REGISTRATION']);
      expect(documents.map((document) => document.assetId).toSet().length, 2);
      expect(captures.every((bytes) => bytes.every((byte) => byte == 0)), true);
      expect(backend.uploads, 2);
      expect(provider.canTokenizeBankAccount, false);
      await expectLater(provider.tokenizeBankAccount(), throwsStateError);
    },
  );

  test(
    'cancelling the second photo discards only the first unsubmitted upload',
    () async {
      final backend = _MediaBackend();
      final provider = NativeVendorOnboardingProvider(
        uploader: _uploader(backend),
        capture: (kind) async => kind == 'OWNER_IDENTITY'
            ? VendorDocumentPhoto(Uint8List.fromList([1, 2]), 'image/png')
            : null,
      );
      await expectLater(
        provider.collectDocuments(),
        throwsA(isA<TransportCancelledException>()),
      );
      expect(backend.uploads, 1);
      expect(backend.deleted, backend.assets.keys.toList());
    },
  );

  test(
    'account loss during camera capture cannot upload the late result',
    () async {
      final backend = _MediaBackend();
      final uploader = _uploader(backend);
      final capture = Completer<VendorDocumentPhoto?>();
      final provider = NativeVendorOnboardingProvider(
        uploader: uploader,
        capture: (_) => capture.future,
      );
      final operation = provider.collectDocuments();
      uploader.dispose();
      final bytes = Uint8List.fromList([7, 8]);
      capture.complete(VendorDocumentPhoto(bytes, 'image/png'));
      await expectLater(operation, throwsA(isA<TransportCancelledException>()));
      expect(backend.assets, isEmpty);
      expect(bytes, [0, 0]);
    },
  );
  test(
    'the normal provider resumes the remaining vendor photo and forgets only confirmed submission progress',
    () async {
      final backend = _MediaBackend(),
          records = MemoryBinaryRecordStore(),
          keys = MemoryCacheKeyProvider();
      PrivateOnboardingProgressStore journal() =>
          EncryptedPrivateOnboardingProgressStore(
            tenantId: 'tenant-a',
            country: 'IN',
            identityId: 'vendor-a',
            applicationRole: 'vendor',
            store: EncryptedRecordStore(
              records: records,
              keyProvider: keys,
              namespace: 'native-vendor-progress-test',
            ),
          );
      final first = NativeVendorOnboardingProvider(
        uploader: _uploader(backend),
        progress: journal(),
        capture: (kind) async => kind == 'OWNER_IDENTITY'
            ? VendorDocumentPhoto(Uint8List.fromList([1, 2]), 'image/png')
            : null,
      );
      await expectLater(
        first.collectDocuments(),
        throwsA(isA<TransportCancelledException>()),
      );
      expect(backend.uploads, 1);
      expect(backend.deleted, isEmpty);
      final kinds = <String>[];
      final resumed = NativeVendorOnboardingProvider(
        uploader: _uploader(backend),
        progress: journal(),
        capture: (kind) async {
          kinds.add(kind);
          return VendorDocumentPhoto(Uint8List.fromList([1, 2]), 'image/png');
        },
      );
      final documents = await resumed.collectDocuments();
      expect(kinds, ['BUSINESS_REGISTRATION']);
      expect(documents, hasLength(2));
      expect(backend.uploads, 2);
      final ids = documents.map((value) => value.assetId).toSet();
      await resumed.prepareDocumentSubmission(ids);
      expect((await journal().read())?.submissionStarted, true);
      await resumed.forgetSubmittedDocuments(ids);
      expect(await journal().read(), isNull);
      expect(backend.deleted, isEmpty);
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
