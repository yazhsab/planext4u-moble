import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

void main() {
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
