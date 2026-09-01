import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_identity/planext4u_identity.dart';

void main() {
  test('install IDs are stable, random and safe for device binding', () async {
    final first = MemoryInstallIdStore();
    final firstValue = await first.readOrCreate();

    expect(isValidInstallId(firstValue), isTrue);
    expect(await first.readOrCreate(), firstValue);

    final secondValue = await MemoryInstallIdStore().readOrCreate();
    expect(secondValue, isNot(firstValue));
  });

  test('invalid persisted install IDs are replaced', () async {
    final store = MemoryInstallIdStore('static-shared-device');

    final value = await store.readOrCreate();

    expect(value, isNot('static-shared-device'));
    expect(isValidInstallId(value), isTrue);
  });
}
