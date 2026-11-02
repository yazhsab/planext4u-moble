import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_device_access/planext4u_device_access.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('net.planext4u.device-access');
  final calls = <MethodCall>[];
  final value = <String, Object>{
    'location': 'approximate',
    'locationServiceEnabled': false,
    'camera': 'notAllowed',
    'microphone': 'allowed',
    'notifications': 'notAllowed',
  };
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'openSettings' ? false : value;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  test(
    'Reading never requests access and preserves approximate and service-off states',
    () async {
      final result = await const AndroidDeviceAccess().read();
      expect(calls.map((c) => c.method), ['read']);
      expect(
        result.permissions[DevicePermission.location],
        DeviceAccess.approximate,
      );
      expect(result.locationServiceEnabled, false);
      expect(
        result.permissions[DevicePermission.notifications],
        DeviceAccess.notAllowed,
      );
      expect(() => result.permissions.clear(), throwsUnsupportedError);
    },
  );
  test(
    'Only the selected permission and bounded settings target reach the channel',
    () async {
      await const AndroidDeviceAccess().request(DevicePermission.camera);
      expect(calls.single.arguments, {'kind': 'camera'});
      expect(
        await const AndroidDeviceAccess().openSettings(
          DeviceSettings.application,
        ),
        false,
      );
      expect(calls.last.arguments, {'target': 'application'});
    },
  );
  test('Incomplete, unknown or impossible native states fail closed', () {
    for (final invalid in [
      null,
      {},
      {...value, 'locationServiceEnabled': 'true'},
      {...value, 'camera': 'precise'},
      {...value, 'location': 'yes'},
      {...value}..remove('microphone'),
    ]) {
      expect(
        () => DeviceAccessSnapshot.fromPlatform(invalid),
        throwsFormatException,
      );
    }
  });
}
