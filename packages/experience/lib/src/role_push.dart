import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_core/planext4u_core.dart';

abstract interface class RolePushMessaging {
  /// Reads existing OS authorization. Never opens a permission prompt.
  Future<bool> authorize();
  Future<String?> token();
  Stream<String> get tokenRefreshes;
  Future<Map<String, String>?> initialInteraction();
  Stream<Map<String, String>> get interactions;
}

final class FirebaseRolePushMessaging implements RolePushMessaging {
  FirebaseRolePushMessaging(this._messaging);

  final FirebaseMessaging _messaging;

  @override
  Future<bool> authorize() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> token() async {
    if (Platform.isIOS && await _messaging.getAPNSToken() == null) return null;
    return _messaging.getToken();
  }

  @override
  Stream<String> get tokenRefreshes => _messaging.onTokenRefresh;

  @override
  Future<Map<String, String>?> initialInteraction() async =>
      _stringData((await _messaging.getInitialMessage())?.data);

  @override
  Stream<Map<String, String>> get interactions => FirebaseMessaging
      .onMessageOpenedApp
      .map((message) => _stringData(message.data) ?? const <String, String>{});
}

abstract interface class RolePushDeviceRemote {
  Future<void> register({
    required String token,
    required String platform,
    required String locale,
  });
  Future<void> unregister();
}

final class RolePushDeviceApi implements RolePushDeviceRemote {
  const RolePushDeviceApi(this._client);

  final ApiClient _client;

  @override
  Future<void> register({
    required String token,
    required String platform,
    required String locale,
  }) async {
    await _client.send(
      ApiRequest.command(
        operation: 'notification.register_current_role_device',
        method: 'PUT',
        path: '/v1/notifications/devices/current',
        body: {'platform': platform, 'locale': locale, 'token': token},
      ),
      (_) {},
    );
  }

  @override
  Future<void> unregister() async {
    await _client.send(
      ApiRequest.command(
        operation: 'notification.unregister_current_role_device',
        method: 'DELETE',
        path: '/v1/notifications/devices/current',
        body: null,
      ),
      (_) {},
    );
  }
}

enum RolePushRegistrationStatus {
  idle,
  checkingPermission,
  denied,
  registering,
  registered,
  unavailable,
}

final class RolePushRegistration {
  RolePushRegistration({
    required RolePushMessaging messaging,
    required RolePushDeviceRemote remote,
    required this.role,
    required this.platform,
    this.locale = 'en-IN',
    String? allowedHost,
    String? allowedScheme,
    this.onDeepLink,
    this.onStatusChanged,
  }) : _messaging = messaging,
       _remote = remote,
       allowedHost = allowedHost ?? 'planext4u.net',
       allowedScheme = allowedScheme ?? 'planext4u-${role.name}';

  final RolePushMessaging _messaging;
  final RolePushDeviceRemote _remote;
  final AppRole role;
  final String platform;
  final String locale;
  final String allowedHost;
  final String allowedScheme;
  final void Function(Uri uri)? onDeepLink;
  final void Function(RolePushRegistrationStatus status)? onStatusChanged;
  StreamSubscription<String>? _tokens;
  StreamSubscription<Map<String, String>>? _interactions;
  bool _started = false;
  bool _closed = false;
  bool _authorized = false;
  bool _initialInteractionHandled = false;
  String? _lastToken;
  String? _registeredToken;
  int _registeredPermissionEpoch = -1;
  int _permissionEpoch = 0;
  int _tokenRevision = 0;
  RolePushRegistrationStatus _status = RolePushRegistrationStatus.idle;
  int _epoch = 0;
  Future<void>? _retryInFlight;
  Future<void> _writes = Future.value();

  RolePushRegistrationStatus get status => _status;

  Future<void> start() async {
    if (_started || _closed) return;
    _started = true;
    _epoch++;
    _interactions = _messaging.interactions.listen(
      _handleInteraction,
      onError: (_) {},
    );
    await retry();
  }

