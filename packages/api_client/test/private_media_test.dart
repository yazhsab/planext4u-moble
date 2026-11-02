import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';

const assetId = 'c9d868de-7c48-48fc-9c6c-b988b5151654';
final now = DateTime.utc(2026, 10, 25);
final bytes = Uint8List.fromList([1, 2, 3, 4]);

void main() {
  test(
    'private upload sends exact frozen bytes without API authorization and awaits READY',
    () async {
      final api = _OwnerTransport();
      final binary = _BinaryTransport();
      final uploader = _uploader(api, binary);
      expect(
        await uploader.upload(
          bytes: bytes,
          contentType: 'image/png',
          purpose: PrivateMediaPurpose.identityDocument,
        ),
        assetId,
      );
      expect(binary.sent.single.headers.containsKey('Authorization'), false);
      expect(binary.copy, bytes);
      expect(binary.sent.single.url.host, 'uploads.example');
      expect(binary.sent.single.headers['if-none-match'], '*');
      expect(api.sent.length, 2);
      expect(
        api.sent.every(
          (request) =>
              request.headers['Authorization'] ==
              'Bearer synthetic-owner-access',
        ),
        true,
      );
      expect(api.sent.last.url.path, '/v1/media/$assetId/complete');
      expect(bytes, [1, 2, 3, 4]);
    },
  );

  for (final state in [
    'REJECTED',
    'PENDING_SCAN',
    'PENDING_UPLOAD',
    'DELETED',
  ]) {
    test('$state cannot become usable private evidence', () async {
      final uploader = _uploader(
        _OwnerTransport(completedState: state),
        _BinaryTransport(),
      );
      await expectLater(
        uploader.upload(
          bytes: bytes,
          contentType: 'image/png',
          purpose: PrivateMediaPurpose.identityDocument,
        ),
        throwsA(
          state == 'PENDING_SCAN'
              ? isA<PrivateMediaPending>()
              : isA<PrivateMediaRejected>(),
        ),
      );
    });
  }

  for (final mutate in <void Function(Map<String, Object?>)>[
    (grant) => grant['upload_url'] =
        'https://other.example/private/$assetId?signature=private',
    (grant) => grant['upload_url'] = 'http://uploads.example/private/$assetId',
    (grant) => grant['upload_url'] =
        'https://user:secret@uploads.example/private/$assetId',
    (grant) =>
        grant['upload_url'] = 'https://uploads.example/private/another-asset',
    (grant) => grant['expires_at'] = now
        .subtract(const Duration(seconds: 1))
        .toIso8601String(),
    (grant) => (grant['headers']! as Map<String, Object?>)['Authorization'] =
        'Bearer stolen',
    (grant) =>
        (grant['headers']! as Map<String, Object?>)['if-none-match'] = '',
    (grant) =>
        (grant['headers']! as Map<String, Object?>)['x-amz-meta-sha256'] =
            'forged',
    (grant) => (grant['asset']! as Map<String, Object?>)['purpose'] = 'AVATAR',
  ]) {
    test('invalid grant cannot send document bytes', () async {
      final binary = _BinaryTransport();
      final uploader = _uploader(_OwnerTransport(mutate: mutate), binary);
      await expectLater(
        uploader.upload(
          bytes: bytes,
          contentType: 'image/png',
          purpose: PrivateMediaPurpose.identityDocument,
        ),
        throwsFormatException,
      );
      expect(binary.sent, isEmpty);
    });
  }

  test(
    'redirect response never triggers completion or another upload',
    () async {
      final api = _OwnerTransport();
      final binary = _BinaryTransport(status: 307);
      await expectLater(
        _uploader(api, binary).upload(
          bytes: bytes,
          contentType: 'image/png',
          purpose: PrivateMediaPurpose.identityDocument,
        ),
        throwsA(isA<PrivateMediaRejected>()),
      );
      expect(api.sent.length, 1);
      expect(binary.sent.length, 1);
    },
  );

  test(
    'account cancellation after signed PUT cannot complete or publish evidence',
    () async {
      final token = ApiCancellationToken();
      final api = _OwnerTransport();
      final binary = _BinaryTransport(afterPut: token.cancel);
      await expectLater(
        _uploader(api, binary).upload(
          bytes: bytes,
          contentType: 'image/png',
          purpose: PrivateMediaPurpose.identityDocument,
          cancellationToken: token,
        ),
        throwsA(isA<TransportCancelledException>()),
      );
      expect(api.sent.length, 1);
    },
  );

  test(
    'scanner dependency failure preserves a retryable opaque pending reference',
    () async {
      final api = _OwnerTransport(unavailable: true);
      await expectLater(
        _uploader(api, _BinaryTransport()).upload(
          bytes: bytes,
          contentType: 'image/png',
          purpose: PrivateMediaPurpose.identityDocument,
        ),
        throwsA(
          isA<PrivateMediaPending>().having(
            (value) => value.assetId,
            'asset',
            assetId,
          ),
        ),
      );
    },
  );

  test(
    'private upload origins must be explicit and HTTPS outside local development',
    () {
      final client = ApiClient(
        baseUrl: Uri.parse('https://api.example'),
        transport: _OwnerTransport(),
      );
      for (final origin in [
        'http://127.0.0.1:9000',
        'http://uploads.example',
        'https://uploads.example/path',
        'https://user:pass@uploads.example',
      ]) {
        expect(
          () => PrivateMediaUploader(
            client: client,
            allowedOrigins: {Uri.parse(origin)},
          ),
          throwsFormatException,
        );
      }
      expect(
        () => PrivateMediaUploader(
          client: client,
          allowedOrigins: {Uri.parse('http://remote.example')},
          allowDevelopmentHttp: true,
        ),
        throwsFormatException,
      );
      expect(
        PrivateMediaUploader(
          client: client,
          allowedOrigins: {Uri.parse('http://127.0.0.1:9000')},
          allowDevelopmentHttp: true,
        ),
        isNotNull,
      );
    },
  );
}

