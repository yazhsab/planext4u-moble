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

final class RolePushRegistration {
  RolePushRegistration({
    required RolePushMessaging messaging,
    required RolePushDeviceRemote remote,
    required this.role,
    required this.platform,
    this.locale = 'en-IN',
    this.onDeepLink,
  }) : _messaging = messaging,
       _remote = remote;

  final RolePushMessaging _messaging;
  final RolePushDeviceRemote _remote;
  final AppRole role;
  final String platform;
  final String locale;
  final void Function(Uri uri)? onDeepLink;
  StreamSubscription<String>? _tokens;
  StreamSubscription<Map<String, String>>? _interactions;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _interactions = _messaging.interactions.listen(
      _handleInteraction,
      onError: (_) {},
    );
    try {
      _handleInteraction(await _messaging.initialInteraction());
      if (!await _messaging.authorize()) return;
      final current = await _messaging.token();
      if (current != null) await _registerSafely(current);
      _tokens = _messaging.tokenRefreshes.listen(
        (value) => unawaited(_registerSafely(value)),
        onError: (_) {},
      );
    } catch (_) {
      // Push is optional. Authentication and operational queues remain usable
      // when Firebase, APNS or the notification service is unavailable.
    }
  }

  Future<void> _registerSafely(String token) async {
    try {
      await _remote.register(token: token, platform: platform, locale: locale);
    } catch (_) {
      // Token refresh and the next authenticated launch provide safe retries.
    }
  }

  void _handleInteraction(Map<String, String>? data) {
    final raw = data?['deep_link'];
    final uri = raw == null ? null : Uri.tryParse(raw);
    if (uri == null || !isSafeRoleDeepLink(uri, role)) return;
    onDeepLink?.call(uri);
  }

  Future<void> dispose({bool unregister = false}) async {
    await _tokens?.cancel();
    await _interactions?.cancel();
    _tokens = null;
    _interactions = null;
    _started = false;
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
    this.onDeepLink,
  }) : _messaging = messaging;

  factory RolePushLifecycle.firebase({
    required AppRole role,
    void Function(Uri uri)? onDeepLink,
  }) => RolePushLifecycle(
    role: role,
    messaging: FirebaseRolePushMessaging(FirebaseMessaging.instance),
    onDeepLink: onDeepLink,
  );

  final AppRole role;
  final RolePushMessaging _messaging;
  final void Function(Uri uri)? onDeepLink;
  RolePushRegistration? _registration;

  Future<void> start(ApiClient client) async {
    final registration = RolePushRegistration(
      messaging: _messaging,
      remote: RolePushDeviceApi(client),
      role: role,
      platform: Platform.isIOS ? 'IOS' : 'ANDROID',
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

bool isSafeRoleDeepLink(Uri uri, AppRole role) {
  final path = uri.path.isEmpty ? '/' : uri.path;
  if (!(path == '/${role.name}' || path.startsWith('/${role.name}/'))) {
    return false;
  }
  if (!uri.isAbsolute) return true;
  final officialWeb =
      uri.scheme == 'https' &&
      (uri.host == 'planext4u.net' || uri.host.endsWith('.planext4u.net'));
  final officialScheme = uri.scheme == 'planext4u-${role.name}';
  return officialWeb || officialScheme;
}

Map<String, String>? _stringData(Map<String, dynamic>? value) {
  if (value == null) return null;
  return {
    for (final entry in value.entries)
      if (entry.value is String) entry.key: entry.value! as String,
  };
}