  Future<void> retry() {
    if (_closed) return Future<void>.value();
    if (!_started) return start();
    final active = _retryInFlight;
    if (active != null) return active;
    final operation = _retry(_epoch);
    _retryInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_retryInFlight, operation)) _retryInFlight = null;
    });
  }

  /// A settings return must not be lost behind an earlier in-flight check.
  Future<void> refreshAuthorization() async {
    if (!_started || _closed) return;
    final epoch = _epoch;
    await _retryInFlight;
    if (_current(epoch)) await retry();
  }

  bool _current(int epoch) => _started && !_closed && _epoch == epoch;

  Future<void> _retry(int epoch) async {
    final permissionEpoch = ++_permissionEpoch;
    var removalAttempted = false;
    // Pause token callbacks while Android's current grant is unknown.
    _authorized = false;
    _lastToken = null;
    try {
      if (!_initialInteractionHandled) {
        _initialInteractionHandled = true;
        final initial = await _messaging.initialInteraction();
        if (!_current(epoch)) return;
        _handleInteraction(initial);
      }
      _setStatus(RolePushRegistrationStatus.checkingPermission);
      final authorized = await _messaging.authorize();
      if (!_current(epoch) || permissionEpoch != _permissionEpoch) return;
      _authorized = authorized;
      if (!_authorized) {
        removalAttempted = true;
        await _removeRegistration(epoch, permissionEpoch);
        if (!_current(epoch) || permissionEpoch != _permissionEpoch) return;
        _setStatus(RolePushRegistrationStatus.denied);
        return;
      }
      _tokens ??= _messaging.tokenRefreshes.listen(
        (value) {
          if (!_current(epoch) || !_authorized) return;
          _tokenRevision++;
          _lastToken = value;
          unawaited(_registerSafely(value));
        },
        onError: (_) {
          if (_current(epoch) && _authorized) {
            _setStatus(RolePushRegistrationStatus.unavailable);
          }
        },
      );
      final tokenRevision = _tokenRevision;
      final fetched = await _messaging.token();
      if (!_current(epoch) ||
          permissionEpoch != _permissionEpoch ||
          !_authorized) {
        return;
      }
      // A newer stream event wins over an older in-flight getToken result.
      final current = tokenRevision == _tokenRevision ? fetched : _lastToken;
      if (current == null || current.isEmpty) {
        _setStatus(RolePushRegistrationStatus.unavailable);
        return;
      }
      _lastToken = current;
      await _registerSafely(current);
    } catch (_) {
      if (_current(epoch) && permissionEpoch == _permissionEpoch) {
        _authorized = false;
        try {
          if (!removalAttempted) {
            await _removeRegistration(epoch, permissionEpoch);
          }
        } catch (_) {
          /* Retry keeps cleanup available. */
        }
        if (_current(epoch) && permissionEpoch == _permissionEpoch) {
          _setStatus(RolePushRegistrationStatus.unavailable);
        }
      }
      // Push is optional. Authentication and operational queues remain usable
      // when Firebase, APNS or the notification service is unavailable.
    }
  }

  Future<void> _registerSafely(String token) {
    final epoch = _epoch;
    final permissionEpoch = _permissionEpoch;
    final operation = _writes.then((_) async {
      if (!_current(epoch) ||
          permissionEpoch != _permissionEpoch ||
          !_authorized) {
        return;
      }
      if (_registeredToken == token &&
          _registeredPermissionEpoch == permissionEpoch) {
        _setStatus(RolePushRegistrationStatus.registered);
        return;
      }
      _setStatus(RolePushRegistrationStatus.registering);
      try {
        await _remote.register(
          token: token,
          platform: platform,
          locale: locale,
        );
        if (_current(epoch) &&
            permissionEpoch == _permissionEpoch &&
            _authorized) {
          _registeredToken = token;
          _registeredPermissionEpoch = permissionEpoch;
          _setStatus(RolePushRegistrationStatus.registered);
        }
      } catch (_) {
        if (_current(epoch) &&
            permissionEpoch == _permissionEpoch &&
            _authorized) {
          _setStatus(RolePushRegistrationStatus.unavailable);
        }
      }
    });
    _writes = operation;
    return operation;
  }

  Future<void> _removeRegistration(int epoch, int permissionEpoch) async {
    final tokens = _tokens;
    _tokens = null;
    _lastToken = null;
    await tokens?.cancel();
    final removal = _writes.then((_) async {
      if (!_current(epoch) || permissionEpoch != _permissionEpoch) return;
      await _remote.unregister();
      if (_current(epoch) && permissionEpoch == _permissionEpoch) {
        _registeredToken = null;
        _registeredPermissionEpoch = -1;
      }
    });
    // A failed removal is visible to retry(), but does not poison later writes.
    _writes = removal.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    await removal;
  }

  void _setStatus(RolePushRegistrationStatus value) {
    if (_status == value) return;
    _status = value;
    onStatusChanged?.call(value);
  }

  void _handleInteraction(Map<String, String>? data) {
    if (!_started) return;
    final raw = data?['deep_link'];
    final uri = raw == null ? null : Uri.tryParse(raw);
    if (uri == null ||
        !isSafeRoleDeepLink(
          uri,
          role,
          allowedHost: allowedHost,
          allowedScheme: allowedScheme,
        )) {
      return;
    }
    onDeepLink?.call(uri);
  }

  Future<void> dispose({bool unregister = false}) async {
    _closed = true;
    _started = false;
    _epoch++;
    _permissionEpoch++;
    _retryInFlight = null;
    final tokens = _tokens;
    final interactions = _interactions;
    _tokens = null;
    _interactions = null;
    _authorized = false;
    _initialInteractionHandled = false;
    _lastToken = null;
    _registeredToken = null;
    _registeredPermissionEpoch = -1;
    _setStatus(RolePushRegistrationStatus.idle);
    await tokens?.cancel();
    await interactions?.cancel();
    if (!unregister) return;
    try {
      // Finish any already issued registration before removing the device.
      await _writes;
      await _remote.unregister();
    } catch (_) {
      // Server-side session revocation remains authoritative.
    }
  }
}

