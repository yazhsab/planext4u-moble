import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

void main() {
  const purpose = ConsentPurpose.locationServiceability;
  test(
    'late load cannot restore consent after an acknowledged withdrawal',
    () async {
      final remote = _Consents();
      final controller = ConsentController(remote);
      await controller.setConsent(
        purpose: purpose,
        granted: true,
        policyVersion: 'privacy-1',
      );
      remote.read = Completer<List<ConsentEvidence>>();
      final loading = controller.load();
      await controller.setConsent(
        purpose: purpose,
        granted: false,
        policyVersion: 'privacy-1',
      );
      remote.read!.complete([_evidence(true)]);
      await loading;
      expect(controller.granted(purpose, 'privacy-1'), isFalse);
      expect(controller.evidence[purpose]!.granted, isFalse);
      controller.dispose();
    },
  );

  test(
    'withdrawal stops local use immediately and stays denied after write failure',
    () async {
      final remote = _Consents();
      final controller = ConsentController(remote);
      await controller.setConsent(
        purpose: purpose,
        granted: true,
        policyVersion: 'privacy-1',
      );
      remote.write = Completer<void>();
      remote.fail = true;
      final withdrawal = controller.setConsent(
        purpose: purpose,
        granted: false,
        policyVersion: 'privacy-1',
      );
      final failure = expectLater(withdrawal, throwsStateError);
      expect(controller.granted(purpose, 'privacy-1'), isFalse);
      remote.write!.complete();
      await failure;
      await controller.load();
      expect(controller.granted(purpose, 'privacy-1'), isFalse);
      expect(controller.hasUnconfirmedChange(purpose), isTrue);
      remote.fail = false;
      remote.write = null;
      await controller.setConsent(
        purpose: purpose,
        granted: false,
        policyVersion: 'privacy-1',
      );
      expect(controller.hasUnconfirmedChange(purpose), isFalse);
      controller.dispose();
    },
  );

  test(
    'grant then withdrawal is persisted in intent order without transient use',
    () async {
      final remote = _Consents()..write = Completer<void>();
      final controller = ConsentController(remote);
      final grant = controller.setConsent(
        purpose: purpose,
        granted: true,
        policyVersion: 'privacy-1',
      );
      final withdraw = controller.setConsent(
        purpose: purpose,
        granted: false,
        policyVersion: 'privacy-1',
      );
      expect(controller.granted(purpose, 'privacy-1'), isFalse);
      remote.write!.complete();
      await Future.wait([grant, withdraw]);
      expect(remote.writes, [true, false]);
      expect(controller.granted(purpose, 'privacy-1'), isFalse);
      expect(controller.evidence[purpose]!.granted, isFalse);
      controller.dispose();
    },
  );

  test(
    'disposal cancels queued consent changes and ignores an in-flight response',
    () async {
      final remote = _Consents()..write = Completer<void>();
      final controller = ConsentController(remote);
      final first = controller.setConsent(
        purpose: purpose,
        granted: true,
        policyVersion: 'privacy-1',
      );
      await Future<void>.delayed(Duration.zero);
      final second = controller.setConsent(
        purpose: purpose,
        granted: false,
        policyVersion: 'privacy-1',
      );
      controller.dispose();
      remote.write!.complete();
      await Future.wait([first, second]);
      expect(remote.writes, [true]);
      expect(controller.evidence, isEmpty);
      expect(controller.granted(purpose, 'privacy-1'), isFalse);
    },
  );

  test(
    'export result from a retired account never reaches the caller',
    () async {
      final remote = _Privacy();
      final controller = AccountPrivacyController(remote);
      final pending = controller.exportAccountData();
      controller.dispose();
      remote.export.complete(
        AccountDataExport(
          generatedAt: DateTime.utc(2026),
          identityId: 'previous-account',
          sessionCount: 1,
          consentCount: 0,
        ),
      );
      expect(await pending, isNull);
      expect(await controller.exportAccountData(), isNull);
    },
  );

  test('late deletion response is ignored after account retirement', () async {
    final remote = _Privacy();
    final controller = AccountPrivacyController(remote);
    final pending = controller.requestAccountDeletion('No longer needed');
    controller.dispose();
    remote.deletion.complete(
      AccountDeletionRequest(
        id: 'previous-deletion',
        status: 'SCHEDULED',
        requestedAt: DateTime.utc(2026),
        effectiveAt: DateTime.utc(2026, 2),
      ),
    );
    expect(await pending, isNull);
  });
}

ConsentEvidence _evidence(bool granted) => ConsentEvidence(
  evidenceId: 'consent-evidence',
  purpose: ConsentPurpose.locationServiceability,
  granted: granted,
  policyVersion: 'privacy-1',
  recordedAt: DateTime.utc(2026),
  version: 1,
);

final class _Consents implements ConsentRemote {
  Completer<List<ConsentEvidence>>? read;
  Completer<void>? write;
  bool fail = false;
  final writes = <bool>[];
  @override
  Future<List<ConsentEvidence>> list() async =>
      read == null ? [_evidence(true)] : read!.future;
  @override
  Future<ConsentEvidence> record({
    int? expectedVersion,
    required ConsentPurpose purpose,
    required bool granted,
    required String policyVersion,
  }) async {
    writes.add(granted);
    await write?.future;
    if (fail) throw StateError('offline');
    return _evidence(granted);
  }
}

final class _Privacy implements AccountPrivacyRemote {
  final export = Completer<AccountDataExport>();
  final deletion = Completer<AccountDeletionRequest>();
  @override
  Future<AccountDataExport> exportAccountData() => export.future;
  @override
  Future<AccountDeletionRequest> requestAccountDeletion(String reason) =>
      deletion.future;
}
