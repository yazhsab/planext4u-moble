import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

final class PrivateCameraCleanupException implements Exception {
  const PrivateCameraCleanupException();
  @override
  String toString() => 'Private camera cache cleanup could not be confirmed.';
}

/// Deletes explicit Android camera results, never an entire cache directory.
/// image_picker_android 0.8.13+17 creates UUID+digits.jpg camera files directly
/// in Context.getCacheDir(). Lost-result resizing can leave the original beside
/// `scaled_<name>`. Both exact names are checked without reading either image.
final class PrivateCameraCache {
  PrivateCameraCache({Future<Directory> Function()? directory})
    : _directory = directory ?? getTemporaryDirectory;
  final Future<Directory> Function() _directory;
  // Windows can acknowledge two concurrent deletes of the same file before
  // its directory entry disappears. Serialize exact-file deletion across
  // cache instances so a cleanup is counted only once in this isolate.
  static Future<void> _deletionTail = Future<void>.value();
  static final _cameraName = RegExp(
    r'^(?:scaled_)?[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}[0-9]{1,24}\.jpg$',
    caseSensitive: false,
  );

  Future<int> discardUnattributed(Iterable<String> paths) async {
    try {
      final inputs = paths.take(9).toList();
      if (inputs.length > 8) throw const PrivateCameraCleanupException();
      if (inputs.isEmpty) return 0;
      final root = await (await _directory()).resolveSymbolicLinks();
      final candidates = <String>{};
      for (final path in inputs) {
        final file = File(path);
        final name = file.uri.pathSegments.last;
        if (!_cameraName.hasMatch(name) ||
            path.contains('\u0000') ||
            !file.uri.isAbsolute ||
            !_samePath(await file.parent.resolveSymbolicLinks(), root)) {
          throw const PrivateCameraCleanupException();
        }
        candidates.add(file.path);
        final sibling = name.startsWith('scaled_')
            ? name.substring(7)
            : 'scaled_$name';
        candidates.add('${file.parent.path}${Platform.pathSeparator}$sibling');
      }
      // Validate all paths before deleting anything. Refuse links/directories,
      // including files that resolve outside the app-owned temporary directory.
      final existing = <File>[];
      for (final path in candidates) {
        final type = await FileSystemEntity.type(path, followLinks: false);
        if (type == FileSystemEntityType.notFound) continue;
        final file = File(path);
        if (type != FileSystemEntityType.file ||
            !_samePath(await file.parent.resolveSymbolicLinks(), root)) {
          throw const PrivateCameraCleanupException();
        }
        String resolved;
        try {
          resolved = await file.resolveSymbolicLinks();
        } on FileSystemException {
          // Another cleanup may unlink this exact file after the type check.
          // Any still-existing entry remains subject to the security checks.
          if (await FileSystemEntity.type(path, followLinks: false) ==
              FileSystemEntityType.notFound) {
            continue;
          }
          rethrow;
        }
        if (!_samePath(
          resolved,
          '$root${Platform.pathSeparator}${file.uri.pathSegments.last}',
        )) {
          throw const PrivateCameraCleanupException();
        }
        existing.add(file);
      }
      final predecessor = _deletionTail;
      final finished = Completer<void>();
      _deletionTail = finished.future;
      await predecessor;
      try {
        var deleted = 0;
        for (final file in existing) {
          final type = await FileSystemEntity.type(
            file.path,
            followLinks: false,
          );
          if (type == FileSystemEntityType.notFound) continue;
          if (type != FileSystemEntityType.file ||
              !_samePath(await file.parent.resolveSymbolicLinks(), root)) {
            throw const PrivateCameraCleanupException();
          }
          try {
            await file.delete();
            deleted++;
          } on FileSystemException {
            // Another isolate or process can still unlink the file after the
            // type check. Preserve other I/O failures as failed cleanup.
            if (await FileSystemEntity.type(file.path, followLinks: false) !=
                FileSystemEntityType.notFound) {
              rethrow;
            }
          }
        }
        return deleted;
      } finally {
        finished.complete();
      }
    } catch (_) {
      // File-system errors may contain private paths; expose only a safe retry.
      throw const PrivateCameraCleanupException();
    }
  }

  static bool _samePath(String a, String b) =>
      Platform.isWindows ? a.toLowerCase() == b.toLowerCase() : a == b;
}
