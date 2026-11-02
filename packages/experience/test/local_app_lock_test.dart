import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_device_access/planext4u_device_access.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

class Store implements LocalAppLockStore {
  Store(this.value);
  bool value;
  bool failRead = false, failWrite = false;
  int writes = 0;
  Completer<bool>? readGate;
  Completer<void>? writeGate;
  @override
  Future<bool> enabled() async {
    if (failRead) throw StateError('Unreadable setting');
    return readGate?.future ?? value;
  }

  @override
  Future<void> setEnabled(bool value) async {
    writes++;
    await writeGate?.future;
    if (failWrite) throw StateError('Save failed');
    this.value = value;
  }
}

class RecoverableStore extends Store implements RecoverableLocalAppLockStore {
  RecoverableStore(super.value);
  int resets = 0;
  @override
  Future<void> resetAfterFreshProof() async {
    resets++;
    failRead = false;
    value = false;
  }
}

class Unlock implements LocalUnlockPlatform {
  bool accepted = false;
  int calls = 0, cancellations = 0;
  Completer<bool>? gate;
  @override
  Future<bool> authenticate() async {
    calls++;
    return gate?.future ?? accepted;
  }

  @override
  Future<void> cancel() async {
    cancellations++;
  }
}

class Privacy implements ScreenPrivacyPlatform {
  final released = <String>[];
  Completer<String>? gate;
  int owners = 0;
  @override
  Future<String> acquire() async => gate?.future ?? 'owner-${++owners}';
  @override
  Future<void> release(String owner) async {
    released.add(owner);
  }
}

