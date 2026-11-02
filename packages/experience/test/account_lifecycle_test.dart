import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

void main() {
  test('lifecycle readback rejects contradictory deletion states', () {
    final deletion = <String, Object?>{
      'id': 'deletion-1',
      'status': 'SCHEDULED',
      'requested_at': '2026-10-25T12:00:00Z',
      'effective_at': '2026-11-24T12:00:00Z',
    };
    expect(
      AccountLifecycleInfo.fromJson(<String, Object?>{
        'status': 'ACTIVE',
      }).deletion,
      isNull,
    );
    expect(
      AccountLifecycleInfo.fromJson(<String, Object?>{
        'status': 'DELETION_SCHEDULED',
        'deletion': deletion,
      }).deletion?.id,
      'deletion-1',
    );
    for (final invalid in [
      <String, Object?>{'status': 'ACTIVE', 'deletion': deletion},
      <String, Object?>{'status': 'DELETION_SCHEDULED'},
      <String, Object?>{'status': 'DELETION_SCHEDULED', 'deletion': null},
    ]) {
      expect(
        () => AccountLifecycleInfo.fromJson(invalid),
        throwsFormatException,
      );
    }
  });

  test('deletion readback rejects invalid status, reference and deadline', () {
    final valid = <String, Object?>{
      'id': 'deletion-1',
      'status': 'SCHEDULED',
      'requested_at': '2026-10-25T12:00:00Z',
      'effective_at': '2026-11-24T12:00:00Z',
    };
    expect(AccountDeletionRequest.fromJson(valid).status, 'SCHEDULED');
    for (final change in [
      <String, Object?>{'status': 'COMPLETED'},
      <String, Object?>{'status': 'UNKNOWN'},
      <String, Object?>{'id': '../other-account'},
      <String, Object?>{'effective_at': '2026-10-25T12:00:00Z'},
      <String, Object?>{'effective_at': '2026-10-24T12:00:00Z'},
    ]) {
      expect(
        () => AccountDeletionRequest.fromJson({...valid, ...change}),
        throwsFormatException,
      );
    }
  });

  test(
    'scheduled deletion survives controller recreation and cancellation uses its owner reference',
    () async {
      final remote = _Remote();
      var controller = AccountLifecycleController(remote);
      await controller.load();
      expect(controller.info?.deletion?.id, 'deletion-1');
      controller.dispose();
      controller = AccountLifecycleController(remote);
      await controller.load();
      await controller.cancelDeletion();
      expect(remote.cancelled, ['deletion-1']);
      expect(controller.info?.status, 'ACTIVE');
      expect(controller.info?.deletion, isNull);
      controller.dispose();
    },
  );
  test(
    'provider/authorization failure does not sign out or fabricate deactivation success',
    () async {
      final remote = _Remote()..fail = true;
      var signedOut = false;
      final controller = AccountLifecycleController(
        remote,
        onDeactivated: () async {
          signedOut = true;
        },
      );
      await controller.deactivate();
      expect(signedOut, isFalse);
      expect(controller.message, contains('fresh sign-in'));
      remote.fail = false;
      await controller.deactivate();
      expect(signedOut, isTrue);
      controller.dispose();
    },
  );
  test(
    'completion from a disposed account cannot sign out a later account',
    () async {
      final wait = Completer<void>();
      final remote = _Remote()..pending = wait.future;
      var signedOut = false;
      final controller = AccountLifecycleController(
        remote,
        onDeactivated: () async {
          signedOut = true;
        },
      );
      final operation = controller.deactivate();
      controller.dispose();
      wait.complete();
      await operation;
      expect(signedOut, isFalse);
    },
  );
}

final class _Remote implements AccountLifecycleRemote {
  bool fail = false;
  Future<void>? pending;
  final List<String> cancelled = [];
  @override
  Future<AccountLifecycleInfo> getLifecycle() async => AccountLifecycleInfo(
    status: 'DELETION_SCHEDULED',
    deletion: AccountDeletionRequest(
      id: 'deletion-1',
      status: 'SCHEDULED',
      requestedAt: DateTime.utc(2026, 10, 25),
      effectiveAt: DateTime.utc(2026, 11, 24),
    ),
  );
  @override
  Future<void> cancelDeletion(String requestId) async {
    cancelled.add(requestId);
  }

  @override
  Future<void> deactivate() async {
    if (fail) throw StateError('provider unavailable');
    await pending;
  }
}
