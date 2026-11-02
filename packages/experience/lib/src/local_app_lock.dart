import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:planext4u_device_access/planext4u_device_access.dart';

abstract interface class LocalUnlockPlatform {
  Future<bool> authenticate();
  Future<void> cancel();
}

final class AndroidLocalUnlock implements LocalUnlockPlatform {
  AndroidLocalUnlock({LocalAuthentication? authentication})
    : _authentication = authentication ?? LocalAuthentication();
  final LocalAuthentication _authentication;
  static Object? _activeOwner;
  Object? _owner;
  bool _closed = false;
  @override
  Future<bool> authenticate() async {
    if (_closed ||
        !Platform.isAndroid ||
        !await _authentication.isDeviceSupported() ||
        _closed ||
        _activeOwner != null) {
      return false;
    }
    final owner = Object();
    _owner = owner;
    _activeOwner = owner;
    try {
      return await _authentication.authenticate(
        localizedReason: 'Unlock Planext4u',
        biometricOnly: false,
        persistAcrossBackgrounding: false,
        sensitiveTransaction: true,
      );
    } finally {
      if (identical(_activeOwner, owner)) _activeOwner = null;
      if (identical(_owner, owner)) _owner = null;
    }
  }

  @override
  Future<void> cancel() async {
    _closed = true;
    if (_owner != null && identical(_activeOwner, _owner)) {
      await _authentication.stopAuthentication();
    }
  }
}

abstract interface class LocalAppLockStore {
  Future<bool> enabled();
  Future<void> setEnabled(bool value);
}

abstract interface class RecoverableLocalAppLockStore
    implements LocalAppLockStore {
  Future<void> resetAfterFreshProof();
}

final class SecureLocalAppLockStore implements RecoverableLocalAppLockStore {
  factory SecureLocalAppLockStore({
    required String tenantId,
    required String country,
    required String identityId,
    FlutterSecureStorage? storage,
    FlutterSecureStorage? recoveryStorage,
  }) {
    if (tenantId.isEmpty ||
        identityId.isEmpty ||
        !RegExp(r'^[A-Z]{2}$').hasMatch(country)) {
      throw const FormatException('App lock scope is invalid.');
    }
    final key = sha256
        .convert(utf8.encode(jsonEncode([tenantId, country, identityId])))
        .toString();
    final namespace = 'planext4u.local_unlock_settings.v1.$key';
    return SecureLocalAppLockStore._(
      key,
      storage ??
          FlutterSecureStorage(
            aOptions: AndroidOptions(
              resetOnError: false,
              storageNamespace: namespace,
            ),
          ),
      recoveryStorage ??
          storage ??
          FlutterSecureStorage(
            aOptions: AndroidOptions(
              resetOnError: true,
              storageNamespace: namespace,
            ),
          ),
    );
  }
  SecureLocalAppLockStore._(this._key, this._storage, this._recoveryStorage);
  final String _key;
  final FlutterSecureStorage _storage;
  final FlutterSecureStorage _recoveryStorage;
  @override
  Future<bool> enabled() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return false;
    final value = jsonDecode(raw);
    if (value is! Map<String, Object?> ||
        value['schema'] != 1 ||
        value['enabled'] is! bool) {
      throw const FormatException('App lock setting is invalid.');
    }
    return value['enabled'] as bool;
  }

  @override
  Future<void> setEnabled(bool value) => _storage.write(
    key: _key,
    value: jsonEncode({'schema': 1, 'enabled': value}),
  );
  @override
  Future<void> resetAfterFreshProof() => _recoveryStorage.write(
    key: _key,
    value: jsonEncode({'schema': 1, 'enabled': false}),
  );
}

