import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

const purpose = ConsentPurpose.locationServiceability;
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'Android journal isolates keys and ciphertext and never resets on an SDK encryption error',
    () {
      final options = SecureConsentJournal.platformStorage.aOptions.toMap();
      expect(options['resetOnError'], 'false');
      expect(options['storageNamespace'], 'planext4u-consent-v1');
      expect(options['migrateWithBackup'], 'false');
    },
  );
  SecureConsentJournal journal({
    String account = 'account-a',
    String tenant = 'tenant-a',
    String country = 'IN',
  }) => SecureConsentJournal(
    tenantId: tenant,
    country: country,
    identityId: account,
  );

  test(
    'withdrawal survives restart and stale server grants; reconnect retries only denial',
    () async {
      final remote = _Remote()..fail = true;
      final first = ConsentController(remote, journal: journal());
      await expectLater(
        first.setConsent(
          purpose: purpose,
          granted: false,
          policyVersion: 'privacy-1',
        ),
        throwsStateError,
      );
      first.dispose();
      final restarted = ConsentController(remote, journal: journal());
      expect(restarted.granted(purpose, 'privacy-1'), false);
      await expectLater(restarted.load(), throwsStateError);
      expect(restarted.hasUnconfirmedChange(purpose), true);
      remote.fail = false;
      await restarted.load();
      expect(remote.writes, [false, false, false]);
      expect(
        restarted.evidence[purpose]!.granted,
        true,
      ); // Deliberately stale server list.
      expect(restarted.granted(purpose, 'privacy-1'), false);
      expect(restarted.hasUnconfirmedChange(purpose), false);
      restarted.dispose();
      final secondRestart = ConsentController(remote, journal: journal());
      await secondRestart.load();
      expect(secondRestart.granted(purpose, 'privacy-1'), false);
      expect(remote.writes, hasLength(3));
      secondRestart.dispose();
    },
  );

  test(
    'newer withdrawal is durable while the previous grant network call is blocked',
    () async {
      final remote = _Remote()..hold = Completer<void>();
      final controller = ConsentController(remote, journal: journal());
      final grant = controller.setConsent(
        purpose: purpose,
        granted: true,
        policyVersion: 'privacy-1',
      );
      await until(() => remote.writes.isNotEmpty);
      final withdrawal = controller.setConsent(
        purpose: purpose,
        granted: false,
        policyVersion: 'privacy-1',
      );
      await until(
        () async => (await journal().read())[purpose]?.retryWithdrawal == true,
      );
      controller.dispose();
      remote.hold!.complete();
      await Future.wait([grant, withdrawal]);
      final restarted = ConsentController(remote, journal: journal());
      await restarted.load();
      expect(remote.writes, [true, false]);
      expect(restarted.granted(purpose, 'privacy-1'), false);
      restarted.dispose();
    },
  );

  test(
    'failed grant is never replayed and only explicit acknowledged grant clears denial',
    () async {
      final remote = _Remote()..fail = true;
      final first = ConsentController(remote, journal: journal());
      await expectLater(
        first.setConsent(
          purpose: purpose,
          granted: true,
          policyVersion: 'privacy-1',
        ),
        throwsStateError,
      );
      first.dispose();
      remote.fail = false;
      final second = ConsentController(remote, journal: journal());
      await second.load();
      expect(remote.writes, [true]);
      expect(second.granted(purpose, 'privacy-1'), false);
      await second.setConsent(
        purpose: purpose,
        granted: true,
        policyVersion: 'privacy-1',
      );
      expect(second.granted(purpose, 'privacy-1'), true);
      expect(await journal().read(), isEmpty);
      second.dispose();
    },
  );

  test(
    'compare-and-confirm cannot clear a later intent from another controller',
    () async {
      final original = await journal().begin(purpose, 'privacy-1', true);
      final withdrawal = await journal().begin(purpose, 'privacy-1', false);
      expect(await journal().confirm(purpose, original.token, true), false);
      expect((await journal().read())[purpose]!.token, withdrawal.token);
    },
  );

  test(
    'journals isolate account, tenant and country without storing identity in key names',
    () async {
      await journal().begin(purpose, 'privacy-1', false);
      expect(await journal(account: 'account-b').read(), isEmpty);
      expect(await journal(tenant: 'tenant-b').read(), isEmpty);
      expect(await journal(country: 'GB').read(), isEmpty);
      final values = await SecureConsentJournal.platformStorage.readAll();
      expect(values.keys.single, isNot(contains('account-a')));
      expect(values.keys.single, isNot(contains('tenant-a')));
    },
  );

  test(
    'corrupt denial fails closed across repeated restarts and is never deleted',
    () async {
      await journal().begin(purpose, 'privacy-1', false);
      final storage = SecureConsentJournal.platformStorage;
      final key = (await storage.readAll()).keys.single;
      await storage.write(key: key, value: 'broken');
      final remote = _Remote();
      for (var index = 0; index < 2; index++) {
        final controller = ConsentController(remote, journal: journal());
        await expectLater(controller.load(), throwsFormatException);
        expect(controller.granted(purpose, 'privacy-1'), false);
        expect(await storage.read(key: key), 'broken');
        controller.dispose();
      }
      expect(remote.reads, 0);
    },
  );
}

Future<void> until(FutureOr<bool> Function() ready) async {
  for (var index = 0; index < 100; index++) {
    if (await ready()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Privacy operation did not reach the expected boundary.');
}

final class _Remote implements ConsentRemote {
  bool fail = false;
  Completer<void>? hold;
  final writes = <bool>[];
  int reads = 0;
  ConsentEvidence evidence(bool grant) => ConsentEvidence(
    evidenceId: 'consent-1',
    purpose: purpose,
    granted: grant,
    policyVersion: 'privacy-1',
    recordedAt: DateTime.utc(2026),
    version: 1,
  );
  @override
  Future<List<ConsentEvidence>> list() async {
    ++reads;
    return [evidence(true)];
  }

  @override
  Future<ConsentEvidence> record({
    int? expectedVersion,
    required ConsentPurpose purpose,
    required bool granted,
    required String policyVersion,
  }) async {
    writes.add(granted);
    await hold?.future;
    if (fail) throw StateError('offline');
    return evidence(granted);
  }
}
