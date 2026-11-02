import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

/// The foundation journeys also run against installations where introduction
/// pages are intentionally absent. When configured, complete their real UI
/// before testing the authenticated workspace; never seed a completion marker.
Future<void> completePublishedIntroductionIfPresent(
  WidgetTester tester,
  PublishedEducationController education,
) async {
  final config = education.config;
  if (config == null) return;
  Future<void> until(bool Function() ready) async {
    final deadline = DateTime.now().add(const Duration(seconds: 45));
    while (!ready()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Configured introduction did not complete.');
      }
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  if (!await education.store.completed(config.version)) {
    for (var index = 0; index < config.steps.length; index++) {
      await until(
        () => find.text(config.steps[index].title).evaluate().isNotEmpty,
      );
      final next = find.widgetWithText(
        FilledButton,
        index == config.steps.length - 1 ? 'Get started' : 'Continue',
      );
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pump(const Duration(milliseconds: 300));
    }
    await until(
      () =>
          find.text(config.steps.last.title).evaluate().isEmpty ||
          find
              .text('Your onboarding progress could not be saved. Try again.')
              .evaluate()
              .isNotEmpty,
    );
    expect(
      find.text('Your onboarding progress could not be saved. Try again.'),
      findsNothing,
    );
  }
  expect(await education.store.completed(config.version), isTrue);
  expect(
    await EncryptedFirstRunStore.platform(
      '${education.role}.published',
    ).completed(config.version),
    isTrue,
  );
  // A non-sensitive checkpoint lets the host receipt confirm that this journey
  // exercised a configured page rather than the optional missing-page branch.
  debugPrint('PUBLISHED_EDUCATION_NATIVE_CONFIRMED ${education.role}');
}

typedef EducationWorkspace = ({
  PublishedEducationController? education,
  Future<void> Function()? onSignOut,
});

/// Requires independently published role introductions in the actual local
/// configuration owner. No page, completion marker or provider is injected.
Future<void> verifyPublishedEducationJourney(
  WidgetTester tester, {
  required Future<void> Function() start,
  required Finder shell,
  required EducationWorkspace Function() workspace,
  required String role,
}) async {
  Future<void> until(bool Function() ready) async {
    final deadline = DateTime.now().add(const Duration(seconds: 45));
    while (!ready()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Normal published-introduction journey timed out.');
      }
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  final login = find.text('Continue with local development account');
  await start();
  await until(
    () =>
        shell.evaluate().isNotEmpty ||
        login.evaluate().isNotEmpty ||
        find.text('Continue').evaluate().isNotEmpty,
  );
  // Complete the ordinary pre-authentication introduction if this dedicated
  // development application has not already stored its completion marker.
  for (var step = 0; step < 3; step++) {
    final next = find.text(step == 2 ? 'Get started' : 'Continue');
    if (next.evaluate().isEmpty) break;
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pump(const Duration(milliseconds: 300));
  }
  if (shell.evaluate().isEmpty) {
    await until(() => login.evaluate().isNotEmpty);
    await tester.ensureVisible(login);
    await tester.tap(login);
  }
  await until(() => shell.evaluate().isNotEmpty);
  final first = workspace();
  expect(first.education, isNotNull);
  final education = first.education!;
  await until(() => !education.loading);
  expect(education.failed, isFalse);
  final config = education.config;
  expect(
    config,
    isNotNull,
    reason: 'The actual owning service must publish a role introduction.',
  );
  final published = config!;
  expect(published.steps, isNotEmpty);
  for (var step = 0; step < published.steps.length; step++) {
    final content = published.steps[step];
    await until(() => find.text(content.title).evaluate().isNotEmpty);
    expect(find.text(content.message), findsOneWidget);
    final next = find.widgetWithText(
      FilledButton,
      step == published.steps.length - 1 ? 'Get started' : 'Continue',
    );
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pump(const Duration(milliseconds: 300));
  }
  // Native encrypted file/key writes may still be in flight after a frame.
  // The ordinary gate removes its last step only after the write commits.
  await until(
    () =>
        find.text(published.steps.last.title).evaluate().isEmpty ||
        find
            .text('Your onboarding progress could not be saved. Try again.')
            .evaluate()
            .isNotEmpty,
  );
  expect(
    find.text('Your onboarding progress could not be saved. Try again.'),
    findsNothing,
  );
  expect(await education.store.completed(published.version), isTrue);
  expect(
    await EncryptedFirstRunStore.platform(
      '$role.published',
    ).completed(published.version),
    isTrue,
    reason:
        'An independently constructed native store must read the real completion marker.',
  );
  expect(first.onSignOut, isNotNull);
  await first.onSignOut!();
  await until(() => login.evaluate().isNotEmpty);
  await tester.ensureVisible(login);
  await tester.tap(login);
  await until(() => shell.evaluate().isNotEmpty);
  final restored = workspace().education;
  expect(restored, isNotNull);
  expect(identical(restored, education), isFalse);
  await until(() => !restored!.loading);
  expect(restored!.failed, isFalse);
  expect(restored.config?.version, published.version);
  expect(await restored.store.completed(published.version), isTrue);
  await tester.pump(const Duration(seconds: 1));
  expect(find.text(published.steps.first.title), findsNothing);
  expect(find.text('Your introduction could not be loaded.'), findsNothing);
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 300));
}
