import 'package:flutter/services.dart';

enum DocumentExportResult { saved, cancelled }

abstract interface class DocumentExporter {
  Future<DocumentExportResult> save({
    required String fileName,
    required Uint8List bytes,
    required bool Function() isCurrent,
  });
}

/// The system picker owns the destination. No temporary plaintext copy or
/// persistent storage permission is needed in the application sandbox.
final class PlatformDocumentExporter implements DocumentExporter {
  const PlatformDocumentExporter();

  static const _channel = MethodChannel(
    'net.planext4u.storage/document-export',
  );
  static const maxBytes = 4 * 1024 * 1024;

  @override
  Future<DocumentExportResult> save({
    required String fileName,
    required Uint8List bytes,
    required bool Function() isCurrent,
  }) async {
    if (!RegExp(r'^planext4u-account-\d{8}T\d{6}Z\.json$').hasMatch(fileName) ||
        bytes.isEmpty ||
        bytes.length > maxBytes) {
      throw ArgumentError('Invalid or oversized account export.');
    }
    if (!isCurrent()) return DocumentExportResult.cancelled;
    final destination = await _channel.invokeMethod<String>('choose', {
      'file_name': fileName,
    });
    if (destination == null) return DocumentExportResult.cancelled;
    try {
      // A logout/account switch while the picker is open must not write the
      // previous account's response to the chosen document.
      if (!isCurrent()) return DocumentExportResult.cancelled;
      final written = await _channel.invokeMethod<bool>('write', {
        'destination': destination,
        'bytes': bytes,
      });
      if (written != true) {
        throw StateError('Document write was not confirmed.');
      }
      return DocumentExportResult.saved;
    } finally {
      // Native discard only removes an unfinished newly created document;
      // successful exports deliberately remain in the user-selected location.
      await _channel.invokeMethod<void>('discard', {
        'destination': destination,
      });
    }
  }
}
