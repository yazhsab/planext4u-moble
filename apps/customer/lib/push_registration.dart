import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_core/planext4u_core.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

abstract interface class PushMessaging implements RolePushMessaging {}

final class FirebasePushMessaging implements PushMessaging {
  FirebasePushMessaging(this._messaging);
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

typedef PushRegistrationStatus = RolePushRegistrationStatus;

/// Customer routing adds typed destination validation to the shared,
/// generation-guarded registration lifecycle used by all three applications.
final class CustomerPushRegistration {
  CustomerPushRegistration({
    required PushMessaging messaging,
    required PushDeviceRemote remote,
    required String platform,
    required String locale,
    required void Function(Uri) onDeepLink,
    this.allowedHost = 'planext4u.net',
    this.allowedScheme = 'planext4u-customer',
    this.onStatusChanged,
  }) {
    _registration = RolePushRegistration(
      messaging: messaging,
      remote: _CustomerPushRemote(remote),
      role: AppRole.customer,
      platform: platform,
      locale: locale,
      allowedHost: allowedHost,
      allowedScheme: allowedScheme,
      onStatusChanged: onStatusChanged,
      onDeepLink: (uri) {
        if (CustomerDeepLink.parse(uri) != null) onDeepLink(uri);
      },
    );
  }
  final String allowedHost;
  final String allowedScheme;
  final void Function(PushRegistrationStatus)? onStatusChanged;
  late final RolePushRegistration _registration;
  PushRegistrationStatus get status => _registration.status;
  Future<void> start() => _registration.start();
  Future<void> retry() => _registration.retry();
  Future<void> refreshAuthorization() => _registration.refreshAuthorization();
  Future<void> dispose({bool unregister = false}) =>
      _registration.dispose(unregister: unregister);
}

final class _CustomerPushRemote implements RolePushDeviceRemote {
  const _CustomerPushRemote(this._remote);
  final PushDeviceRemote _remote;
  @override
  Future<void> register({
    required String token,
    required String platform,
    required String locale,
  }) async {
    await _remote.register(token: token, platform: platform, locale: locale);
  }

  @override
  Future<void> unregister() => _remote.unregister();
}

Map<String, String>? _stringData(Map<String, dynamic>? value) {
  if (value == null) return null;
  return {
    for (final entry in value.entries)
      if (entry.value is String) entry.key: entry.value! as String,
  };
}
