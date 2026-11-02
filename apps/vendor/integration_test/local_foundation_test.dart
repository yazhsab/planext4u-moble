import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_core/planext4u_core.dart';
import 'package:planext4u_identity/planext4u_identity.dart';
import 'package:planext4u_vendor/main.dart' as app;
import 'package:planext4u_experience/planext4u_experience.dart';

import '../../../packages/experience/test_support/portable_export_journey.dart';
import '../../../packages/experience/test_support/published_education_journey.dart';

// Normal startup and real local HTTP/secure-storage plugins. Provider evidence
// is synthetic; this does not stand in for Firebase, push or financial UAT.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'local Android vendor startup, onboarding, live session and logout',
    (tester) async {
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
            find.byType(app.VendorApp).evaluate().isNotEmpty,
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
              find.byType(app.VendorApp).evaluate().isNotEmpty,
        );
        debugPrint('NATIVE_STARTUP_RETRY_CONFIRMED vendor');
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
      if (find.byType(app.VendorApp).evaluate().isEmpty) {
        await until(tester, () => login.evaluate().isNotEmpty);
        await tester.ensureVisible(login);
        await tester.tap(login);
      }
      await until(
        tester,
        () => find.byType(app.VendorApp).evaluate().isNotEmpty,
      );
      final workspace = tester.widget<app.VendorApp>(
        find.byType(app.VendorApp),
      );
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
      expect(profile.state.current?.roles, contains(AppRole.vendor));

      final consents = workspace.accountPrivacyController!.consents!;
      await consents.load();
      await consents.setConsent(
        purpose: ConsentPurpose.analytics,
        granted: false,
        policyVersion: 'phase2-native-privacy-1',
      );
      final currentIdentity = profile.state.current!;
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
        'vendor',
      );
      expect(
        consents.granted(ConsentPurpose.analytics, 'phase2-native-privacy-1'),
        isFalse,
      );

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
      expect(find.byType(app.VendorApp), findsNothing);
      // Sign in once more through the UI. The old account controllers must have
      // been disposed and the new device session must come from the real owner.
      await tester.ensureVisible(login);
      await tester.tap(login);
      await until(
        tester,
        () => find.byType(app.VendorApp).evaluate().isNotEmpty,
      );
      final restored = tester.widget<app.VendorApp>(find.byType(app.VendorApp));
      expect(restored.privateMediaUploader, isNotNull);
      expect(
        identical(restored.sessionManagementController, sessions),
        isFalse,
      );
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
    },
  );
  testWidgets(
    'native private document bytes reach actual scanner and owning vendor API',
    (tester) async {
      final transport = IoApiTransport();
      final remote = IdentityApi(
        ApiClient(
          baseUrl: Uri.parse('http://10.0.2.2:8082'),
          transport: transport,
        ),
      );
      final identity = await remote.enroll(
        assertion: ProviderAssertion(
          provider: IdentityProviderKind.local,
          token: 'synthetic-participant-${IdempotencyKey.generate()}',
        ),
        deviceId: 'native-private-${DateTime.now().microsecondsSinceEpoch}',
        country: 'IN',
        role: AppRole.vendor,
      );
      final client = ApiClient(
        baseUrl: Uri.parse('http://10.0.2.2:8082'),
        transport: transport,
        authSession: _NativeSession(identity.tokens.accessToken),
      );
      final uploader = PrivateMediaUploader(
        client: client,
        allowedOrigins: {Uri.parse('http://127.0.0.1:9000')},
        allowDevelopmentHttp: true,
      );
      final assets = <String>[];
      try {
        final vendor = VendorOperationsApi(client);
        final application = await vendor.register(
          businessName: 'Synthetic native verification',
          businessType: 'SOLE_PROPRIETOR',
          contactName: 'Synthetic native owner',
        );
        final picture = Uint8List.fromList(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aL1sAAAAASUVORK5CYII=',
          ),
        );
        for (var index = 0; index < 2; index++) {
          assets.add(
            await uploader.upload(
              bytes: picture,
              contentType: 'image/png',
              purpose: PrivateMediaPurpose.identityDocument,
            ),
          );
        }
        final submitted = await vendor.submitDocuments(application.revision, [
          VendorOnboardingDocument(
            kind: 'OWNER_IDENTITY',
            assetId: assets[0],
          ).toJson(),
          VendorOnboardingDocument(
            kind: 'BUSINESS_REGISTRATION',
            assetId: assets[1],
          ).toJson(),
        ]);
        expect(submitted.status, 'DOCUMENTS_SUBMITTED');
        expect(submitted.verified, false);
        expect(
          submitted.documentSummaries.every(
            (document) => document.ocrStatus == 'PENDING',
          ),
          true,
        );
      } finally {
        uploader.dispose();
        await remote.revoke(identity.tokens.refreshToken);
        transport.close(force: true);
      }
    },
  );
}

final class _NativeSession implements ApiAuthSession {
  const _NativeSession(this.token);
  final String token;
  @override
  Future<String?> accessToken() async => token;
  @override
  Future<bool> refresh() async => false;
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
