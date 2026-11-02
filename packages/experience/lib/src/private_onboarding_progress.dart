import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_storage/planext4u_storage.dart';

Set<String> _requiredKinds(String workflow) => switch (workflow) {
  'VENDOR' => const {'OWNER_IDENTITY', 'BUSINESS_REGISTRATION'},
  'RIDER_BICYCLE' => const {'IDENTITY'},
  'RIDER_MOTORBIKE' || 'RIDER_CAR' || 'RIDER_VAN' => const {
    'IDENTITY',
    'DRIVER_LICENSE',
    'VEHICLE_REGISTRATION',
    'INSURANCE',
  },
  _ => throw const FormatException('Private document workflow is invalid.'),
};

/// References only. A saved reference never establishes server readiness,
/// consent, OCR/KYC approval or a bank-verification result.
final class PrivateOnboardingProgress {
  PrivateOnboardingProgress({
    required this.workflow,
    required Map<String, PrivateUploadCheckpoint> documents,
    this.submissionStarted = false,
  }) : documents = Map.unmodifiable(documents) {
    final required = _requiredKinds(workflow);
    if (documents.length > required.length ||
        documents.keys.any((kind) => !required.contains(kind)) ||
        documents.values.any(
          (value) => value.purpose != PrivateMediaPurpose.identityDocument,
        ) ||
        documents.values.map((value) => value.assetId).toSet().length !=
            documents.length ||
        (submissionStarted && documents.length != required.length)) {
      throw const FormatException('Private document progress is invalid.');
    }
  }

  factory PrivateOnboardingProgress.fromJson(Object? value) {
    if (value is! Map<String, Object?> ||
        value.length != 4 ||
        value['schema'] != 1 ||
        value['workflow'] is! String ||
        value['submission_started'] is! bool ||
        value['documents'] is! List<Object?>) {
      throw const FormatException('Private document progress is invalid.');
    }
    final entries = value['documents']! as List<Object?>;
    if (entries.length > 4) {
      throw const FormatException('Too many private documents.');
    }
    final documents = <String, PrivateUploadCheckpoint>{};
    for (final entry in entries) {
      if (entry is! Map<String, Object?> ||
          entry.length != 2 ||
          entry['kind'] is! String ||
          documents.containsKey(entry['kind'])) {
        throw const FormatException('Private document progress is invalid.');
      }
      documents[entry['kind']! as String] = PrivateUploadCheckpoint.fromJson(
        entry['upload'],
      );
    }
    return PrivateOnboardingProgress(
      workflow: value['workflow']! as String,
      documents: documents,
      submissionStarted: value['submission_started']! as bool,
    );
  }

  final String workflow;
  final Map<String, PrivateUploadCheckpoint> documents;
  final bool submissionStarted;
  Set<String> get assetIds =>
      documents.values.map((value) => value.assetId).toSet();
  Map<String, Object?> toJson() => {
    'schema': 1,
    'workflow': workflow,
    'submission_started': submissionStarted,
    'documents': [
      for (final kind in documents.keys.toList()..sort())
        {'kind': kind, 'upload': documents[kind]!.toJson()},
    ],
  };
}

abstract interface class PrivateOnboardingProgressStore {
  String get scopeKey;
  Future<PrivateOnboardingProgress?> read();
  Future<void> write(PrivateOnboardingProgress value);
  Future<void> clear();
}

