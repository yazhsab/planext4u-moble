import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

void main() {
  test('account privacy controller fails closed and can retry', () async {
    final remote = _AccountPrivacyRemote()..fail = true;
    final controller = AccountPrivacyController(remote);

    expect(await controller.exportAccountData(), isNull);
    expect(controller.state.status, AccountPrivacyStatus.failure);
    expect(controller.state.message, contains('could not be exported'));

    remote.fail = false;
    expect(await controller.exportAccountData(), isNotNull);
    expect(controller.state.status, AccountPrivacyStatus.ready);
    expect(remote.exportCalls, 2);
  });

  testWidgets(
    'privacy screen exports and requires exact deletion confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final remote = _AccountPrivacyRemote();
      final controller = AccountPrivacyController(remote);

      await tester.pumpWidget(
        MaterialApp(home: AccountPrivacyScreen(controller: controller)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('export-account-data')),
        250,
      );
      await tester.tap(find.byKey(const ValueKey('export-account-data')));
      await tester.pumpAndSettle();
      expect(find.text('Account export ready'), findsOneWidget);
      expect(find.textContaining('private-device'), findsNothing);
      expect(find.text('2 sessions'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('request-account-deletion')),
        250,
      );
      await tester.tap(find.byKey(const ValueKey('request-account-deletion')));
      await tester.pumpAndSettle();
      final confirmButton = find.byKey(
        const ValueKey('confirm-account-deletion'),
      );
      expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);

      await tester.enterText(
        find.byKey(const ValueKey('account-deletion-confirmation')),
        'delete my account',
      );
      await tester.pump();
      expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);

      await tester.enterText(
        find.byKey(const ValueKey('account-deletion-confirmation')),
        'DELETE MY ACCOUNT',
      );
      await tester.enterText(
        find.byKey(const ValueKey('account-deletion-reason')),
        'No longer needed',
      );
      await tester.pump();
      expect(tester.widget<FilledButton>(confirmButton).onPressed, isNotNull);
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      expect(remote.deletionReasons, ['No longer needed']);
      expect(find.textContaining('Deletion scheduled for'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('privacy screen fits a narrow device at 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MaterialApp(
        home: AccountPrivacyScreen(
          controller: AccountPrivacyController(_AccountPrivacyRemote()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (var index = 0; index < 4; index++) {
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}

final class _AccountPrivacyRemote implements AccountPrivacyRemote {
  bool fail = false;
  int exportCalls = 0;
  final List<String> deletionReasons = [];

  @override
  Future<AccountDataExport> exportAccountData() async {
    exportCalls += 1;
    if (fail) throw StateError('offline');
    return AccountDataExport(
      generatedAt: DateTime.utc(2026, 9, 1),
      identityId: 'identity-redacted',
      sessionCount: 2,
      consentCount: 3,
    );
  }

  @override
  Future<AccountDeletionRequest> requestAccountDeletion(String reason) async {
    if (fail) throw StateError('offline');
    deletionReasons.add(reason);
    return AccountDeletionRequest(
      id: 'deletion-request-001',
      status: 'SCHEDULED',
      requestedAt: DateTime.utc(2026, 9, 1),
      effectiveAt: DateTime.utc(2026, 10, 1),
    );
  }
}
