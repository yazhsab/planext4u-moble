import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_storage/planext4u_storage.dart';

void main() {
  final start = DateTime.utc(2026, 8, 27, 10);

  test(
    'cache ciphertext does not expose plaintext and authenticates its key',
    () async {
      final records = MemoryBinaryRecordStore();
      final store = encrypted(records, start);
      await store.put(
        'catalog.home',
        {'title': 'Synthetic private cache value'},
        expiresAt: start.add(const Duration(minutes: 5)),
        staleUntil: start.add(const Duration(minutes: 30)),
      );

      final bytes = await records.read('catalog.home');
      expect(
        utf8.decode(bytes!),
        isNot(contains('Synthetic private cache value')),
      );
      final result = await store.get<Map<String, Object?>>(
        'catalog.home',
        (value) => value! as Map<String, Object?>,
      );
      expect(result.freshness, CacheFreshness.fresh);
      expect(result.value?['title'], 'Synthetic private cache value');

      await records.writeAtomic('catalog.other', bytes);
      final tampered = await store.get<Object?>(
        'catalog.other',
        (value) => value,
      );
      expect(tampered.freshness, CacheFreshness.corrupt);
      expect(records.contains('catalog.other'), isFalse);
    },
  );

  test('fresh, stale and expired policy is deterministic', () async {
    var now = start;
    final records = MemoryBinaryRecordStore();
    final store = EncryptedRecordStore(
      records: records,
      keyProvider: MemoryCacheKeyProvider(),
      clock: () => now,
    );
    await store.put(
      'bootstrap.snapshot',
      {'revision': 7},
      expiresAt: start.add(const Duration(minutes: 5)),
      staleUntil: start.add(const Duration(minutes: 30)),
    );

    expect(
      (await store.get<Object?>(
        'bootstrap.snapshot',
        (value) => value,
      )).freshness,
      CacheFreshness.fresh,
    );
    now = start.add(const Duration(minutes: 10));
    expect(
      (await store.get<Object?>(
        'bootstrap.snapshot',
        (value) => value,
      )).freshness,
      CacheFreshness.stale,
    );
    now = start.add(const Duration(minutes: 31));
    expect(
      (await store.get<Object?>(
        'bootstrap.snapshot',
        (value) => value,
      )).freshness,
      CacheFreshness.expired,
    );
    expect(records.contains('bootstrap.snapshot'), isFalse);
  });

  test('corruption and logout purge fail closed', () async {
    final records = MemoryBinaryRecordStore();
    final keys = MemoryCacheKeyProvider();
    final store = EncryptedRecordStore(
      records: records,
      keyProvider: keys,
      clock: () => start,
    );
    await store.put(
      'profile.cache',
      {'name': 'Synthetic'},
      expiresAt: start.add(const Duration(hours: 1)),
      staleUntil: start.add(const Duration(hours: 2)),
    );
    records.corrupt('profile.cache');
    expect(
      (await store.get<Object?>('profile.cache', (value) => value)).freshness,
      CacheFreshness.corrupt,
    );

    await store.put(
      'catalog.home',
      const {'value': true},
      expiresAt: start.add(const Duration(hours: 1)),
      staleUntil: start.add(const Duration(hours: 2)),
    );
    await store.purge(destroyKey: true);
    expect(records.contains('catalog.home'), isFalse);
  });

  test('file record store atomically persists and clears records', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'planext4u-storage-test-',
    );
    addTearDown(() => temporary.delete(recursive: true));
    final records = FileBinaryRecordStore(
      namespace: 'test',
      directory: () async => temporary,
    );

    await records.writeAtomic('record.one', utf8.encode('first'));
    await records.writeAtomic('record.one', utf8.encode('second'));
    expect(utf8.decode((await records.read('record.one'))!), 'second');
    await records.clear();
    expect(await records.read('record.one'), isNull);
  });
}

EncryptedRecordStore encrypted(MemoryBinaryRecordStore records, DateTime now) =>
    EncryptedRecordStore(
      records: records,
      keyProvider: MemoryCacheKeyProvider(),
      clock: () => now,
    );
