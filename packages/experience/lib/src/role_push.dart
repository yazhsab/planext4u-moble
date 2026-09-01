import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_core/planext4u_core.dart';

abstract interface class RolePushMessaging {
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
    final settings = await _messaging.requestPermission(provisional: true);
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
  requestingPermission,
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
  bool _authorized = false;
  bool _initialInteractionHandled = false;
  String? _lastToken;
  RolePushRegistrationStatus _status = RolePushRegistrationStatus.idle;

  RolePushRegistrationStatus get status => _status;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _interactions = _messaging.interactions.listen(
      _handleInteraction,
      onError: (_) {},
    );
    await retry();
  }

  Future<void> retry() async {
    if (!_started) return start();
    try {
      if (!_initialInteractionHandled) {
        _initialInteractionHandled = true;
        _handleInteraction(await _messaging.initialInteraction());
      }
      if (!_authorized) {
        _setStatus(RolePushRegistrationStatus.requestingPermission);
        _authorized = await _messaging.authorize();
      }
      if (!_authorized) {
        _setStatus(RolePushRegistrationStatus.denied);
        return;
      }
      _tokens ??= _messaging.tokenRefreshes.listen((value) {
        _lastToken = value;
        unawaited(_registerSafely(value));
      }, onError: (_) => _setStatus(RolePushRegistrationStatus.unavailable));
      final current = _lastToken ?? await _messaging.token();
      if (current == null || current.isEmpty) {
        _setStatus(RolePushRegistrationStatus.unavailable);
        return;
      }
      _lastToken = current;
      await _registerSafely(current);
    } catch (_) {
      _setStatus(RolePushRegistrationStatus.unavailable);
      // Push is optional. Authentication and operational queues remain usable
      // when Firebase, APNS or the notification service is unavailable.
    }
  }

  Future<void> _registerSafely(String token) async {
    _setStatus(RolePushRegistrationStatus.registering);
    try {
      await _remote.register(token: token, platform: platform, locale: locale);
      _setStatus(RolePushRegistrationStatus.registered);
    } catch (_) {
      _setStatus(RolePushRegistrationStatus.unavailable);
      // Explicit retry, token refresh and the next authenticated launch are
      // safe recovery paths.
    }
  }

  void _setStatus(RolePushRegistrationStatus value) {
    if (_status == value) return;
    _status = value;
    onStatusChanged?.call(value);
  }

  void _handleInteraction(Map<String, String>? data) {
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
    await _tokens?.cancel();
    await _interactions?.cancel();
    _tokens = null;
    _interactions = null;
    _started = false;
    _authorized = false;
    _initialInteractionHandled = false;
    _lastToken = null;
    _setStatus(RolePushRegistrationStatus.idle);
    if (!unregister) return;
    try {
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

  Future<void> start(ApiClient client) async {
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
  }

  Future<void> end(bool unregister) async {
    await _registration?.dispose(unregister: unregister);
    _registration = null;
  }
}

bool isSafeRoleDeepLink(
  Uri uri,
  AppRole role, {
  String? allowedHost,
  String? allowedScheme,
}) {
  final path = uri.path.isEmpty ? '/' : uri.path;
  if (!(path == '/${role.name}' || path.startsWith('/${role.name}/'))) {
    return false;
  }
  if (!uri.isAbsolute) return true;
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
