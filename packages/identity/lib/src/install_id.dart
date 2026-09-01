import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stable, non-personal identifier for binding one app installation to a
/// server-side device/session record.
abstract interface class InstallIdStore {
  Future<String> readOrCreate();
}

final class PlatformInstallIdStore implements InstallIdStore {
  PlatformInstallIdStore({
    required String namespace,
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _key = '$namespace.install-id.v1' {
    if (!RegExp(r'^[a-z0-9.]{3,80}$').hasMatch(namespace)) {
      throw const FormatException('Install ID namespace is invalid.');
    }
  }

  final FlutterSecureStorage _storage;
  final String _key;

  @override
  Future<String> readOrCreate() async {
    final existing = await _storage.read(key: _key);
    if (existing != null && isValidInstallId(existing)) return existing;
    final generated = generateInstallId();
    await _storage.write(key: _key, value: generated);
    return generated;
  }
}

final class MemoryInstallIdStore implements InstallIdStore {
  MemoryInstallIdStore([this.value]);

  String? value;

  @override
  Future<String> readOrCreate() async {
    final existing = value;
    if (existing != null && isValidInstallId(existing)) return existing;
    return value = generateInstallId();
  }
}

String generateInstallId() {
  final random = Random.secure();
  final value = List<int>.generate(
    16,
    (_) => random.nextInt(256),
  ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return 'device-$value';
}

bool isValidInstallId(String value) =>
    RegExp(r'^device-[a-f0-9]{32}$').hasMatch(value);
