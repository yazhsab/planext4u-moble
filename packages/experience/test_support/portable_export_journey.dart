import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

/// Requires the guarded host harness to cancel/accept the real Android system
/// document picker. Application API responses and file bytes are never seeded.
Future<void> verifyPortableExportJourney(
  WidgetTester tester,
  AccountPrivacyController controller,
  String role,
) async {
  if (!const bool.fromEnvironment('VERIFY_PORTABLE_EXPORT')) {
    return;
  }
  final initial = await controller.exportAccountData();
  expect(initial?.document, isNotNull);
  expect(initial!.identityId, isNotEmpty);
  expect(initial.consentHistoryCount, greaterThanOrEqualTo(1));
  await _until(tester, () => find.byType(Navigator).evaluate().isNotEmpty);
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  navigator.push<void>(
    MaterialPageRoute(
      builder: (_) => AccountPrivacyScreen(controller: controller),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  final scrollables = find.descendant(
    of: find.byType(AccountPrivacyScreen),
    matching: find.byType(Scrollable),
  );
  await _until(tester, () => scrollables.evaluate().isNotEmpty);
  final scrollable = scrollables.first;
  for (final action in ['CANCEL', 'SAVE']) {
    final generate = find.byKey(const ValueKey('export-account-data'));
    await tester.scrollUntilVisible(generate, 180, scrollable: scrollable);
    await _until(
      tester,
      () =>
          controller.consents?.loading != true &&
          controller.lifecycle?.busy != true &&
          generate.evaluate().isNotEmpty &&
          tester.widget<FilledButton>(generate).onPressed != null,
    );
    // Consent/lifecycle responses can expand the list after its initial scroll.
    // Scroll the settled layout and require an actual hit before sending input.
    await tester.ensureVisible(generate);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.ensureVisible(generate);
    await _until(tester, () => generate.hitTestable().evaluate().isNotEmpty);
    await tester.tap(generate.hitTestable());
    final save = find.byKey(const ValueKey('save-account-export'));
    await _until(tester, () => save.evaluate().isNotEmpty);
    // The selected name is read from DocumentsUI by the host rather than
    // assuming the server's current second or supplying a fixture filename.
    await tester.ensureVisible(save);
    await _until(tester, () => save.hitTestable().evaluate().isNotEmpty);
    debugPrint('ACCOUNT_EXPORT_PICKER_$action $role');
    await tester.tap(save);
    await _until(
      tester,
      () =>
          controller.state.status == AccountPrivacyStatus.failure ||
          controller.state.message?.contains(
                action == 'CANCEL'
                    ? 'cancelled'
                    : 'saved to your chosen location',
              ) ==
              true,
    );
    expect(
      controller.state.status,
      AccountPrivacyStatus.ready,
      reason: controller.state.message,
    );
    expect(
      controller.state.message,
      action == 'CANCEL'
          ? contains('cancelled')
          : contains('saved to your chosen location'),
    );
    debugPrint('ACCOUNT_EXPORT_${action}_CONFIRMED $role');
    await tester.pump(const Duration(milliseconds: 300));
  }
  navigator.pop();
  await tester.pump(const Duration(milliseconds: 300));
  expect(tester.takeException(), isNull);
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (!ready()) {
    if (DateTime.now().isAfter(deadline)) {
      fail(
        'Timed out waiting for native portable export/picker acknowledgement.',
      );
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
}
