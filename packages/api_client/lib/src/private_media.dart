import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'cancellation.dart';
import 'client.dart';
import 'failures.dart';
import 'request.dart';
import 'transport.dart';

enum PrivateMediaPurpose {
  identityDocument('IDENTITY_DOCUMENT'),
  completionProof('COMPLETION_PROOF');

  const PrivateMediaPurpose(this.wireValue);
  final String wireValue;
}

/// A scoped owner's immutable upload reference and integrity metadata. This
/// contains no bytes, signed URL, OCR result, bank data or approval decision.
final class PrivateUploadCheckpoint {
  PrivateUploadCheckpoint({
    required this.assetId,
    required this.purpose,
    required this.contentType,
    required this.sizeBytes,
    required this.sha256,
  }) {
    if (!PrivateMediaUploader._uuid.hasMatch(assetId) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256) ||
        sizeBytes < 1 ||
        sizeBytes > 15 << 20 ||
        !const {
          'image/png',
          'image/jpeg',
          'application/pdf',
        }.contains(contentType)) {
      throw const FormatException('Private upload checkpoint is invalid.');
    }
  }

  factory PrivateUploadCheckpoint.fromJson(Object? value) {
    if (value is! Map<String, Object?> ||
        value.length != 6 ||
        value['schema'] != 1 ||
        value['asset_id'] is! String ||
        value['purpose'] is! String ||
        value['content_type'] is! String ||
        value['size_bytes'] is! int ||
        value['sha256'] is! String) {
      throw const FormatException('Private upload checkpoint is invalid.');
    }
    final purpose = switch (value['purpose']) {
      'IDENTITY_DOCUMENT' => PrivateMediaPurpose.identityDocument,
      'COMPLETION_PROOF' => PrivateMediaPurpose.completionProof,
      _ => throw const FormatException('Private upload purpose is invalid.'),
    };
    return PrivateUploadCheckpoint(
      assetId: value['asset_id']! as String,
      purpose: purpose,
      contentType: value['content_type']! as String,
      sizeBytes: value['size_bytes']! as int,
      sha256: value['sha256']! as String,
    );
  }

  final String assetId;
  final PrivateMediaPurpose purpose;
  final String contentType;
  final int sizeBytes;
  final String sha256;

  Map<String, Object?> toJson() => {
    'schema': 1,
    'asset_id': assetId,
    'purpose': purpose.wireValue,
    'content_type': contentType,
    'size_bytes': sizeBytes,
    'sha256': sha256,
  };
  Map<String, Object?> get _metadata => {
    'purpose': purpose.wireValue,
    'content_type': contentType,
    'size_bytes': sizeBytes,
    'sha256': sha256,
  };
}

/// A scan may be retried with the same asset. A pending scan is never evidence
/// that an upload is safe or usable by an owning business service.
final class PrivateMediaPending implements Exception {
  const PrivateMediaPending(this.assetId);
  final String assetId;
  @override
  String toString() => 'Private upload is awaiting verification.';
}

final class PrivateMediaRejected implements Exception {
  const PrivateMediaRejected();
  @override
  String toString() => 'The private upload was rejected.';
}

/// Uploads only to explicit deployment origins. The S3 transport has no API
/// bearer credentials, retries, telemetry or redirects. Signed URLs and bytes
/// are never persisted. Use an account/session-bound ApiClient for the owner
/// API and cancel the operation when its account scope ends.
final class PrivateMediaUploader {
  PrivateMediaUploader({
    required ApiClient client,
    required Set<Uri> allowedOrigins,
    bool allowDevelopmentHttp = false,
    ApiTransport? uploadTransport,
    DateTime Function()? clock,
  }) : _client = client,
       _origins = allowedOrigins
           .map((uri) => _origin(uri, allowDevelopmentHttp))
           .toSet(),
       _uploadTransport = uploadTransport,
       _clock = clock ?? DateTime.now {
    if (_origins.isEmpty || _origins.length > 4) {
      throw const FormatException('Configure private upload origins.');
    }
  }

  final ApiClient _client;
  final Set<String> _origins;
  final ApiTransport? _uploadTransport;
  final DateTime Function() _clock;
  final Set<ApiCancellationToken> _operations = {};
  bool _disposed = false;
  bool get isActive => !_disposed;

