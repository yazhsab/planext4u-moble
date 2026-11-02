import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:planext4u_device_access/planext4u_device_access.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

class Store implements LocalAppLockStore {
  bool value = false;
  int writes = 0;
  bool failWrite = false;
  @override
  Future<bool> enabled() async => value;
  @override
  Future<void> setEnabled(bool choice) async {
    writes++;
    if (failWrite) throw StateError('Storage write failed');
    value = choice;
  }
}

class Unlock implements LocalUnlockPlatform {
  bool fail = true;
  @override
  Future<bool> authenticate() async {
    if (fail) {
      throw const LocalAuthException(code: LocalAuthExceptionCode.userCanceled);
    }
    return true;
  }

  @override
  Future<void> cancel() async {}
}

class Privacy implements ScreenPrivacyPlatform {
  int releases = 0;
  @override
  Future<String> acquire() async => 'synthetic-owner';
  @override
  Future<void> release(String owner) async {
    releases++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Native cancellation before a settings write preserves the confirmed disabled choice and permits retry',
    () async {
      final store = Store(), auth = Unlock(), privacy = Privacy();
      final lock = LocalAppLockController(
        store: store,
        platform: auth,
        privacy: privacy,
        signInAgain: () async {},
        freshServerSignIn: false,
      );
      await lock.initialize();
      await lock.setEnabled(true);
      expect(store.writes, 0);
      expect(lock.enabled, false);
      expect(
        lock.initialized,
        true,
        reason:
            'No write was attempted; cancellation must preserve the confirmed setting',
      );
      expect(lock.locked, false);
      expect(privacy.releases, 1);
      auth.fail = false;
      await lock.setEnabled(true);
      expect(store.writes, 1);
      expect(lock.enabled, true);
      expect(lock.locked, false);
      lock.dispose();
    },
  );
  test(
    'A started but unconfirmed storage write still locks and requires rereading',
    () async {
      final store = Store()..failWrite = true, auth = Unlock()..fail = false;
      final lock = LocalAppLockController(
        store: store,
        platform: auth,
        privacy: Privacy(),
        signInAgain: () async {},
        freshServerSignIn: false,
      );
      await lock.initialize();
      await lock.setEnabled(true);
      expect(store.writes, 1);
      expect(lock.locked, true);
      expect(lock.initialized, false);
      lock.dispose();
    },
  );
}
