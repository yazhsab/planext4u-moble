import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_storage/planext4u_storage.dart';

const _name = '26aeb279-c481-42e2-bbb8-1853768f1067123456.jpg';
File _file(Directory root, String name) =>
    File('${root.path}${Platform.pathSeparator}$name');
Future<Directory> _root() async =>
    Directory.systemTemp.createTemp('planext4u-camera-cleanup-');
void main() {
  test(
    'explicit lost scaled result removes only its exact raw/scaled private pair',
    () async {
      final root = await _root();
      addTearDown(() => root.delete(recursive: true));
      final raw = _file(root, _name),
          scaled = _file(root, 'scaled_$_name'),
          unrelated = _file(root, 'other-photo.jpg');
      await raw.writeAsString('private original');
      await scaled.writeAsString('private scaled');
      await unrelated.writeAsString('preserve');
      final cache = PrivateCameraCache(directory: () async => root);
      expect(await cache.discardUnattributed([scaled.path, scaled.path]), 2);
      expect(await raw.exists(), isFalse);
      expect(await scaled.exists(), isFalse);
      expect(await unrelated.readAsString(), 'preserve');
      expect(await cache.discardUnattributed([scaled.path]), 0);
    },
  );
  test(
    'normal raw result also removes an existing exact scaled copy',
    () async {
      final root = await _root();
      addTearDown(() => root.delete(recursive: true));
      final raw = _file(root, _name), scaled = _file(root, 'scaled_$_name');
      await raw.writeAsString('private');
      await scaled.writeAsString('private');
      expect(
        await PrivateCameraCache(
          directory: () async => root,
        ).discardUnattributed([raw.path]),
        2,
      );
    },
  );
  test(
    'outside paths are refused before deleting any valid cache result',
    () async {
      final root = await _root(), outside = await _root();
      addTearDown(() => root.delete(recursive: true));
      addTearDown(() => outside.delete(recursive: true));
      final own = _file(root, _name), foreign = _file(outside, _name);
      await own.writeAsString('preserve until safe');
      await foreign.writeAsString('foreign');
      await expectLater(
        PrivateCameraCache(
          directory: () async => root,
        ).discardUnattributed([own.path, foreign.path]),
        throwsA(isA<PrivateCameraCleanupException>()),
      );
      expect(await own.exists(), isTrue);
      expect(await foreign.readAsString(), 'foreign');
    },
  );
  test(
    'directories and gallery-like file names are never deleted recursively',
    () async {
      final root = await _root();
      addTearDown(() => root.delete(recursive: true));
      final disguised = Directory(_file(root, _name).path);
      await disguised.create();
      final child = _file(disguised, 'preserve.txt');
      await child.writeAsString('preserve');
      final gallery = _file(root, 'family-photo.jpg');
      await gallery.writeAsString('preserve');
      final cache = PrivateCameraCache(directory: () async => root);
      for (final path in [disguised.path, gallery.path]) {
        await expectLater(
          cache.discardUnattributed([path]),
          throwsA(isA<PrivateCameraCleanupException>()),
        );
      }
      expect(await child.readAsString(), 'preserve');
      expect(await gallery.exists(), isTrue);
    },
  );
  test(
    'empty input does not touch native storage and oversized results fail before lookup',
    () async {
      var calls = 0;
      final cache = PrivateCameraCache(
        directory: () async {
          calls++;
          throw const FileSystemException('private path must not leak');
        },
      );
      expect(await cache.discardUnattributed([]), 0);
      await expectLater(
        cache.discardUnattributed(List.filled(9, _name)),
        throwsA(isA<PrivateCameraCleanupException>()),
      );
      expect(calls, 0);
      try {
        await cache.discardUnattributed([_name]);
        fail('unavailable directory accepted');
      } on PrivateCameraCleanupException catch (error) {
        expect(error.toString(), isNot(contains('private path')));
      }
    },
  );
  test(
    'parallel cleanups converge without disclosing paths or affecting other files',
    () async {
      final root = await _root();
      addTearDown(() => root.delete(recursive: true));
      final raw = _file(root, _name);
      final unrelated = File('${root.path}${Platform.pathSeparator}notes.txt');
      await unrelated.writeAsString('keep');
      for (var attempt = 0; attempt < 24; attempt++) {
        await raw.writeAsString('private');
        final counts = await Future.wait([
          for (var i = 0; i < 2; i++)
            PrivateCameraCache(
              directory: () async => root,
            ).discardUnattributed([raw.path]),
        ]);
        expect(counts.reduce((a, b) => a + b), 1);
        expect(await raw.exists(), isFalse);
      }
      expect(await unrelated.readAsString(), 'keep');
    },
  );
}
