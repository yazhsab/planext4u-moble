import 'package:flutter/services.dart';

enum DevicePermission { location, camera, microphone, notifications, contacts }

enum DeviceAccess { allowed, precise, approximate, notAllowed, unavailable }

enum DeviceSettings { application, location, notifications }

final class DeviceAccessSnapshot {
  const DeviceAccessSnapshot({
    required this.permissions,
    required this.locationServiceEnabled,
  });
  factory DeviceAccessSnapshot.fromPlatform(Object? value) {
    if (value is! Map || value['locationServiceEnabled'] is! bool) {
      throw const FormatException('Invalid device permission response.');
    }
    final result = <DevicePermission, DeviceAccess>{};
    for (final kind in DevicePermission.values) {
      final raw = value[kind.name];
      final matches = DeviceAccess.values.where((state) => state.name == raw);
      if (kind == DevicePermission.contacts && raw == null) {
        result[kind] = DeviceAccess.unavailable;
        continue;
      }
      if (matches.length != 1 ||
          (kind != DevicePermission.location &&
              (raw == 'precise' || raw == 'approximate'))) {
        throw const FormatException('Invalid device permission response.');
      }
      result[kind] = matches.single;
    }
    return DeviceAccessSnapshot(
      permissions: Map.unmodifiable(result),
      locationServiceEnabled: value['locationServiceEnabled'] as bool,
    );
  }
  final Map<DevicePermission, DeviceAccess> permissions;
  final bool locationServiceEnabled;
}

abstract interface class DeviceAccessPlatform {
  Future<DeviceAccessSnapshot> read();
  Future<DeviceAccessSnapshot> request(DevicePermission permission);
  Future<bool> openSettings(DeviceSettings destination);
}

final class AndroidDeviceAccess implements DeviceAccessPlatform {
  const AndroidDeviceAccess();
  static const _channel = MethodChannel('net.planext4u.device-access');
  @override
  Future<DeviceAccessSnapshot> read() async =>
      DeviceAccessSnapshot.fromPlatform(
        await _channel.invokeMethod<Object?>('read'),
      );
  @override
  Future<DeviceAccessSnapshot> request(DevicePermission permission) async =>
      DeviceAccessSnapshot.fromPlatform(
        await _channel.invokeMethod<Object?>('request', {
          'kind': permission.name,
        }),
      );
  @override
  Future<bool> openSettings(DeviceSettings destination) async =>
      await _channel.invokeMethod<bool>('openSettings', {
        'target': destination.name,
      }) ??
      false;
}

final class NativeContactPhones {
  const NativeContactPhones({required this.phones, required this.skipped});
  final List<String> phones;
  final int skipped;
}

abstract interface class ContactPhonesPlatform {
  Future<NativeContactPhones> readPhones({required int maximum});
}

final class AndroidContactPhones implements ContactPhonesPlatform {
  const AndroidContactPhones();
  static const _channel = MethodChannel('net.planext4u.device-access');
  @override
  Future<NativeContactPhones> readPhones({required int maximum}) async {
    if (maximum < 1 || maximum > 10000) {
      throw const FormatException('Contact budget is invalid.');
    }
    final response = await _channel.invokeMethod<Object?>('readContactPhones', {
      'maximum': maximum,
    });
    if (response is! Map ||
        response['phones'] is! List ||
        response['skipped'] is! int ||
        (response['skipped'] as int) < 0) {
      throw const FormatException('Android contact response is invalid.');
    }
    final phones = response['phones'] as List;
    final pattern = RegExp(r'^\+[1-9][0-9]{7,14}$');
    if (phones.length > maximum ||
        phones.any((item) => item is! String || !pattern.hasMatch(item))) {
      throw const FormatException(
        'Android contacts are outside the safe range.',
      );
    }
    return NativeContactPhones(
      phones: List<String>.unmodifiable(phones.cast<String>()),
      skipped: response['skipped'] as int,
    );
  }
}

abstract interface class ScreenPrivacyPlatform {
  Future<String> acquire();
  Future<void> release(String owner);
}

final class AndroidScreenPrivacy implements ScreenPrivacyPlatform {
  const AndroidScreenPrivacy();
  static const _channel = MethodChannel('net.planext4u.device-access');
  @override
  Future<String> acquire() async {
    final owner = await _channel.invokeMethod<String>('privacyAcquire');
    if (owner == null || !RegExp(r'^[0-9a-f-]{36}$').hasMatch(owner)) {
      throw const FormatException('Screen privacy is unavailable.');
    }
    return owner;
  }

  @override
  Future<void> release(String owner) =>
      _channel.invokeMethod<void>('privacyRelease', {'owner': owner});
}
