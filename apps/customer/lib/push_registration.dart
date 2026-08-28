import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

abstract interface class PushMessaging {
  Future<bool> authorize();
  Future<String?> token();
  Stream<String> get tokenRefreshes;
  Future<Map<String, String>?> initialInteraction();
  Stream<Map<String, String>> get interactions;
}

final class FirebasePushMessaging implements PushMessaging {
  FirebasePushMessaging(this._messaging);
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

final class PushDeviceEndpoint {
  const PushDeviceEndpoint({
    required this.id,
    required this.deviceReference,
    required this.enabled,
  });
  factory PushDeviceEndpoint.fromJson(Object? value) {
    if (value is! Map<String, Object?> || value.containsKey('token')) {
      throw const FormatException('Push device response is invalid.');
    }
    final id = value['id'];
    final reference = value['device_reference'];
    final enabled = value['enabled'];
    if (id is! String ||
        id.isEmpty ||
        reference is! String ||
        reference.isEmpty ||
        enabled is! bool) {
      throw const FormatException('Push device response is invalid.');
    }
    return PushDeviceEndpoint(
      id: id,
      deviceReference: reference,
      enabled: enabled,
    );
  }
  final String id;
  final String deviceReference;
  final bool enabled;
}

abstract interface class PushDeviceRemote {
  Future<PushDeviceEndpoint> register({
    required String token,
    required String platform,
    required String locale,
  });
  Future<void> unregister();
}

final class PushDeviceApi implements PushDeviceRemote {
  const PushDeviceApi(this._client);
  final ApiClient _client;

  @override
  Future<PushDeviceEndpoint> register({
    required String token,
    required String platform,
    required String locale,
  }) async => (await _client.send(
    ApiRequest.command(
      operation: 'notification.register_current_device',
      method: 'PUT',
      path: '/v1/notifications/devices/current',
      body: {'platform': platform, 'locale': locale, 'token': token},
    ),
    PushDeviceEndpoint.fromJson,
  )).value;

  @override
  Future<void> unregister() async {
    await _client.send(
      ApiRequest.command(
        operation: 'notification.unregister_current_device',
        method: 'DELETE',
        path: '/v1/notifications/devices/current',
        body: null,
      ),
      (_) {},
    );
  }
}

final class CustomerPushRegistration {
  CustomerPushRegistration({
    required PushMessaging messaging,
    required PushDeviceRemote remote,
    required String platform,
    required String locale,
    required void Function(Uri) onDeepLink,
  }) : _messaging = messaging,
       _remote = remote,
       _platform = platform,
       _locale = locale,
       _onDeepLink = onDeepLink;

  final PushMessaging _messaging;
  final PushDeviceRemote _remote;
  final String _platform;
  final String _locale;
  final void Function(Uri) _onDeepLink;
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
      // Push is an optional delivery channel. Startup and authentication must
      // remain usable when Firebase or the notification API is unavailable.
    }
  }

  Future<void> _registerSafely(String token) async {
    try {
      await _remote.register(
        token: token,
        platform: _platform,
        locale: _locale,
      );
    } catch (_) {
      // A future token refresh or the next authenticated launch retries this
      // without exposing the provider token to logs or crash reporting.
    }
  }

  void _handleInteraction(Map<String, String>? data) {
    final raw = data?['deep_link'];
    if (raw == null) return;
    final uri = Uri.tryParse(raw);
    if (uri == null || CustomerDeepLink.parse(uri) == null) return;
    if (uri.isAbsolute &&
        !((uri.scheme == 'https' && uri.host.endsWith('planext4u.net')) ||
            uri.scheme.startsWith('planext4u-customer'))) {
      return;
    }
    _onDeepLink(uri);
  }

  Future<void> dispose({bool unregister = false}) async {
    await _tokens?.cancel();
    await _interactions?.cancel();
    if (unregister) {
      try {
        await _remote.unregister();
      } catch (_) {
        // Server-side session revocation remains authoritative if this
        // best-effort device cleanup cannot reach the notification service.
      }
    }
  }
}

Map<String, String>? _stringData(Map<String, dynamic>? value) {
  if (value == null) return null;
  return {
    for (final entry in value.entries)
      if (entry.value is String) entry.key: entry.value! as String,
  };
}
