import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

void main() {
  test(
    'stale device grant cannot overwrite another device withdrawal',
    () async {
      final remote = VersionedConsentRemote();
      final first = ConsentController(remote);
      final second = ConsentController(remote);
      await first.load();
      await second.load();
      await second.setConsent(
        purpose: ConsentPurpose.locationServiceability,
        granted: false,
        policyVersion: 'privacy-1',
      );
      await expectLater(
        first.setConsent(
          purpose: ConsentPurpose.locationServiceability,
          granted: true,
          policyVersion: 'privacy-1',
        ),
        throwsStateError,
      );
      expect(remote.current.granted, isFalse);
      expect(remote.lastExpectedVersion, 1);
      expect(
        first.granted(ConsentPurpose.locationServiceability, 'privacy-1'),
        isFalse,
      );
      await first.load();
      await first.setConsent(
        purpose: ConsentPurpose.locationServiceability,
        granted: true,
        policyVersion: 'privacy-1',
      );
      expect(remote.lastExpectedVersion, 2);
      expect(
        first.granted(ConsentPurpose.locationServiceability, 'privacy-1'),
        isTrue,
      );
      first.dispose();
      second.dispose();
    },
  );
  test('consent grants require the current policy version', () async {
    final remote = FakeConsentRemote();
    final controller = ConsentController(remote);

    await controller.load();
    expect(
      controller.granted(
        ConsentPurpose.locationServiceability,
        'privacy-2026-01',
      ),
      isFalse,
    );

    await controller.setConsent(
      purpose: ConsentPurpose.locationServiceability,
      granted: true,
      policyVersion: 'privacy-2026-01',
    );

    expect(
      controller.granted(
        ConsentPurpose.locationServiceability,
        'privacy-2026-01',
      ),
      isTrue,
    );
    expect(
      controller.granted(
        ConsentPurpose.locationServiceability,
        'privacy-2026-02',
      ),
      isFalse,
    );
    expect(remote.updates, 1);
  });

  test('consent evidence rejects unknown purposes', () {
    expect(
      () => ConsentEvidence.fromJson({
        'evidence_id': 'evidence-1',
        'purpose': 'UNREVIEWED_PURPOSE',
        'granted': true,
        'policy_version': 'privacy-1',
        'recorded_at': '2026-08-27T10:00:00Z',
        'version': 1,
      }),
      throwsFormatException,
    );
  });
}

final class FakeConsentRemote implements ConsentRemote {
  int updates = 0;
  ConsentEvidence? evidence;

  @override
  Future<List<ConsentEvidence>> list() async => [?evidence];

  @override
  Future<ConsentEvidence> record({
    int? expectedVersion,
    required ConsentPurpose purpose,
    required bool granted,
    required String policyVersion,
  }) async {
    updates++;
    return evidence = ConsentEvidence(
      evidenceId: 'evidence-$updates',
      purpose: purpose,
      granted: granted,
      policyVersion: policyVersion,
      recordedAt: DateTime.utc(2026, 8, 27, 10),
      version: updates,
    );
  }
}

final class VersionedConsentRemote implements ConsentRemote {
  ConsentEvidence current = ConsentEvidence(
    evidenceId: 'initial',
    purpose: ConsentPurpose.locationServiceability,
    granted: true,
    policyVersion: 'privacy-1',
    recordedAt: DateTime.utc(2026),
    version: 1,
  );
  int? lastExpectedVersion;
  @override
  Future<List<ConsentEvidence>> list() async => [current];
  @override
  Future<ConsentEvidence> record({
    int? expectedVersion,
    required ConsentPurpose purpose,
    required bool granted,
    required String policyVersion,
  }) async {
    lastExpectedVersion = expectedVersion;
    if (granted && expectedVersion != current.version) {
      throw StateError('CONSENT_VERSION_CONFLICT');
    }
    return current = ConsentEvidence(
      evidenceId: 'evidence-${current.version + 1}',
      purpose: purpose,
      granted: granted,
      policyVersion: policyVersion,
      recordedAt: DateTime.utc(2026),
      version: current.version + 1,
    );
  }
}
