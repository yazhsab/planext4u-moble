import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_device_access/planext4u_device_access.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

DeviceAccessSnapshot snapshot([
  DeviceAccess location = DeviceAccess.notAllowed,
]) => DeviceAccessSnapshot(
  permissions: {
    for (final p in DevicePermission.values)
      p: p == DevicePermission.location ? location : DeviceAccess.notAllowed,
  },
  locationServiceEnabled: false,
);

class Platform extends Fake implements DeviceAccessPlatform {
  int reads = 0;
  final requests = <DevicePermission>[];
  final settings = <DeviceSettings>[];
  Future<DeviceAccessSnapshot> Function()? readResult;
  @override
  Future<DeviceAccessSnapshot> read() {
    reads++;
    return readResult?.call() ?? Future.value(snapshot());
  }

  @override
  Future<DeviceAccessSnapshot> request(DevicePermission permission) async {
    requests.add(permission);
    return snapshot(DeviceAccess.approximate);
  }

  @override
  Future<bool> openSettings(DeviceSettings destination) async {
    settings.add(destination);
    return true;
  }
}

void main() {
  testWidgets(
    'An OS refresh keeps the request control visible and disabled until confirmed',
    (tester) async {
      final pending = Completer<DeviceAccessSnapshot>();
      final platform = Platform()..readResult = () => pending.future;
      final controller = DevicePermissionsController(platform: platform);
      await tester.pumpWidget(
        MaterialApp(home: DevicePermissionsScreen(controller: controller)),
      );
      await tester.pump();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('request-device-camera')),
        250,
      );
      await tester.pump();
      final button = find.byKey(const ValueKey('request-device-camera'));
      expect(tester.widget<OutlinedButton>(button).onPressed, null);
      pending.complete(snapshot());
      await tester.pumpAndSettle();
      expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
      expect(platform.requests, isEmpty);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
  test('Failed refresh removes a previously allowed permission', () async {
    final platform = Platform()
      ..readResult = () async => snapshot(DeviceAccess.precise);
    final controller = DevicePermissionsController(platform: platform);
    await controller.refresh();
    expect(
      controller.snapshot!.permissions[DevicePermission.location],
      DeviceAccess.precise,
    );
    platform.readResult = () => Future.error(StateError('OS unavailable'));
    await controller.refresh();
    expect(controller.snapshot, null);
    expect(controller.error, isNotNull);
    controller.dispose();
  });
  test(
    'Activity loss and late results do not notify a disposed screen',
    () async {
      final pending = Completer<DeviceAccessSnapshot>();
      final platform = Platform()..readResult = () => pending.future;
      final controller = DevicePermissionsController(platform: platform);
      var changes = 0;
      controller.addListener(() => changes++);
      final read = controller.refresh();
      await controller.request(DevicePermission.camera);
      expect(platform.requests, isEmpty);
      controller.dispose();
      pending.complete(snapshot(DeviceAccess.precise));
      await read;
      expect(changes, 1);
      expect(controller.snapshot, null);
    },
  );
  testWidgets(
    'Permission requests require the explanation and explicit confirmation',
    (tester) async {
      final platform = Platform();
      final controller = DevicePermissionsController(platform: platform);
      await tester.pumpWidget(
        MaterialApp(home: DevicePermissionsScreen(controller: controller)),
      );
      await tester.pumpAndSettle();
      expect(platform.requests, isEmpty);
      await tester.ensureVisible(
        find.byKey(const ValueKey('request-device-location')),
      );
      await tester.tap(find.byKey(const ValueKey('request-device-location')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(platform.requests, isEmpty);
      await tester.tap(find.byKey(const ValueKey('request-device-location')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue to Android'));
      await tester.pumpAndSettle();
      expect(platform.requests, [DevicePermission.location]);
      expect(find.text('Approximate location allowed'), findsOneWidget);
      expect(
        find.text('Device location services are switched off.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
  testWidgets('Return from settings rereads OS state, including revocation', (
    tester,
  ) async {
    final platform = Platform()
      ..readResult = () async => snapshot(DeviceAccess.precise);
    final controller = DevicePermissionsController(platform: platform);
    await tester.pumpWidget(
      MaterialApp(home: DevicePermissionsScreen(controller: controller)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Precise location allowed'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('open-device-app-settings')),
      400,
    );
    await tester.tap(find.byKey(const ValueKey('open-device-app-settings')));
    await tester.pumpAndSettle();
    expect(platform.settings, [DeviceSettings.application]);
    expect(controller.snapshot, null);
    platform.readResult = () async => snapshot();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(platform.reads, 2);
    expect(
      controller.snapshot!.permissions[DevicePermission.location],
      DeviceAccess.notAllowed,
    );
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
