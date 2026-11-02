import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_storage/planext4u_storage.dart';

void main() {
  test(
    'parallel instances preserve invocation order and freeze queued bytes',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'planext4u-file-order-',
      );
      addTearDown(() => root.delete(recursive: true));
      FileBinaryRecordStore open() => FileBinaryRecordStore(
        namespace: 'ordered-test',
        directory: () async => root,
      );
      final bytes = Uint8List.fromList([1, 2, 3]);
      final first = open().writeAtomic('progress', bytes);
      bytes.fillRange(0, bytes.length, 0);
      final readFirst = open().read('progress');
      final second = open().writeAtomic(
        'progress',
        Uint8List.fromList([4, 5, 6]),
      );
      final clearing = open().clear();
      final readCleared = open().read('progress');
      final third = open().writeAtomic(
        'progress',
        Uint8List.fromList([7, 8, 9]),
      );
      await first;
      expect(await readFirst, [1, 2, 3]);
      await second;
      await clearing;
      expect(await readCleared, isNull);
      await third;
      expect(await open().read('progress'), [7, 8, 9]);
    },
  );

  test(
    'a later delete waits for an in-flight file replacement across instances',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'planext4u-file-delete-',
      );
      addTearDown(() => root.delete(recursive: true));
      FileBinaryRecordStore open() => FileBinaryRecordStore(
        namespace: 'delete-test',
        directory: () async => root,
      );
      await open().writeAtomic('progress', Uint8List.fromList([1]));
      final path = '${root.path}/planext4u/delete-test/progress.p4u';
      final committed = File(path), pending = File('$path.pending');
      final started = Completer<void>(), release = Completer<void>();
      await IOOverrides.runZoned(
        () async {
          final writing = open().writeAtomic(
            'progress',
            Uint8List.fromList([2]),
          );
          await started.future;
          final deleting = open().delete('progress');
          release.complete();
          await writing;
          await deleting;
          expect(await open().read('progress'), isNull);
        },
        createFile: (name) => _FailReplacement(
          name == path ? committed : pending,
          failRename: false,
          beforeWrite: () async {
            if (!started.isCompleted) started.complete();
            await release.future;
          },
        ),
      );
    },
  );
  test(
    'a failed replacement retains the last acknowledged disk record',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'planext4u-replacement-',
      );
      addTearDown(() => root.delete(recursive: true));
      final records = FileBinaryRecordStore(
        namespace: 'owned-test',
        directory: () async => root,
      );
      await records.writeAtomic('progress', Uint8List.fromList([1, 2, 3]));
      final path = '${root.path}/planext4u/owned-test/progress.p4u';
      final committed = File(path), pending = File('$path.pending');
      await IOOverrides.runZoned(
        () async {
          await expectLater(
            records.writeAtomic('progress', Uint8List.fromList([4, 5, 6])),
            throwsA(isA<FileSystemException>()),
          );
          expect(await records.read('progress'), [1, 2, 3]);
        },
        createFile: (name) => _FailReplacement(
          name == path ? committed : pending,
          failRename: name.endsWith('.pending'),
        ),
      );
      // A new store ignores the unacknowledged pending bytes and can replace the
      // committed record normally on the actual host filesystem.
      final restarted = FileBinaryRecordStore(
        namespace: 'owned-test',
        directory: () async => root,
      );
      expect(await restarted.read('progress'), [1, 2, 3]);
      await restarted.writeAtomic('progress', Uint8List.fromList([7, 8, 9]));
      expect(await restarted.read('progress'), [7, 8, 9]);
      expect(await pending.exists(), false);
    },
  );
}

// Fault injection uses Dart's IOOverrides; production has no test-only storage
// callback. Every operation except the failing final rename uses real files.
final class _FailReplacement implements File {
  _FailReplacement(this.delegate, {required this.failRename, this.beforeWrite});
  final File delegate;
  final bool failRename;
  final Future<void> Function()? beforeWrite;
  @override
  String get path => delegate.path;
  @override
  Future<bool> exists() => delegate.exists();
  @override
  Future<Uint8List> readAsBytes() => delegate.readAsBytes();
  @override
  Future<File> writeAsBytes(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) async {
    await beforeWrite?.call();
    return delegate.writeAsBytes(bytes, mode: mode, flush: flush);
  }

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) =>
      delegate.delete(recursive: recursive);
  @override
  Future<File> rename(String newPath) async {
    if (failRename) {
      throw FileSystemException('Synthetic replacement failure', path);
    }
    return delegate.rename(newPath);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
