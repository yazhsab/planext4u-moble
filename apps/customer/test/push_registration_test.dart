import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_customer/push_registration.dart';

void main() {
  test('registers, rotates token, deep-links safely and unregisters', () async {
    final messaging = _PushMessaging();
    final remote = _PushRemote();
    final links = <Uri>[];
    final registration = CustomerPushRegistration(
      messaging: messaging,
      remote: remote,
      platform: 'ANDROID',
      locale: 'en',
      onDeepLink: links.add,
    );

    await registration.start();
    expect(remote.tokens, ['fcm_token_initial_00000000000001']);
    expect(links.single.path, '/app/orders/order-001');
    expect(registration.status, PushRegistrationStatus.registered);

    messaging.tokenController.add('fcm_token_rotated_0000000000001');
    messaging.interactionController.add({
      'deep_link': 'https://attacker.example/app/orders/order-002',
    });
    messaging.interactionController.add({
      'deep_link': 'https://planext4u.net/app/orders/order-002',
    });
    await Future<void>.delayed(Duration.zero);
    expect(remote.tokens, [
      'fcm_token_initial_00000000000001',
      'fcm_token_rotated_0000000000001',
    ]);
    expect(links.map((value) => value.path), [
      '/app/orders/order-001',
      '/app/orders/order-002',
    ]);

    await registration.dispose(unregister: true);
    expect(remote.unregistered, isTrue);
    await messaging.dispose();
  });

  test('denied permission does not upload a provider token', () async {
    final messaging = _PushMessaging()..authorized = false;
    final remote = _PushRemote();
    final registration = CustomerPushRegistration(
      messaging: messaging,
      remote: remote,
      platform: 'IOS',
      locale: 'en',
      onDeepLink: (_) {},
    );
    await registration.start();
    expect(remote.tokens, isEmpty);
    expect(registration.status, PushRegistrationStatus.denied);
    await registration.dispose();
    await messaging.dispose();
  });

  test('provider and API failures never break customer startup', () async {
    final messaging = _PushMessaging();
    final remote = _PushRemote()..fail = true;
    final registration = CustomerPushRegistration(
      messaging: messaging,
      remote: remote,
      platform: 'ANDROID',
      locale: 'en',
      onDeepLink: (_) {},
    );

    await expectLater(registration.start(), completes);
    expect(registration.status, PushRegistrationStatus.unavailable);
    remote.fail = false;
    await registration.retry();
    expect(registration.status, PushRegistrationStatus.registered);
    expect(remote.tokens, ['fcm_token_initial_00000000000001']);
    messaging.tokenController.add('fcm_token_rotated_0000000000001');
    await Future<void>.delayed(Duration.zero);
    await expectLater(registration.dispose(unregister: true), completes);
    await messaging.dispose();
  });

  test('uses exact staging host and custom-scheme allowlists', () async {
    final messaging = _PushMessaging()..initial = null;
    final remote = _PushRemote();
    final links = <Uri>[];
    final registration = CustomerPushRegistration(
      messaging: messaging,
      remote: remote,
      platform: 'ANDROID',
      locale: 'en',
      allowedHost: 'staging.planext4u.net',
      allowedScheme: 'planext4u-customer-staging',
      onDeepLink: links.add,
    );
    await registration.start();
    messaging.interactionController.add({
      'deep_link': 'https://evilplanext4u.net/app/orders/order-001',
    });
    messaging.interactionController.add({
      'deep_link':
          'planext4u-customer-staging-evil://open/app/orders/order-001',
    });
    messaging.interactionController.add({
      'deep_link': 'https://staging.planext4u.net/app/orders/order-001',
    });
    messaging.interactionController.add({
      'deep_link': 'planext4u-customer-staging://open/app/orders/order-002',
    });
    await Future<void>.delayed(Duration.zero);
    expect(links, hasLength(2));
    expect(links.first.host, 'staging.planext4u.net');
    expect(links.last.scheme, 'planext4u-customer-staging');
    await registration.dispose();
    await messaging.dispose();
  });
}

final class _PushMessaging implements PushMessaging {
  final tokenController = StreamController<String>.broadcast();
  final interactionController =
      StreamController<Map<String, String>>.broadcast();
  bool authorized = true;
  Map<String, String>? initial = const {
    'deep_link': 'https://planext4u.net/app/orders/order-001',
  };

  @override
  Future<bool> authorize() async => authorized;
  @override
  Future<String?> token() async => 'fcm_token_initial_00000000000001';
  @override
  Stream<String> get tokenRefreshes => tokenController.stream;
  @override
  Future<Map<String, String>?> initialInteraction() async => initial;
  @override
  Stream<Map<String, String>> get interactions => interactionController.stream;

  Future<void> dispose() async {
    await tokenController.close();
    await interactionController.close();
  }
}

final class _PushRemote implements PushDeviceRemote {
  final tokens = <String>[];
  bool unregistered = false;
  bool fail = false;

  @override
  Future<PushDeviceEndpoint> register({
    required String token,
    required String platform,
    required String locale,
  }) async {
    if (fail) throw StateError('notification dependency unavailable');
    tokens.add(token);
    return const PushDeviceEndpoint(
      id: 'device-endpoint-001',
      deviceReference: 'device-reference-001',
      enabled: true,
    );
  }

  @override
  Future<void> unregister() async {
    if (fail) throw StateError('notification dependency unavailable');
    unregistered = true;
  }
}