/// Optional local screen protection. Backend authentication/authorization remain
/// authoritative; device authentication never creates or refreshes a session.
final class LocalAppLockController extends ChangeNotifier {
  LocalAppLockController({
    required LocalAppLockStore store,
    required Future<void> Function() signInAgain,
    required this.freshServerSignIn,
    LocalUnlockPlatform? platform,
    ScreenPrivacyPlatform privacy = const AndroidScreenPrivacy(),
  }) : _store = store,
       _signInAgain = signInAgain,
       _platform = platform ?? AndroidLocalUnlock(),
       _privacy = privacy,
       _freshRecoveryAvailable = freshServerSignIn,
       _createdAt = DateTime.now().toUtc();
  final LocalAppLockStore _store;
  final Future<void> Function() _signInAgain;
  final LocalUnlockPlatform _platform;
  final ScreenPrivacyPlatform _privacy;
  final bool freshServerSignIn;
  final DateTime _createdAt;
  bool _freshRecoveryAvailable;
  bool _disposed = false;
  bool _initialized = false;
  bool _enabled = false;
  bool _locked = true;
  bool _busy = false;
  bool _authenticating = false;
  int _epoch = 0;
  int _visibilityRevision = 0;
  bool _foreground = true;
  DateTime? _pendingUnlock;
  String? _privacyOwner;
  String? _error;
  bool get initialized => _initialized;
  bool get enabled => _enabled;
  bool get locked => _locked;
  bool get busy => _busy;
  bool get authenticating => _authenticating;
  String? get error => _error;
  bool get canResetAfterFreshSignIn =>
      _freshRecoveryAvailable &&
      DateTime.now().toUtc().difference(_createdAt).abs() <=
          const Duration(minutes: 2);
  bool _current(int epoch) => !_disposed && epoch == _epoch;

  Future<void> _protect(int epoch) async {
    if (_privacyOwner != null) return;
    final owner = await _privacy.acquire();
    if (!_current(epoch)) {
      await _privacy.release(owner);
      return;
    }
    _privacyOwner = owner;
  }

  Future<void> _unprotect() async {
    final owner = _privacyOwner;
    if (owner != null) {
      await _privacy.release(owner);
      if (_privacyOwner == owner) _privacyOwner = null;
    }
  }

