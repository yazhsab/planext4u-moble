import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_experience/planext4u_experience.dart';
import 'package:planext4u_rider/main.dart';
import 'package:planext4u_storage/planext4u_storage.dart';

void main() {
  test(
    'encrypted queue survives restart and stays isolated across accounts',
    () async {
      final records = MemoryBinaryRecordStore();
      final keys = MemoryCacheKeyProvider();
      EncryptedRiderCommandStore store() => EncryptedRiderCommandStore(
        store: EncryptedRecordStore(
          records: records,
          keyProvider: keys,
          namespace: 'rider-offline-v1',
        ),
      );
      var first = store();
      expect(first.pending, throwsStateError);
      await first.bind('profile-tenant-a-country-in-rider-one');
      const command = RiderOfflineCommand(
        deviceSequence: 42,
        commandId: 'mobile-persisted-000042',
        kind: 'PICKUP',
        taskId: 'task-owned-by-one',
        revision: 1,
      );
      await first.enqueue(command);
      final other = store();
      await other.bind('profile-tenant-a-country-in-rider-two');
      expect(await other.pending(), isEmpty);
      await other.replace([]);
      first = store();
      await first.bind('profile-tenant-a-country-in-rider-one');
      expect((await first.pending()).single.deviceSequence, 42);
      await first.replace([]);
      expect(await first.pending(), isEmpty);
    },
  );
}