LocalAppLockController controller(
  Store store,
  Unlock unlock,
  Privacy privacy, {
  bool fresh = false,
}) => LocalAppLockController(
  store: store,
  platform: unlock,
  privacy: privacy,
  freshServerSignIn: fresh,
  signInAgain: () async {},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Namespace repair is unavailable without fresh sign-in and consumes its proof',
    () async {
      final store = RecoverableStore(true)..failRead = true;
      final restored = controller(store, Unlock(), Privacy());
      await restored.initialize();
      await restored.resetAfterFreshSignIn();
      expect(store.resets, 0);
      restored.dispose();
      final fresh = controller(store, Unlock(), Privacy(), fresh: true);
      await fresh.initialize();
      await fresh.resetAfterFreshSignIn();
      expect(store.resets, 1);
      expect(fresh.locked, false);
      await fresh.resetAfterFreshSignIn();
      expect(store.resets, 1);
      fresh.dispose();
    },
  );
  test(
    'Restored sessions require OS unlock and cancellation keeps content locked',
    () async {
      final store = Store(true), auth = Unlock(), privacy = Privacy();
      final lock = controller(store, auth, privacy);
      await lock.initialize();
      expect(lock.locked, true);
      expect(auth.calls, 0);
      await lock.unlock();
      expect(lock.locked, true);
      expect(lock.error, isNotNull);
      auth.accepted = true;
      await lock.unlock();
      expect(lock.locked, false);
      lock.background();
      lock.resume();
      expect(lock.locked, true);
      expect(store.writes, 0);
      lock.dispose();
    },
  );
  test(
    'Fresh sign-in convenience is consumed before the next background lock',
    () async {
      final store = Store(true), auth = Unlock(), privacy = Privacy();
      final lock = controller(store, auth, privacy, fresh: true);
      await lock.initialize();
      expect(lock.locked, false);
      expect(auth.calls, 0);
      lock.background();
      lock.resume();
      expect(lock.locked, true);
      expect(lock.canResetAfterFreshSignIn, false);
      await lock.resetAfterFreshSignIn();
      expect(store.writes, 0);
      expect(lock.locked, true);
      lock.dispose();
    },
  );
  test(
    'Corrupt settings fail closed; only a new interactive sign-in can reset them',
    () async {
      final store = Store(true)..failRead = true;
      final restored = controller(store, Unlock(), Privacy());
      await restored.initialize();
      await restored.resetAfterFreshSignIn();
      expect(restored.locked, true);
      expect(store.writes, 0);
      restored.dispose();
      final fresh = controller(store, Unlock(), Privacy(), fresh: true);
      await fresh.initialize();
      expect(fresh.locked, true);
      expect(fresh.canResetAfterFreshSignIn, true);
      await fresh.resetAfterFreshSignIn();
      expect(fresh.locked, false);
      expect(store.value, false);
      fresh.dispose();
    },
  );
  test(
    'Late OS success after account disposal cannot unlock or notify',
    () async {
      final auth = Unlock()..gate = Completer<bool>();
      final privacy = Privacy();
      final lock = controller(Store(true), auth, privacy);
      await lock.initialize();
      final pending = lock.unlock();
      await Future<void>.delayed(Duration.zero);
      var notifications = 0;
      lock.addListener(() => notifications++);
      lock.dispose();
      auth.gate!.complete(true);
      await pending;
      expect(lock.locked, true);
      expect(notifications, 0);
      expect(auth.cancellations, 1);
      expect(privacy.released, ['owner-1']);
    },
  );
  test(
    'Late native privacy acquisition is released after account disposal',
    () async {
      final privacy = Privacy()..gate = Completer<String>();
      final lock = controller(Store(true), Unlock(), privacy);
      final pending = lock.initialize();
      await Future<void>.delayed(Duration.zero);
      lock.dispose();
      privacy.gate!.complete('late-owner');
      await pending;
      expect(privacy.released, ['late-owner']);
      expect(lock.locked, true);
    },
  );
  test(
    'A background event while settings load cannot use an earlier fresh sign-in',
    () async {
      final store = Store(true)..readGate = Completer<bool>();
      final lock = controller(store, Unlock(), Privacy(), fresh: true);
      final pending = lock.initialize();
      lock.background();
      store.readGate!.complete(true);
      await pending;
      lock.resume();
      expect(lock.locked, true);
      expect(lock.canResetAfterFreshSignIn, false);
      lock.dispose();
    },
  );
  test(
    'Device credential success in its OS activity is accepted only on return',
    () async {
      final auth = Unlock()..gate = Completer<bool>();
      final lock = controller(Store(true), auth, Privacy());
      await lock.initialize();
      final pending = lock.unlock();
      await Future<void>.delayed(Duration.zero);
      lock.background();
      auth.gate!.complete(true);
      await pending;
      expect(lock.locked, true);
      lock.resume();
      expect(lock.locked, false);
      lock.background();
      lock.resume();
      expect(lock.locked, true);
      lock.dispose();
    },
  );
  test(
    'Backgrounding during the settings commit preserves the new enabled lock',
    () async {
      final store = Store(false)..writeGate = Completer<void>();
      final lock = controller(store, Unlock()..accepted = true, Privacy());
      await lock.initialize();
      final pending = lock.setEnabled(true);
      await Future<void>.delayed(Duration.zero);
      lock.background();
      store.writeGate!.complete();
      await pending;
      lock.resume();
      expect(store.value, true);
      expect(lock.enabled, true);
      expect(lock.locked, true);
      lock.dispose();
    },
  );
  test(
    'Unconfirmed setting writes require a fresh read instead of an enabled success',
    () async {
      final store = Store(false)..failWrite = true;
      final lock = controller(store, Unlock()..accepted = true, Privacy());
      await lock.initialize();
      await lock.setEnabled(true);
      expect(lock.enabled, false);
      expect(lock.locked, true);
      expect(lock.initialized, false);
      expect(lock.error, isNotNull);
      store.failWrite = false;
      await lock.retryInitialization();
      expect(lock.locked, false);
      lock.dispose();
    },
  );
  test(
    'Native secure settings persist only within the same account, country and tenant',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      SecureLocalAppLockStore store(
        String tenant,
        String country,
        String identity,
      ) => SecureLocalAppLockStore(
        tenantId: tenant,
        country: country,
        identityId: identity,
      );
      await store('tenant-a', 'IN', 'identity-a').setEnabled(true);
      expect(await store('tenant-a', 'IN', 'identity-a').enabled(), true);
      expect(await store('tenant-a', 'SG', 'identity-a').enabled(), false);
      expect(await store('tenant-a', 'IN', 'identity-b').enabled(), false);
      expect(await store('tenant-b', 'IN', 'identity-a').enabled(), false);
      FlutterSecureStorage.setMockInitialValues({});
    },
  );
  testWidgets(
    'The gate hides every route and its semantics, then relocks after background',
    (tester) async {
      final auth = Unlock();
      final lock = controller(Store(true), auth, Privacy());
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: LocalAppLockGate(
            controller: lock,
            child: const Scaffold(body: Text('private-account-marker')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('private-account-marker'), findsNothing);
      expect(find.bySemanticsLabel('private-account-marker'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('unlock-local-app')));
      await tester.pumpAndSettle();
      expect(find.text('private-account-marker'), findsNothing);
      auth.accepted = true;
      await tester.tap(find.byKey(const ValueKey('unlock-local-app')));
      await tester.pumpAndSettle();
      expect(find.text('private-account-marker'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('private-account-marker'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      lock.dispose();
      semantics.dispose();
    },
  );
}
