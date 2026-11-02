import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:planext4u_device_access/planext4u_device_access.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

// Dedicated synthetic AVD only. The companion harness operates actual Android
// permission dialogs and location settings, without account/provider fixtures.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'actual Android denial, grant, settings return and fresh OS read',
    (tester) async {
      final controller = DevicePermissionsController();
      await controller.refresh();
      expect(
        controller.snapshot!.permissions[DevicePermission.camera],
        DeviceAccess.notAllowed,
      );
      await tester.pumpWidget(
        MaterialApp(home: DevicePermissionsScreen(controller: controller)),
      );
      await tester.pumpAndSettle();
      for (final choice in ['DENY', 'ALLOW']) {
        await waitFor(
          tester,
          () => !controller.busy && controller.snapshot != null,
        );
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('request-device-camera')),
          250,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('request-device-camera')));
        await tester.pumpAndSettle();
        expect(find.text('Allow camera?'), findsOneWidget);
        debugPrint('DEVICE_ACCESS_CAMERA_${choice}_REQUEST');
        await tester.tap(find.text('Continue to Android'));
        await waitFor(
          tester,
          () => !controller.busy && controller.snapshot != null,
        );
        expect(
          controller.snapshot!.permissions[DevicePermission.camera],
          choice == 'DENY' ? DeviceAccess.notAllowed : DeviceAccess.allowed,
        );
        debugPrint('DEVICE_ACCESS_CAMERA_${choice}_CONFIRMED');
      }
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('open-device-location-settings')),
        -250,
      );
      await tester.pumpAndSettle();
      debugPrint('DEVICE_ACCESS_LOCATION_SETTINGS_REQUEST');
      await tester.tap(
        find.byKey(const ValueKey('open-device-location-settings')),
      );
      await waitFor(
        tester,
        () => controller.snapshot?.locationServiceEnabled == false,
      );
      expect(
        controller.snapshot!.permissions[DevicePermission.camera],
        DeviceAccess.allowed,
      );
      expect(
        find.text('Device location services are switched off.'),
        findsOneWidget,
      );
      debugPrint('DEVICE_ACCESS_LOCATION_SETTINGS_RETURN_CONFIRMED');
      // Allow the guarded companion driver to capture the actual returned UI.
      await Future<void>.delayed(const Duration(seconds: 3));
      final fresh = await const AndroidDeviceAccess().read();
      expect(fresh.locationServiceEnabled, false);
      expect(fresh.permissions[DevicePermission.camera], DeviceAccess.allowed);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      debugPrint('NATIVE_DEVICE_ACCESS_CONFIRMED');
    },
  );
}

Future<void> waitFor(WidgetTester tester, bool Function() predicate) async {
  final deadline = DateTime.now().add(const Duration(seconds: 90));
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Android permission/settings response did not arrive.');
    }
    await tester.pump(const Duration(milliseconds: 250));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  await tester.pump();
}
