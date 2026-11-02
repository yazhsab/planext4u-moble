import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';
import 'package:planext4u_device_access/planext4u_device_access.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

// Dedicated AVD only. The companion driver supplies a synthetic device PIN to
// actual Android credential UI. No platform identity or backend proof is faked.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'actual device credential enable, cancellation, unlock and background lock',
    (tester) async {
      final scope =
          'native-unlock-${DateTime.now().toUtc().microsecondsSinceEpoch}';
      SecureLocalAppLockStore store(String country) => SecureLocalAppLockStore(
        tenantId: 'synthetic-local-unlock',
        country: country,
        identityId: scope,
      );
      final settings = store('IN');
      await settings.setEnabled(false);
      final controller = LocalAppLockController(
        store: settings,
        signInAgain: () async {
          fail('Native device unlock must not create a server sign-in.');
        },
        freshServerSignIn: false,
        platform: _TraceUnlock(),
      );
      controller.addListener(
        () => debugPrint(
          'LOCAL_UNLOCK_STATE enabled=${controller.enabled} locked=${controller.locked} busy=${controller.busy} error=${controller.error ?? "none"}',
        ),
      );
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: Planext4uTheme.light,
            home: LocalAppLockGate(
              controller: controller,
              child: Scaffold(
                body: SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const Text('Synthetic private account screen'),
                      LocalAppLockSettings(controller: controller),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(controller.initialized, true);
        expect(controller.enabled, false);
        const screen = AndroidScreenPrivacy();
        final first = await screen.acquire(), second = await screen.acquire();
        await screen.release(first);
        debugPrint('LOCAL_UNLOCK_ONE_SCREEN_OWNER');
        await Future<void>.delayed(const Duration(seconds: 5));
        await screen.release(second);
        debugPrint('LOCAL_UNLOCK_NO_SCREEN_OWNERS');
        await Future<void>.delayed(const Duration(seconds: 5));
        debugPrint('LOCAL_UNLOCK_ENABLE_REQUEST');
        await tester.tap(find.byKey(const ValueKey('enable-local-app-lock')));
        await until(
          tester,
          () =>
              !controller.busy &&
              (controller.enabled || controller.error != null),
        );
        expect(
          controller.error,
          isNull,
          reason: 'Native OS unlock must succeed before enablement.',
        );
        expect(controller.locked, false);
        expect(await store('IN').enabled(), true);
        expect(await store('SG').enabled(), false);
        debugPrint('LOCAL_UNLOCK_ENABLE_CONFIRMED');
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('lock-local-app-now')),
          200,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('lock-local-app-now')));
        await tester.pumpAndSettle();
        expect(find.text('Synthetic private account screen'), findsNothing);
        debugPrint('LOCAL_UNLOCK_CANCEL_REQUEST');
        await tester.tap(find.byKey(const ValueKey('unlock-local-app')));
        await until(tester, () => !controller.busy);
        expect(controller.locked, true);
        expect(find.text('Synthetic private account screen'), findsNothing);
        debugPrint('LOCAL_UNLOCK_CANCEL_CONFIRMED');
        debugPrint('LOCAL_UNLOCK_SUCCESS_REQUEST');
        await tester.tap(find.byKey(const ValueKey('unlock-local-app')));
        await until(tester, () => !controller.busy && !controller.locked);
        expect(find.text('Synthetic private account screen'), findsOneWidget);
        debugPrint('LOCAL_UNLOCK_SUCCESS_CONFIRMED');
        debugPrint('LOCAL_UNLOCK_BACKGROUND_REQUEST');
        await until(
          tester,
          () =>
              controller.locked &&
              WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed,
        );
        expect(find.text('Synthetic private account screen'), findsNothing);
        debugPrint('LOCAL_UNLOCK_BACKGROUND_CONFIRMED');
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
        // Independent controller + actual secure storage: restart still locks,
        // while a different country has no inherited setting.
        final restored = LocalAppLockController(
          store: store('IN'),
          signInAgain: () async {},
          freshServerSignIn: false,
        );
        await restored.initialize();
        expect(restored.enabled, true);
        expect(restored.locked, true);
        restored.dispose();
        debugPrint('NATIVE_LOCAL_UNLOCK_CONFIRMED');
      } finally {
        controller.dispose();
        await settings.setEnabled(false);
      }
    },
  );
}

final class _TraceUnlock implements LocalUnlockPlatform {
  final _delegate = AndroidLocalUnlock();
  @override
  Future<bool> authenticate() async {
    try {
      final result = await _delegate.authenticate();
      debugPrint('NATIVE_DEVICE_AUTH_RESULT $result');
      return result;
    } on LocalAuthException catch (error) {
      debugPrint('NATIVE_DEVICE_AUTH_ERROR ${error.code.name}');
      rethrow;
    }
  }

  @override
  Future<void> cancel() => _delegate.cancel();
}

Future<void> until(WidgetTester tester, bool Function() predicate) async {
  final end = DateTime.now().add(const Duration(seconds: 90));
  while (!predicate()) {
    if (DateTime.now().isAfter(end)) {
      fail('Native local-unlock checkpoint did not finish.');
    }
    await tester.pump(const Duration(milliseconds: 200));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  await tester.pump();
}
