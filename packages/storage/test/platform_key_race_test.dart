import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_storage/planext4u_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  for (final corrupted in ['invalid-base64!', 'AQID']) {
    test(
      'corrupt key $corrupted recovers without blocking later operations',
      () async {
        const namespace = 'test.key.corrupt';
        FlutterSecureStorage.setMockInitialValues({
          '$namespace.key': corrupted,
        });
        final first = PlatformCacheKeyProvider(namespace: namespace);
        final second = PlatformCacheKeyProvider(namespace: namespace);
        final keys = await Future.wait([
          first.getOrCreate(),
          second.getOrCreate(),
        ]).timeout(const Duration(seconds: 3));
        expect(await keys.first.extractBytes(), hasLength(32));
        expect(await keys.last.extractBytes(), await keys.first.extractBytes());
        await first.destroy().timeout(const Duration(seconds: 3));
        expect(
          await const FlutterSecureStorage().read(key: '$namespace.key'),
          isNull,
        );
      },
    );
  }
  test('concurrent store instances share one durable encryption key', () async {
    final first = PlatformCacheKeyProvider(namespace: 'test.key.race');
    final second = PlatformCacheKeyProvider(namespace: 'test.key.race');
    final keys = await Future.wait([first.getOrCreate(), second.getOrCreate()]);
    expect(
      listEquals(await keys[0].extractBytes(), await keys[1].extractBytes()),
      isTrue,
    );
    final restarted = await PlatformCacheKeyProvider(
      namespace: 'test.key.race',
    ).getOrCreate();
    expect(
      listEquals(await keys[0].extractBytes(), await restarted.extractBytes()),
      isTrue,
    );
  });
  test(
    'key destruction follows an already issued creation across instances',
    () async {
      final first = PlatformCacheKeyProvider(namespace: 'test.key.destroy');
      final second = PlatformCacheKeyProvider(namespace: 'test.key.destroy');
      final creating = first.getOrCreate();
      final destroying = second.destroy();
      await creating;
      await destroying;
      expect(
        await const FlutterSecureStorage().read(key: 'test.key.destroy.key'),
        isNull,
      );
    },
  );
}