  void dispose() {
    _disposed = true;
    for (final token in _operations.toList()) {
      token.cancel();
    }
  }

  /// Discard only an upload that has not yet been submitted to an owning
  /// business service. Business evidence retention is enforced by the owner.
  Future<void> discardUnsubmitted(String assetId) async {
    if (_disposed || !_uuid.hasMatch(assetId)) {
      throw const TransportCancelledException();
    }
    await _client.send(
      ApiRequest.command(
        operation: 'media.discard_unsubmitted_upload',
        method: 'DELETE',
        path: '/v1/media/$assetId',
        body: null,
      ),
      (_) => null,
    );
  }

  Future<String> upload({
    required Uint8List bytes,
    required String contentType,
    required PrivateMediaPurpose purpose,
    ApiCancellationToken? cancellationToken,
    Future<void> Function(PrivateUploadCheckpoint checkpoint)? onCheckpoint,
  }) async {
    if (bytes.isEmpty ||
        bytes.length > 15 << 20 ||
        !const {
          'image/png',
          'image/jpeg',
          'application/pdf',
        }.contains(contentType)) {
      throw const FormatException('Private document size or type is invalid.');
    }
    if (_disposed) throw const TransportCancelledException();
    final cancellation = ApiCancellationToken();
    final stopCancellation = cancellationToken?.onCancel(cancellation.cancel);
    cancellation.throwIfCancelled();
    _operations.add(cancellation);
    final body = Uint8List.fromList(bytes);
    try {
      final checksum = sha256.convert(body);
      final metadata = <String, Object?>{
        'purpose': purpose.wireValue,
        'content_type': contentType,
        'size_bytes': body.length,
        'sha256': checksum.toString(),
      };
      final grant = (await _client.send(
        ApiRequest(
          operation: 'media.create_private_upload',
          method: 'POST',
          path: '/v1/media/uploads',
          body: metadata,
        ),
        _map,
        cancellationToken: cancellation,
      )).value;
      final asset = _map(grant['asset']);
      final id = asset['id'];
      if (id is! String ||
          !_uuid.hasMatch(id) ||
          asset['state'] != 'PENDING_UPLOAD' ||
          !_matches(asset, metadata)) {
        throw const FormatException('Private upload grant is invalid.');
      }
      final target = Uri.tryParse(grant['upload_url'] as String? ?? '');
      final expires = DateTime.tryParse(grant['expires_at'] as String? ?? '');
      if (target == null ||
          !target.isAbsolute ||
          (target.scheme != 'http' && target.scheme != 'https') ||
          target.userInfo.isNotEmpty ||
          target.fragment.isNotEmpty ||
          !_origins.contains(target.origin) ||
          target.pathSegments.isEmpty ||
          target.pathSegments.last != id ||
          expires == null ||
          !expires.isAfter(_clock()) ||
          expires.difference(_clock()) >
              const Duration(minutes: 30, seconds: 5)) {
        throw const FormatException('Private upload destination is invalid.');
      }
      final expectedHeaders = <String, String>{
        'content-type': contentType,
        'x-amz-checksum-sha256': base64Encode(checksum.bytes),
        'x-amz-meta-sha256': checksum.toString(),
        'if-none-match': '*',
      };
      final headers = _map(grant['headers']);
      final normalized = <String, String>{};
      for (final entry in headers.entries) {
        final key = entry.key.toLowerCase();
        if (entry.value is! String ||
            normalized.containsKey(key) ||
            expectedHeaders[key] != entry.value) {
          throw const FormatException('Private upload headers are invalid.');
        }
        normalized[key] = entry.value! as String;
      }
      if (normalized.length != expectedHeaders.length) {
        throw const FormatException(
          'Private upload integrity headers are missing.',
        );
      }
      // Persist only an account-scoped reference before sending bytes. A failed
      // checkpoint never proceeds with an untracked binary upload.
      await onCheckpoint?.call(
        PrivateUploadCheckpoint(
          assetId: id,
          purpose: purpose,
          contentType: contentType,
          sizeBytes: body.length,
          sha256: checksum.toString(),
        ),
      );
      cancellation.throwIfCancelled();
      final transport =
          _uploadTransport ?? IoApiTransport(maxResponseBytes: 16384);
      try {
        cancellation.throwIfCancelled();
        final response = await transport.send(
          TransportRequest(
            method: 'PUT',
            url: target,
            headers: Map.unmodifiable(normalized),
            body: body,
          ),
          timeout: const Duration(seconds: 30),
          cancellationToken: cancellation,
        );
        if (response.statusCode != 200 && response.statusCode != 204) {
          throw const PrivateMediaRejected();
        }
        cancellation.throwIfCancelled();
        try {
          final completed = (await _client.send(
            ApiRequest.command(
              operation: 'media.complete_private_upload',
              method: 'POST',
              path: '/v1/media/$id/complete',
              body: null,
            ),
            _map,
            cancellationToken: cancellation,
          )).value;
          if (completed['id'] != id || !_matches(completed, metadata)) {
            throw const FormatException('Private upload result is invalid.');
          }
          if (completed['state'] == 'PENDING_SCAN') {
            throw PrivateMediaPending(id);
          }
          if (completed['state'] != 'READY') throw const PrivateMediaRejected();
          return id;
        } on ApiFailure catch (error) {
          if (error.retryable) {
            throw PrivateMediaPending(id);
          }
          rethrow;
        }
      } finally {
        if (_uploadTransport == null && transport is IoApiTransport) {
          transport.close(force: true);
        }
      }
    } finally {
      body.fillRange(0, body.length, 0);
      stopCancellation?.call();
      _operations.remove(cancellation);
    }
  }