  Future<void> initialize() async {
    if (_disposed || _initialized || _busy) return;
    final epoch = ++_epoch;
    _busy = true;
    notifyListeners();
    try {
      // The gate hides content until the stored choice has been read.
      final enabled = await _store.enabled().timeout(
        const Duration(seconds: 10),
      );
      if (!_current(epoch)) return;
      _enabled = enabled;
      if (enabled) await _protect(epoch);
      if (!_current(epoch)) return;
      _locked = enabled && !canResetAfterFreshSignIn;
      _freshRecoveryAvailable = false;
      _error = null;
    } catch (_) {
      if (_current(epoch)) {
        _locked = true;
        _error =
            'App lock could not be restored. Retry, or sign in again to recover access.';
      }
    } finally {
      if (_current(epoch)) {
        _initialized = true;
        _busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> retryInitialization() async {
    if (_disposed || _busy) return;
    _initialized = false;
    await initialize();
  }

  void lock() {
    if (_disposed) return;
    _visibilityRevision++;
    _pendingUnlock = null;
    _freshRecoveryAvailable = false;
    if (!_enabled && _initialized) return;
    _locked = true;
    _error = null;
    notifyListeners();
  }

  void background() {
    if (_disposed) return;
    _foreground = false;
    // The OS credential activity can itself hide Flutter. Its successful
    // result may be accepted only upon a prompt return to this same gate.
    if (!_authenticating) {
      lock();
    } else if (_enabled) {
      _locked = true;
      notifyListeners();
    }
  }

  void resume() {
    if (_disposed) return;
    _foreground = true;
    final pending = _pendingUnlock;
    _pendingUnlock = null;
    if (pending != null &&
        DateTime.now().toUtc().difference(pending).abs() <=
            const Duration(seconds: 10) &&
        _enabled) {
      _locked = false;
      notifyListeners();
    }
  }

  void _acceptUnlock() {
    _locked = !_foreground;
    _pendingUnlock = _foreground ? null : DateTime.now().toUtc();
  }

  Future<bool> _challenge(int epoch) async {
    _authenticating = true;
    try {
      return await _platform.authenticate() && _current(epoch);
    } finally {
      if (_current(epoch)) _authenticating = false;
    }
  }

  Future<void> unlock() async {
    if (_disposed || _busy || !_initialized || !_enabled) return;
    final epoch = ++_epoch;
    final visibility = _visibilityRevision;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _protect(epoch);
      if (!_current(epoch) || !_foreground) return;
      if (await _challenge(epoch) && visibility == _visibilityRevision) {
        _acceptUnlock();
      } else if (_current(epoch)) {
        _error =
            'Unlock cancelled or unavailable. Retry, use your device screen lock, or sign in again.';
      }
    } catch (_) {
      if (_current(epoch)) {
        _error = 'Device unlock is unavailable. Retry or sign in again.';
      }
    } finally {
      if (_current(epoch)) {
        _busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> setEnabled(bool value) async {
    if (_disposed || _busy || !_initialized || _locked) return;
    final epoch = ++_epoch;
    final visibility = _visibilityRevision;
    _busy = true;
    _error = null;
    notifyListeners();
    var writeStarted = false;
    try {
      if (value) {
        await _protect(epoch);
        if (!_current(epoch) || !_foreground) return;
        if (!await _challenge(epoch)) {
          if (_current(epoch)) {
            _error =
                'App lock was not enabled. Set up device biometrics or a screen lock and retry.';
          }
          return;
        }
      }
      if (!_current(epoch)) return;
      writeStarted = true;
      await _store.setEnabled(value);
      if (!_current(epoch)) return;
      _enabled = value;
      if (value) {
        if (visibility == _visibilityRevision) {
          _acceptUnlock();
        } else {
          _locked = true;
        }
      } else {
        _locked = false;
        _pendingUnlock = null;
      }
    } catch (_) {
      if (_current(epoch)) {
        if (writeStarted) {
          _locked = true;
          _initialized = false;
          _error =
              'The saved app lock choice could not be confirmed. Refresh app lock settings.';
        } else {
          _error =
              'App lock was not changed. Device unlock was cancelled or unavailable.';
        }
      }
    } finally {
      if (_current(epoch)) {
        if (!_enabled) {
          try {
            await _unprotect();
          } catch (_) {
            /* Keeping screen protection is safe. */
          }
        }
        if (_current(epoch)) {
          _busy = false;
          notifyListeners();
        }
      }
    }
  }

  Future<void> signInAgain() async {
    if (_disposed || _busy) return;
    _busy = true;
    notifyListeners();
    try {
      await _signInAgain();
    } catch (_) {
      if (!_disposed) {
        _error = 'Sign-out could not finish. Retry before signing in again.';
      }
    } finally {
      if (!_disposed) {
        _busy = false;
        notifyListeners();
      }
    }
  }

  /// Only available after a new server-accepted interactive sign-in. It resets
  /// a broken local choice; restored/refresh-only sessions cannot use it.
  Future<void> resetAfterFreshSignIn() async {
    if (!canResetAfterFreshSignIn || _disposed || _busy) return;
    _busy = true;
    notifyListeners();
    try {
      final store = _store;
      if (store is RecoverableLocalAppLockStore) {
        await store.resetAfterFreshProof();
      } else {
        await store.setEnabled(false);
      }
      if (_disposed) return;
      _enabled = false;
      _locked = false;
      _initialized = true;
      _error = null;
      _freshRecoveryAvailable = false;
      await _unprotect();
    } catch (_) {
      if (!_disposed) _error = 'The local lock could not be reset. Retry.';
    } finally {
      if (!_disposed) {
        _busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _epoch++;
    unawaited(_platform.cancel().catchError((Object _) {}));
    unawaited(_unprotect().catchError((Object _) {}));
    super.dispose();
  }
}