final class EncryptedPrivateOnboardingProgressStore
    implements PrivateOnboardingProgressStore {
  EncryptedPrivateOnboardingProgressStore({
    required String tenantId,
    required String country,
    required String identityId,
    required this.applicationRole,
    EncryptedRecordStore? store,
    DateTime Function()? clock,
  }) : _key =
           'private-docs-${sha256.convert(utf8.encode(jsonEncode([tenantId, country, identityId, applicationRole])))}',
       _clock = clock ?? (() => DateTime.now().toUtc()),
       _store =
           store ??
           EncryptedRecordStore(
             records: FileBinaryRecordStore(
               namespace: 'onboarding-documents-v1',
             ),
             keyProvider: PlatformCacheKeyProvider(
               namespace: 'planext4u.onboarding.documents.v1',
             ),
             namespace: 'onboarding-documents-v1',
             maxPlaintextBytes: 8192,
           ) {
    if (tenantId.isEmpty ||
        identityId.isEmpty ||
        !RegExp(r'^[A-Z]{2}$').hasMatch(country) ||
        !const {'vendor', 'rider'}.contains(applicationRole)) {
      throw const FormatException(
        'Private document account scope is incomplete.',
      );
    }
  }
  final String applicationRole, _key;
  final EncryptedRecordStore _store;
  final DateTime Function() _clock;
  static final Map<String, Future<void>> _tails = {};
  @override
  String get scopeKey => _key;
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

  bool _matchesRole(PrivateOnboardingProgress value) =>
      applicationRole == 'vendor'
      ? value.workflow == 'VENDOR'
      : value.workflow.startsWith('RIDER_');
  @override
  Future<PrivateOnboardingProgress?> read() => _serialize(() async {
    final result = await _store.get(_key, PrivateOnboardingProgress.fromJson);
    if (result.freshness == CacheFreshness.corrupt) {
      throw StateError(
        'Saved private document progress could not be verified.',
      );
    }
    final value = result.value;
    if (value != null && !_matchesRole(value)) {
      throw const FormatException('Private document role mismatch.');
    }
    return value;
  });
  @override
  Future<void> write(PrivateOnboardingProgress value) {
    if (!_matchesRole(value)) {
      throw const FormatException('Private document role mismatch.');
    }
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

final class PrivateOnboardingPhoto {
  const PrivateOnboardingPhoto(this.bytes, this.contentType);
  final Uint8List bytes;
  final String contentType;
}

/// Optional capability for the normal vendor/rider screens. Discarding local
/// progress after a possibly accepted submission never erases retained evidence.
abstract interface class RecoverableOnboardingDocuments {
  bool get retainsDocumentProgress;
  Future<void> discardSavedDocuments();
  Future<void> prepareDocumentSubmission(Set<String> assetIds);
  Future<void> forgetSubmittedDocuments(Set<String> assetIds);
}

final class PrivateOnboardingDocumentCollector {
  const PrivateOnboardingDocumentCollector({
    required this.uploader,
    this.progress,
  });
  final PrivateMediaUploader uploader;
  final PrivateOnboardingProgressStore? progress;
  static final Map<String, ({Object token, PrivateMediaUploader owner})>
  _leases = {};

  void _active() {
    if (!uploader.isActive) throw const TransportCancelledException();
  }

  Future<T> _exclusive<T>(Future<T> Function() operation) async {
    _active();
    final key = progress?.scopeKey;
    final token = Object();
    if (key != null) {
      final previous = _leases[key];
      if (previous != null && previous.owner.isActive) {
        throw StateError('Another private document operation is active.');
      }
      _leases[key] = (token: token, owner: uploader);
    }
    try {
      return await operation();
    } finally {
      if (key != null && identical(_leases[key]?.token, token)) {
        _leases.remove(key);
      }
    }
  }

  Future<Map<String, String>> collect({
    required String workflow,
    required Future<PrivateOnboardingPhoto?> Function(String kind) capture,
  }) => _exclusive(() async {
    final required = _requiredKinds(workflow).toList();
    final saved = progress == null ? null : await progress!.read();
    _active();
    if (saved?.submissionStarted == true) {
      throw StateError(
        'Refresh the current application before starting another document submission.',
      );
    }
    if (saved != null && saved.workflow != workflow) {
      throw StateError(
        'Discard saved private document progress before changing vehicle type.',
      );
    }
    final checkpoints = <String, PrivateUploadCheckpoint>{...?saved?.documents};
    final ready = <String, String>{};
    Future<void> persist() async {
      _active();
      await progress?.write(
        PrivateOnboardingProgress(workflow: workflow, documents: checkpoints),
      );
      _active();
    }

    try {
      for (final kind in required) {
        _active();
        final previous = checkpoints[kind];
        if (previous != null) {
          try {
            ready[kind] = await uploader.resume(previous);
            _active();
            continue;
          } on PrivateMediaRejected {
            checkpoints.remove(kind);
            await persist();
          } on ApiFailure catch (error) {
            if (error.statusCode != 404 && error.statusCode != 410) rethrow;
            checkpoints.remove(kind);
            await persist();
          }
        }
        final photo = await capture(kind);
        if (photo == null) throw const TransportCancelledException();
        try {
          _active();
          ready[kind] = await uploader.upload(
            bytes: photo.bytes,
            contentType: photo.contentType,
            purpose: PrivateMediaPurpose.identityDocument,
            onCheckpoint: progress == null
                ? null
                : (value) async {
                    checkpoints[kind] = value;
                    await persist();
                  },
          );
          _active();
        } finally {
          photo.bytes.fillRange(0, photo.bytes.length, 0);
        }
      }
      return Map.unmodifiable(ready);
    } catch (_) {
      if (progress == null) {
        for (final id in ready.values) {
          try {
            await uploader.discardUnsubmitted(id);
          } catch (_) {
            /* Retention/retry remains server owned. */
          }
        }
      }
      rethrow;
    }
  });

  Future<void> prepareSubmission(Set<String> ids) => _exclusive(() async {
    if (progress == null) return;
    final saved = await progress!.read();
    _active();
    if (saved == null ||
        saved.submissionStarted ||
        saved.documents.length != _requiredKinds(saved.workflow).length ||
        saved.assetIds.length != ids.length ||
        !saved.assetIds.containsAll(ids)) {
      throw StateError(
        'Refresh the saved document workflow before submitting.',
      );
    }
    await progress!.write(
      PrivateOnboardingProgress(
        workflow: saved.workflow,
        documents: saved.documents,
        submissionStarted: true,
      ),
    );
    _active();
  });

  Future<void> forgetSubmitted(Set<String> ids) => _exclusive(() async {
    if (progress == null) return;
    final saved = await progress!.read();
    _active();
    if (saved == null) return;
    if (!saved.submissionStarted ||
        saved.assetIds.length != ids.length ||
        !saved.assetIds.containsAll(ids)) {
      throw StateError('A different private document workflow is active.');
    }
    await progress!.clear();
    _active();
  });

  Future<void> discardSaved() => _exclusive(() async {
    if (progress == null) return;
    final saved = await progress!.read();
    _active();
    if (saved == null) return;
    // An ambiguous submission may already have claimed these assets. Only the
    // owning server's retention/erasure workflow can release that evidence.
    if (saved.submissionStarted) {
      await progress!.clear();
      _active();
      return;
    }
    final remaining = Map<String, PrivateUploadCheckpoint>.from(
      saved.documents,
    );
    for (final entry in saved.documents.entries) {
      try {
        await uploader.discardUnsubmitted(entry.value.assetId);
      } on ApiFailure catch (error) {
        final retained =
            error.statusCode == 409 && error.code == 'MEDIA_EVIDENCE_RETAINED';
        if (error.statusCode != 404 && error.statusCode != 410 && !retained) {
          rethrow;
        }
      }
      _active();
      remaining.remove(entry.key);
      if (remaining.isEmpty) {
        await progress!.clear();
      } else {
        await progress!.write(
          PrivateOnboardingProgress(
            workflow: saved.workflow,
            documents: remaining,
          ),
        );
      }
      _active();
    }
  });
}
