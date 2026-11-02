import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

void main() {
  testWidgets('opening privacy does not notify an ancestor during layout', (
    tester,
  ) async {
    final consents = ConsentController(_Consents());
    await consents.load();
    final privacy = AccountPrivacyController(_Privacy(), consents: consents);
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: consents,
          builder: (_, _) => AccountPrivacyScreen(controller: privacy),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Privacy choices'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    privacy.dispose();
  });

  testWidgets(
    'privacy controls withdraw at 200 percent text and retain local denial on network failure',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final consents = ConsentController(_Consents());
      final privacy = AccountPrivacyController(_Privacy(), consents: consents);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: AccountPrivacyScreen(controller: privacy),
        ),
      );
      await tester.pumpAndSettle();
      final withdraw = find.byKey(const ValueKey('withdraw-ANALYTICS'));
      await tester.ensureVisible(withdraw);
      await tester.pumpAndSettle();
      await tester.tap(withdraw);
      await tester.pumpAndSettle();
      expect(consents.granted(ConsentPurpose.analytics, 'privacy-1'), isFalse);
      expect(consents.hasUnconfirmedChange(ConsentPurpose.analytics), isTrue);
      expect(
        find.text('Stopped locally; synchronization pending'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      privacy.dispose();
    },
  );
}

final class _Consents implements ConsentRemote {
  @override
  Future<List<ConsentEvidence>> list() async => [
    ConsentEvidence(
      evidenceId: 'evidence',
      purpose: ConsentPurpose.analytics,
      granted: true,
      policyVersion: 'privacy-1',
      recordedAt: DateTime.utc(2026),
      version: 1,
    ),
  ];
  @override
  Future<ConsentEvidence> record({
    int? expectedVersion,
    required ConsentPurpose purpose,
    required bool granted,
    required String policyVersion,
  }) async => throw StateError('offline');
}

final class _Privacy implements AccountPrivacyRemote {
  @override
  Future<AccountDataExport> exportAccountData() async =>
      throw UnimplementedError();
  @override
  Future<AccountDeletionRequest> requestAccountDeletion(String reason) async =>
      throw UnimplementedError();
}
