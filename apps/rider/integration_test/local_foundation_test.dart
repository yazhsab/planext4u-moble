import 'dart:convert';
import 'dart:typed_data';
import 'package:planext4u_rider/private_onboarding.dart';
import 'package:planext4u_experience/planext4u_experience.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:planext4u_core/planext4u_core.dart';
import 'package:planext4u_identity/planext4u_identity.dart';
import 'package:planext4u_rider/main.dart' as app;

import '../../../packages/experience/test_support/portable_export_journey.dart';
import '../../../packages/experience/test_support/published_education_journey.dart';

// Normal startup and real local HTTP/secure-storage plugins. Provider evidence
// is synthetic; this does not stand in for Firebase, push or financial UAT.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('local Android rider startup, onboarding, live session and logout', (
    tester,
  ) async {
    await app.main();
    final startupRetry = find.byKey(const ValueKey('retry-startup-runtime'));
    await until(
      tester,
      () =>
          startupRetry.evaluate().isNotEmpty ||
          find.text('Continue').evaluate().isNotEmpty ||
          find
              .text('Continue with local development account')
              .evaluate()
              .isNotEmpty ||
          find.byType(app.RiderApp).evaluate().isNotEmpty,
    );
    if (startupRetry.evaluate().isNotEmpty) {
      await tester.ensureVisible(startupRetry);
      await tester.tap(startupRetry);
      await tester.pump(const Duration(milliseconds: 300));
      await until(
        tester,
        () =>
            find.text('Continue').evaluate().isNotEmpty ||
            find
                .text('Continue with local development account')
                .evaluate()
                .isNotEmpty ||
            find.byType(app.RiderApp).evaluate().isNotEmpty,
      );
      debugPrint('NATIVE_STARTUP_RETRY_CONFIRMED rider');
    }
    for (var step = 0; step < 3; step++) {
      final label = step == 2 ? 'Get started' : 'Continue';
      final next = find.text(label);
      if (next.evaluate().isEmpty) break;
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pump(const Duration(milliseconds: 300));
    }
    final login = find.text('Continue with local development account');
    if (find.byType(app.RiderApp).evaluate().isEmpty) {
      await until(tester, () => login.evaluate().isNotEmpty);
      await tester.ensureVisible(login);
      await tester.tap(login);
    }
    await until(tester, () => find.byType(app.RiderApp).evaluate().isNotEmpty);
    final workspace = tester.widget<app.RiderApp>(find.byType(app.RiderApp));
    final profile = workspace.identityProfileController;
    expect(profile, isNotNull);
    final education = profile!.education;
    expect(education, isNotNull);
    await until(tester, () => !education!.loading);
    expect(
      education!.failed,
      isFalse,
      reason: 'Published education must reach its configuration owner.',
    );
    expect(find.text('Your introduction could not be loaded.'), findsNothing);
    if (education case final PublishedEducationController currentEducation) {
      await completePublishedIntroductionIfPresent(tester, currentEducation);
    }
    await profile.load();
    expect(profile.state.current?.roles, contains(AppRole.rider));
    expect(workspace.controller, isNotNull);
    await workspace.controller!.load();
    expect(workspace.controller!.deliveryPrivacyEnforced, isTrue);
    if (!workspace.controller!.deliveryPolicyAvailable) {
      expect(workspace.controller!.deliveryLocationAllowed, isFalse);
    }

    final consents = workspace.accountPrivacyController!.consents!;
    await consents.load();
    await consents.setConsent(
      purpose: ConsentPurpose.analytics,
      granted: false,
      policyVersion: 'phase2-native-privacy-1',
    );
    final currentIdentity = profile.state.current!;
    final progress = workspace.controller!.onboardingProgress;
    expect(
      progress,
      isNotNull,
      reason: 'Normal rider startup must bind its authenticated draft scope.',
    );
    await progress!.save(
      const RiderOnboardingProgress(
        fullName: 'Local native draft',
        vehicleNumber: 'TN01TEST',
        postalCodes: '600001',
      ),
    );
    final recreatedProgress = EncryptedRiderOnboardingProgressStore(
      tenantId: currentIdentity.tenantId,
      country: currentIdentity.country,
      identityId: currentIdentity.identityId,
    );
    expect((await recreatedProgress.read())?.fullName, 'Local native draft');
    await recreatedProgress.clear();
    expect(await progress.read(), isNull);
    final savedDenials = await SecureConsentJournal(
      tenantId: currentIdentity.tenantId,
      country: currentIdentity.country,
      identityId: currentIdentity.identityId,
    ).read();
    expect(savedDenials[ConsentPurpose.analytics], isNotNull);
    expect(savedDenials[ConsentPurpose.analytics]!.unconfirmed, isFalse);
    await verifyPortableExportJourney(
      tester,
      workspace.accountPrivacyController!,
      'rider',
    );
    expect(
      consents.granted(ConsentPurpose.analytics, 'phase2-native-privacy-1'),
      isFalse,
    );

    final privateUploader = workspace.privateMediaUploader;
    expect(privateUploader, isNotNull);
    final photoBuffers = <Uint8List>[];
    final documentProvider = NativeRiderOnboardingProvider(
      uploader: privateUploader!,
      capture: (_) async {
        final bytes = base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aL1sAAAAASUVORK5CYII=',
        );
        photoBuffers.add(bytes);
        return RiderDocumentPhoto(bytes, 'image/png');
      },
    );
    final documents = await documentProvider.collectDocuments(
      vehicleType: 'MOTORBIKE',
    );
    expect(documents.map((value) => value.assetId).toSet(), hasLength(4));
    expect(
      photoBuffers.every((value) => value.every((byte) => byte == 0)),
      isTrue,
    );
    expect(documentProvider.canTokenizeBankAccount, isFalse);
    await documentProvider.discardUnsubmittedDocuments(documents);
    final sessions = workspace.sessionManagementController;
    expect(sessions, isNotNull);
    await sessions!.load();
    expect(sessions.state.status, IdentitySessionManagementStatus.ready);
    expect(
      sessions.state.sessions.where((value) => value.current),
      hasLength(1),
    );
    expect(
      sessions.state.sessions
          .singleWhere((value) => value.current)
          .deviceReference,
      isNotEmpty,
    );
    expect(workspace.onSignOut, isNotNull);
    await workspace.onSignOut!();
    await until(tester, () => login.evaluate().isNotEmpty);
    expect(find.byType(app.RiderApp), findsNothing);
    // Sign in once more through the UI. The old account controllers must have
    // been disposed and the new device session must come from the real owner.
    await tester.ensureVisible(login);
    await tester.tap(login);
    await until(tester, () => find.byType(app.RiderApp).evaluate().isNotEmpty);
    final restored = tester.widget<app.RiderApp>(find.byType(app.RiderApp));
    expect(identical(restored.sessionManagementController, sessions), isFalse);
    final restoredConsents = restored.accountPrivacyController!.consents!;
    expect(identical(restoredConsents, consents), isFalse);
    await restoredConsents.load();
    expect(
      restoredConsents.granted(
        ConsentPurpose.analytics,
        'phase2-native-privacy-1',
      ),
      isFalse,
    );
    final restoredEducation = restored.identityProfileController!.education!;
    await until(tester, () => !restoredEducation.loading);
    expect(restoredEducation.failed, isFalse);
    await restored.sessionManagementController!.load();
    expect(
      restored.sessionManagementController!.state.status,
      IdentitySessionManagementStatus.ready,
    );
    expect(
      restored.sessionManagementController!.state.sessions.where(
        (value) => value.current,
      ),
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
    // Close timers/network clients before the test runner tears down its view.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
  });
}

Future<void> until(WidgetTester tester, bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 45));
  while (!ready()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for normal local application startup/session.');
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
}
