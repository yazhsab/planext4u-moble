import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:planext4u_core/planext4u_core.dart';
import 'package:planext4u_experience/planext4u_experience.dart';
import 'package:planext4u_identity/planext4u_identity.dart';
import 'package:planext4u_customer/main.dart' as app;
import 'package:planext4u_customer/account_stores.dart';
import 'package:planext4u_storage/planext4u_storage.dart';

import '../../../packages/experience/test_support/portable_export_journey.dart';
import '../../../packages/experience/test_support/published_education_journey.dart';

// Normal startup and real local HTTP/secure-storage plugins. Provider evidence
// is synthetic; this does not stand in for Firebase, push or financial UAT.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'local Android customer startup, onboarding, live session and logout',
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
            find.byType(app.CustomerApp).evaluate().isNotEmpty,
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
              find.byType(app.CustomerApp).evaluate().isNotEmpty,
        );
        debugPrint('NATIVE_STARTUP_RETRY_CONFIRMED customer');
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
      if (find.byType(app.CustomerApp).evaluate().isEmpty) {
        await until(tester, () => login.evaluate().isNotEmpty);
        await tester.ensureVisible(login);
        await tester.tap(login);
      }
      await until(
        tester,
        () => find.byType(app.CustomerApp).evaluate().isNotEmpty,
      );
      final workspace = tester.widget<app.CustomerApp>(
        find.byType(app.CustomerApp),
      );
      final bootstrap = workspace.bootstrapController;
      expect(bootstrap, isNotNull);
      await until(
        tester,
        () => bootstrap!.state.status != BootstrapStatus.loading,
      );
      expect(bootstrap!.state.status, BootstrapStatus.ready);
      expect(bootstrap.state.config.revision, greaterThan(0));
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
      expect(profile.state.current?.roles, contains(AppRole.customer));

      final consents = workspace.accountPrivacyController!.consents!;
      await consents.load();
      await consents.setConsent(
        purpose: ConsentPurpose.analytics,
        granted: false,
        policyVersion: 'phase2-native-privacy-1',
      );
      final currentIdentity = profile.state.current!;
      await bootstrap.load();
      expect(bootstrap.state.status, BootstrapStatus.ready);
      await _verifyAudienceCachePersistence(
        bootstrap.state.config,
        currentIdentity.identityId,
      );
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
        'customer',
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
      expect(find.byType(app.CustomerApp), findsNothing);
      // Sign in once more through the UI. The old account controllers must have
      // been disposed and the new device session must come from the real owner.
      await tester.ensureVisible(login);
      await tester.tap(login);
      await until(
        tester,
        () => find.byType(app.CustomerApp).evaluate().isNotEmpty,
      );
      final restored = tester.widget<app.CustomerApp>(
        find.byType(app.CustomerApp),
      );
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
}

// A synthetic audience-derived rail exercises the normal CustomerBootstrapCache
// writer and actual native file/KeyStore boundary. The separate namespace is
// removed afterward; no runtime account cache or server configuration is seeded.
Future<void> _verifyAudienceCachePersistence(
  BootstrapConfig published,
  String identity,
) async {
  final namespace = 'phase2.audience.$identity';
  final files = FileBinaryRecordStore(namespace: namespace);
  final keys = PlatformCacheKeyProvider(namespace: namespace);
  EncryptedRecordStore independent() => EncryptedRecordStore(
    records: FileBinaryRecordStore(namespace: namespace),
    keyProvider: PlatformCacheKeyProvider(namespace: namespace),
    namespace: namespace,
  );
  const marker = 'native-private-audience-cache-probe';
  final protected = BootstrapConfig(
    revision: published.revision,
    publishedAt: published.publishedAt,
    updateGate: published.updateGate,
    latestVersion: published.latestVersion,
    maintenance: published.maintenance,
    maintenanceUntil: published.maintenanceUntil,
    maintenanceText: published.maintenanceText,
    locale: published.locale,
    supportedLocales: published.supportedLocales,
    consentPolicies: published.consentPolicies,
    flags: published.flags,
    homeSections: [
      ...published.homeSections,
      const HomeSectionConfig(
        id: marker,
        kind: 'SERVICE_RAIL',
        titleKey: 'home.services',
        collectionId: marker,
        enabled: true,
        priority: 0,
        requiresLiveAudience: true,
      ),
    ],
  );
  try {
    await CustomerBootstrapCache(
      EncryptedRecordStore(
        records: files,
        keyProvider: keys,
        namespace: namespace,
      ),
    ).write(protected);
    final raw = await independent().get<Object?>(
      'configuration',
      (value) => value,
    );
    expect(raw.value, isNotNull);
    expect(raw.value.toString(), isNot(contains(marker)));
    final restored = await CustomerBootstrapCache(independent()).read();
    expect(restored, isNotNull);
    expect(
      restored!.homeSections.length,
      published.withoutLiveAudience().homeSections.length,
    );
    debugPrint('NATIVE_AUDIENCE_CACHE_CONFIRMED customer');
  } finally {
    await files.clear();
    await keys.destroy();
  }
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
