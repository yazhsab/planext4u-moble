import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'identity_models.dart';

abstract interface class SecureSessionStore {
  Future<IdentityAuthentication?> read();

  Future<void> write(IdentityAuthentication authentication);

  Future<void> clear();
}

final class PlatformSecureSessionStore implements SecureSessionStore {
  PlatformSecureSessionStore({
    FlutterSecureStorage? storage,
    String namespace = 'planext4u.identity.v1',
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _key = '$namespace.session';

  final FlutterSecureStorage _storage;
  final String _key;

  @override
  Future<IdentityAuthentication?> read() async {
    final encoded = await _storage.read(key: _key);
    if (encoded == null) return null;
    try {
      final envelope = jsonDecode(encoded);
      if (envelope is! Map<String, Object?> || envelope['schema'] != 1) {
        throw const FormatException('Session envelope is invalid.');
      }
      return IdentityAuthentication.fromJson(envelope['authentication']);
    } catch (_) {
      await clear();
      rethrow;
    }
  }

  @override
  Future<void> write(IdentityAuthentication authentication) => _storage.write(
    key: _key,
    value: jsonEncode({'schema': 1, 'authentication': authentication.toJson()}),
  );

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

final class MemorySecureSessionStore implements SecureSessionStore {
  String? _encoded;

  bool get hasSession => _encoded != null;

  void corruptForTest() => _encoded = '{invalid';

  @override
  Future<IdentityAuthentication?> read() async {
    final encoded = _encoded;
    if (encoded == null) return null;
    try {
      return IdentityAuthentication.fromJson(jsonDecode(encoded));
    } catch (_) {
      await clear();
      rethrow;
    }
  }

  @override
  Future<void> write(IdentityAuthentication authentication) async {
    _encoded = jsonEncode(authentication.toJson());
  }

  @override
  Future<void> clear() async => _encoded = null;
}
