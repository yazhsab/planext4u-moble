import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';

const id = '26aeb279-c481-42e2-bbb8-1853768f1067';
final photo = Uint8List.fromList([1, 2, 3]);
PrivateUploadCheckpoint checkpoint() => PrivateUploadCheckpoint(
  assetId: id,
  purpose: PrivateMediaPurpose.identityDocument,
  contentType: 'image/png',
  sizeBytes: 3,
  sha256: sha256.convert(photo).toString(),
);

void main() {
  test(
    'checkpoint projects immutable integrity metadata and rejects sensitive extras',
    () {
      final document = checkpoint().toJson();
      expect(PrivateUploadCheckpoint.fromJson(document).toJson(), document);
      for (final key in [
        'bytes',
        'upload_url',
        'bank_reference',
        'ocr_status',
        'approved',
      ]) {
        expect(
          () =>
              PrivateUploadCheckpoint.fromJson({...document, key: 'forbidden'}),
          throwsFormatException,
        );
      }
      expect(
        () => PrivateUploadCheckpoint.fromJson({
          ...document,
          'size_bytes': 16 << 20,
        }),
        throwsFormatException,
      );
      expect(
        () => PrivateUploadCheckpoint.fromJson({
          ...document,
          'asset_id': '../other',
        }),
        throwsFormatException,
      );
      expect(
        () => PrivateUploadCheckpoint.fromJson({
          ...document,
          'purpose': 'AVATAR',
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'binary upload waits for a durable checkpoint without storing signed URLs',
    () async {
      final owner = _Backend(),
          saved = Completer<void>(),
          release = Completer<void>();
      PrivateUploadCheckpoint? recorded;
      final pending = _uploader(owner).upload(
        bytes: photo,
        contentType: 'image/png',
        purpose: PrivateMediaPurpose.identityDocument,
        onCheckpoint: (value) async {
          recorded = value;
          saved.complete();
          await release.future;
        },
      );
      await saved.future;
      expect(owner.binaryWrites, 0);
      expect(recorded?.toJson(), checkpoint().toJson());
      expect(jsonEncode(recorded?.toJson()), isNot(contains('signature')));
      release.complete();
      expect(await pending, id);
      expect(owner.binaryWrites, 1);
    },
  );

  test(
    'checkpoint storage failure cannot send untracked document bytes',
    () async {
      final owner = _Backend();
      await expectLater(
        _uploader(owner).upload(
          bytes: photo,
          contentType: 'image/png',
          purpose: PrivateMediaPurpose.identityDocument,
          onCheckpoint: (_) async {
            throw StateError('Synthetic private storage outage');
          },
        ),
        throwsStateError,
      );
      expect(owner.binaryWrites, 0);
      expect(
        owner.requests.where((value) => value.url.path.endsWith('/complete')),
        isEmpty,
      );
    },
  );

  test(
    'account retirement during checkpoint storage prevents the late upload',
    () async {
      final owner = _Backend(),
          saved = Completer<void>(),
          release = Completer<void>();
      final client = _uploader(owner);
      final pending = client.upload(
        bytes: photo,
        contentType: 'image/png',
        purpose: PrivateMediaPurpose.identityDocument,
        onCheckpoint: (_) async {
          saved.complete();
          await release.future;
        },
      );
      await saved.future;
      client.dispose();
      release.complete();
      await expectLater(pending, throwsA(isA<TransportCancelledException>()));
      expect(owner.binaryWrites, 0);
    },
  );

  test(
    'resuming READY revalidates the current owner without reuploading',
    () async {
      final owner = _Backend();
      expect(await _uploader(owner).resume(checkpoint()), id);
      expect(owner.requests.single.method, 'GET');
      expect(
        owner.requests.single.headers['Authorization'],
        'Bearer synthetic-owner',
      );
      expect(owner.binaryWrites, 0);
    },
  );

  test(
    'resuming a pending scan asks the owner to complete and requires READY',
    () async {
      final owner = _Backend(state: 'PENDING_SCAN');
      expect(await _uploader(owner).resume(checkpoint()), id);
      expect(owner.requests.map((value) => value.method), ['GET', 'POST']);
      expect(owner.requests.last.url.path, '/v1/media/$id/complete');
      expect(owner.binaryWrites, 0);
    },
  );

  for (final state in ['DELETED', 'EXPIRED', 'REJECTED']) {
    test('a $state checkpoint is never accepted as usable evidence', () async {
      final owner = _Backend(state: state);
      await expectLater(
        _uploader(owner).resume(checkpoint()),
        throwsA(isA<PrivateMediaRejected>()),
      );
      expect(owner.requests, hasLength(1));
    });
  }

  test(
    'mismatched owner metadata cannot replace the checkpoint content',
    () async {
      final owner = _Backend(mismatch: true);
      await expectLater(
        _uploader(owner).resume(checkpoint()),
        throwsFormatException,
      );
      expect(owner.requests, hasLength(1));
    },
  );

  test(
    'scan and network outages retain a pending reference instead of readiness',
    () async {
      for (final owner in [
        _Backend(state: 'PENDING_SCAN', completeState: 'PENDING_SCAN'),
        _Backend(status: 503),
      ]) {
        await expectLater(
          _uploader(owner).resume(checkpoint()),
          throwsA(
            isA<PrivateMediaPending>().having(
              (value) => value.assetId,
              'same reference',
              id,
            ),
          ),
        );
      }
    },
  );

  test(
    'a foreign owner denial never retries completion or becomes pending',
    () async {
      final owner = _Backend(status: 403);
      await expectLater(
        _uploader(owner).resume(checkpoint()),
        throwsA(isA<ApiAuthorizationFailure>()),
      );
      expect(owner.requests, hasLength(1));
    },
  );

  test(
    'a late resumed owner response is discarded after account retirement',
    () async {
      final owner = _Backend(waitRead: Completer<void>()),
          client = _uploader(_Backend());
      client.dispose();
      await expectLater(
        client.resume(checkpoint()),
        throwsA(isA<TransportCancelledException>()),
      );
      final resumed = _uploader(owner);
      final pending = resumed.resume(checkpoint());
      await owner.readStarted.future;
      resumed.dispose();
      owner.waitRead!.complete();
      await expectLater(pending, throwsA(isA<TransportCancelledException>()));
      expect(owner.requests, hasLength(1));
    },
  );
}

PrivateMediaUploader _uploader(_Backend owner) => PrivateMediaUploader(
  client: ApiClient(
    baseUrl: Uri.parse('https://api.example'),
    transport: owner,
    authSession: const _Session(),
    retryBudget: const ApiRetryBudget(maxAttempts: 1),
  ),
  allowedOrigins: {Uri.parse('https://uploads.example')},
  uploadTransport: owner,
);

final class _Session implements ApiAuthSession {
  const _Session();
  @override
  Future<String?> accessToken() async => 'synthetic-owner';
  @override
  Future<bool> refresh() async => false;
}

final class _Backend implements ApiTransport {
  _Backend({
    this.state = 'READY',
    this.completeState = 'READY',
    this.status = 200,
    this.mismatch = false,
    this.waitRead,
  });
  final String state, completeState;
  final int status;
  final bool mismatch;
  final Completer<void>? waitRead;
  final readStarted = Completer<void>();
  final requests = <TransportRequest>[];
  int binaryWrites = 0;
  @override
  Future<TransportResponse> send(
    TransportRequest request, {
    required Duration timeout,
    required ApiCancellationToken cancellationToken,
  }) async {
    requests.add(request);
    if (request.url.host == 'uploads.example') {
      binaryWrites++;
      return response(200, null);
    }
    if (status != 200) {
      return response(status, {
        'error': {
          'code': 'MEDIA_UNAVAILABLE',
          'message': 'Synthetic media failure',
          'retryable': status == 503,
          'correlation_id': 'synthetic-checkpoint',
          'field_errors': [],
          'details': <String, Object?>{},
        },
      });
    }
    final asset = {
      'id': id,
      'purpose': 'IDENTITY_DOCUMENT',
      'content_type': 'image/png',
      'size_bytes': 3,
      'sha256': mismatch ? '0' * 64 : sha256.convert(photo).toString(),
      'state': state,
    };
    if (request.url.path == '/v1/media/uploads') {
      return response(201, {
        'asset': {...asset, 'state': 'PENDING_UPLOAD'},
        'upload_url': 'https://uploads.example/$id?signature=synthetic',
        'expires_at': DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 10))
            .toIso8601String(),
        'headers': {
          'content-type': 'image/png',
          'x-amz-checksum-sha256': base64Encode(sha256.convert(photo).bytes),
          'x-amz-meta-sha256': sha256.convert(photo).toString(),
          'if-none-match': '*',
        },
      });
    }
    if (request.method == 'GET') {
      if (!readStarted.isCompleted) readStarted.complete();
      await waitRead?.future;
      return response(200, asset);
    }
    return response(200, {...asset, 'state': completeState});
  }
}

TransportResponse response(int status, Object? value) => TransportResponse(
  statusCode: status,
  headers: const {'content-type': 'application/json'},
  body: Uint8List.fromList(value == null ? [] : utf8.encode(jsonEncode(value))),
);