  /// Re-read the owning service after restart. A cached checkpoint can never
  /// establish readiness, ownership or KYC approval on its own.
  Future<String> resume(
    PrivateUploadCheckpoint checkpoint, {
    ApiCancellationToken? cancellationToken,
  }) async {
    if (_disposed) throw const TransportCancelledException();
    final cancellation = ApiCancellationToken();
    final stop = cancellationToken?.onCancel(cancellation.cancel);
    _operations.add(cancellation);
    try {
      cancellation.throwIfCancelled();
      var asset = (await _client.send(
        ApiRequest.get(
          operation: 'media.resume_private_upload',
          path: '/v1/media/${checkpoint.assetId}',
        ),
        _map,
        cancellationToken: cancellation,
      )).value;
      void verify() {
        if (asset['id'] != checkpoint.assetId ||
            !_matches(asset, checkpoint._metadata)) {
          throw const FormatException(
            'Private upload checkpoint no longer matches its owner.',
          );
        }
      }

      verify();
      if (asset['state'] == 'PENDING_UPLOAD' ||
          asset['state'] == 'PENDING_SCAN') {
        asset = (await _client.send(
          ApiRequest.command(
            operation: 'media.resume_private_scan',
            method: 'POST',
            path: '/v1/media/${checkpoint.assetId}/complete',
            body: null,
          ),
          _map,
          cancellationToken: cancellation,
        )).value;
        verify();
      }
      cancellation.throwIfCancelled();
      if (asset['state'] == 'PENDING_SCAN' ||
          asset['state'] == 'PENDING_UPLOAD') {
        throw PrivateMediaPending(checkpoint.assetId);
      }
      if (asset['state'] != 'READY') throw const PrivateMediaRejected();
      return checkpoint.assetId;
    } on ApiFailure catch (error) {
      if (error.retryable) throw PrivateMediaPending(checkpoint.assetId);
      rethrow;
    } finally {
      stop?.call();
      _operations.remove(cancellation);
    }
  }

  static Map<String, Object?> _map(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const FormatException('Private upload response is invalid.');
    }
    return value;
  }

  static bool _matches(
    Map<String, Object?> asset,
    Map<String, Object?> metadata,
  ) => metadata.entries.every((entry) => asset[entry.key] == entry.value);

  static String _origin(Uri uri, bool development) {
    if (!uri.isAbsolute ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        (uri.scheme != 'https' &&
            !(development &&
                uri.scheme == 'http' &&
                const {
                  'localhost',
                  '127.0.0.1',
                  '10.0.2.2',
                }.contains(uri.host)))) {
      throw const FormatException('Private upload origin is invalid.');
    }
    return uri.origin;
  }

  static final _uuid = RegExp(
    r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$',
  );
}