final class RolePushLifecycle {
  RolePushLifecycle({
    required this.role,
    required RolePushMessaging messaging,
    String? allowedHost,
    String? allowedScheme,
    this.onDeepLink,
  }) : _messaging = messaging,
       allowedHost = allowedHost ?? 'planext4u.net',
       allowedScheme = allowedScheme ?? 'planext4u-${role.name}';

  factory RolePushLifecycle.firebase({
    required AppRole role,
    String? allowedHost,
    String? allowedScheme,
    void Function(Uri uri)? onDeepLink,
  }) => RolePushLifecycle(
    role: role,
    messaging: FirebaseRolePushMessaging(FirebaseMessaging.instance),
    allowedHost: allowedHost,
    allowedScheme: allowedScheme,
    onDeepLink: onDeepLink,
  );

  final AppRole role;
  final RolePushMessaging _messaging;
  final String allowedHost;
  final String allowedScheme;
  final void Function(Uri uri)? onDeepLink;
  RolePushRegistration? _registration;
  int _generation = 0;

  Future<void> start(ApiClient client) async {
    final generation = ++_generation;
    final previous = _registration;
    _registration = null;
    await previous?.dispose();
    if (generation != _generation) return;
    final registration = RolePushRegistration(
      messaging: _messaging,
      remote: RolePushDeviceApi(client),
      role: role,
      platform: Platform.isIOS ? 'IOS' : 'ANDROID',
      allowedHost: allowedHost,
      allowedScheme: allowedScheme,
      onDeepLink: onDeepLink,
    );
    _registration = registration;
    await registration.start();
    if (generation != _generation) await registration.dispose();
  }

  Future<void> end(bool unregister) async {
    _generation++;
    final previous = _registration;
    _registration = null;
    await previous?.dispose(unregister: unregister);
  }

  Future<void> retry() => _registration?.retry() ?? Future<void>.value();
  Future<void> refreshAuthorization() =>
      _registration?.refreshAuthorization() ?? Future<void>.value();
}

bool isSafeRoleDeepLink(
  Uri uri,
  AppRole role, {
  String? allowedHost,
  String? allowedScheme,
}) {
  final path = uri.path.isEmpty ? '/' : uri.path;
  final prefix = role == AppRole.customer ? '/app' : '/${role.name}';
  if (!(path == prefix || path.startsWith('$prefix/'))) {
    return false;
  }
  // A network-path reference has no scheme but still names an external host.
  if (!uri.isAbsolute) return !uri.hasAuthority;
  final officialWeb =
      uri.scheme == 'https' &&
      uri.host.toLowerCase() == (allowedHost ?? 'planext4u.net').toLowerCase();
  final officialScheme =
      uri.scheme == (allowedScheme ?? 'planext4u-${role.name}');
  return officialWeb || officialScheme;
}

Map<String, String>? _stringData(Map<String, dynamic>? value) {
  if (value == null) return null;
  return {
    for (final entry in value.entries)
      if (entry.value is String) entry.key: entry.value! as String,
  };
}