PrivateMediaUploader _uploader(
  _OwnerTransport owner,
  _BinaryTransport binary,
) => PrivateMediaUploader(
  client: ApiClient(
    baseUrl: Uri.parse('https://api.example'),
    transport: owner,
    authSession: const _Session(),
    retryBudget: const ApiRetryBudget(maxAttempts: 1),
  ),
  allowedOrigins: {Uri.parse('https://uploads.example')},
  uploadTransport: binary,
  clock: () => now,
);

final class _Session implements ApiAuthSession {
  const _Session();
  @override
  Future<String?> accessToken() async => 'synthetic-owner-access';
  @override
  Future<bool> refresh() async => false;
}

final class _OwnerTransport implements ApiTransport {
  _OwnerTransport({
    this.completedState = 'READY',
    this.mutate,
    this.unavailable = false,
  });
  final String completedState;
  final void Function(Map<String, Object?>)? mutate;
  final bool unavailable;
  final sent = <TransportRequest>[];
  @override
  Future<TransportResponse> send(
    TransportRequest request, {
    required Duration timeout,
    required ApiCancellationToken cancellationToken,
  }) async {
    sent.add(request);
    final checksum = sha256.convert(bytes);
    final asset = <String, Object?>{
      'id': assetId,
      'purpose': 'IDENTITY_DOCUMENT',
      'content_type': 'image/png',
      'size_bytes': bytes.length,
      'sha256': checksum.toString(),
      'state': 'PENDING_UPLOAD',
    };
    if (sent.length == 1) {
      final grant = <String, Object?>{
        'asset': asset,
        'upload_url':
            'https://uploads.example/private/$assetId?signature=private',
        'expires_at': now.add(const Duration(minutes: 10)).toIso8601String(),
        'headers': <String, Object?>{
          'content-type': 'image/png',
          'x-amz-checksum-sha256': base64Encode(checksum.bytes),
          'x-amz-meta-sha256': checksum.toString(),
          'if-none-match': '*',
        },
      };
      mutate?.call(grant);
      return _json(201, grant);
    }
    if (unavailable) {
      return _json(503, {
        'error': {
          'code': 'MEDIA_DEPENDENCY_UNAVAILABLE',
          'message': 'Scanner is unavailable',
          'retryable': true,
          'correlation_id': request.headers['X-Correlation-ID'],
          'field_errors': [],
          'details': <String, Object?>{},
        },
      });
    }
    return _json(200, {...asset, 'state': completedState});
  }
}

final class _BinaryTransport implements ApiTransport {
  _BinaryTransport({this.status = 200, this.afterPut});
  final int status;
  final void Function()? afterPut;
  final sent = <TransportRequest>[];
  Uint8List? copy;
  @override
  Future<TransportResponse> send(
    TransportRequest request, {
    required Duration timeout,
    required ApiCancellationToken cancellationToken,
  }) async {
    sent.add(request);
    copy = Uint8List.fromList(request.body!);
    afterPut?.call();
    return TransportResponse(
      statusCode: status,
      headers: const {},
      body: Uint8List(0),
    );
  }
}

TransportResponse _json(int status, Object value) => TransportResponse(
  statusCode: status,
  headers: const {'content-type': 'application/json'},
  body: Uint8List.fromList(utf8.encode(jsonEncode(value))),
);
