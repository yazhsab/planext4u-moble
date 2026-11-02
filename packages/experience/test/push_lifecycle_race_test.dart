import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_core/planext4u_core.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

void main() {
  test(
    'Firebase startup reads notification settings without requesting permission',
    () async {
      final messaging = _FirebaseMessaging();
      final provider = FirebaseRolePushMessaging(messaging);
      expect(await provider.authorize(), true);
      messaging.status = AuthorizationStatus.denied;
      expect(await provider.authorize(), false);
      expect(messaging.reads, 2);
      expect(messaging.requests, 0);
    },
  );
  test(
    'Settings revocation waits for an issued registration, removes it and drops token callbacks',
    () async {
      final messaging = _Messaging();
      final remote = _Remote()..registration = Completer<void>();
      final registration = _registration(messaging, remote, (_) {});
      final start = registration.start();
      await Future<void>.delayed(Duration.zero);
      expect(remote.events, ['register']);
      messaging.authorized = false;
      final refresh = registration.refreshAuthorization();
      remote.registration!.complete();
      await Future.wait([start, refresh]);
      expect(remote.events, ['register', 'unregister']);
      expect(registration.status, RolePushRegistrationStatus.denied);
      messaging.tokens.add('late-revoked-token');
      await Future<void>.delayed(Duration.zero);
      expect(remote.events, ['register', 'unregister']);
      messaging.authorized = true;
      await registration.refreshAuthorization();
      expect(remote.events, ['register', 'unregister', 'register']);
      expect(registration.status, RolePushRegistrationStatus.registered);
      await registration.dispose();
      await messaging.close();
    },
  );
  test('A rotated token beats an older delayed token read', () async {
    final messaging = _Messaging()..tokenResult = Completer<String?>();
    final remote = _Remote();
    final registration = _registration(messaging, remote, (_) {});
    final start = registration.start();
    await Future<void>.delayed(Duration.zero);
    messaging.tokens.add('newer-device-token');
    await Future<void>.delayed(Duration.zero);
    messaging.tokenResult!.complete('obsolete-device-token');
    await start;
    expect(remote.tokens, ['newer-device-token']);
    await registration.dispose();
    await messaging.close();
  });
  test(
    'Settings callbacks after disposal cannot restart registration',
    () async {
      final messaging = _Messaging();
      final remote = _Remote();
      final registration = _registration(messaging, remote, (_) {});
      await registration.start();
      await registration.dispose(unregister: true);
      await registration.refreshAuthorization();
      await registration.retry();
      await registration.start();
      expect(remote.events, ['register', 'unregister']);
      expect(registration.status, RolePushRegistrationStatus.idle);
      await messaging.close();
    },
  );
  test(
    'Failed permission cleanup remains retryable and later regrant can register',
    () async {
      final messaging = _Messaging();
      final remote = _Remote();
      final registration = _registration(messaging, remote, (_) {});
      await registration.start();
      messaging.authorized = false;
      remote.failRemoval = true;
      await registration.refreshAuthorization();
      expect(registration.status, RolePushRegistrationStatus.unavailable);
      expect(remote.events, ['register', 'unregister']);
      remote.failRemoval = false;
      await registration.refreshAuthorization();
      expect(registration.status, RolePushRegistrationStatus.denied);
      messaging.authorized = true;
      await registration.refreshAuthorization();
      expect(registration.status, RolePushRegistrationStatus.registered);
      expect(remote.events, [
        'register',
        'unregister',
        'unregister',
        'register',
      ]);
      await registration.dispose();
      await messaging.close();
    },
  );
  test(
    'permission completion after disposal cannot register or reopen links',
    () async {
      final messaging = _Messaging()..permission = Completer<bool>();
      final remote = _Remote();
      final links = <Uri>[];
      final registration = _registration(messaging, remote, links.add);
      final start = registration.start();
      await Future<void>.delayed(Duration.zero);
      await registration.dispose(unregister: true);
      messaging.permission!.complete(true);
      await start;
      messaging.opened.add({
        'deep_link': 'https://planext4u.net/rider/tasks/old',
      });
      await Future<void>.delayed(Duration.zero);
      expect(remote.events, ['unregister']);
      expect(links, isEmpty);
      expect(registration.status, RolePushRegistrationStatus.idle);
      await messaging.close();
    },
  );

  test(
    'delayed initial interaction cannot open a signed-out workspace',
    () async {
      final messaging = _Messaging()
        ..initial = Completer<Map<String, String>?>();
      final remote = _Remote();
      final links = <Uri>[];
      final registration = _registration(messaging, remote, links.add);
      final start = registration.start();
      await registration.dispose();
      messaging.initial!.complete({
        'deep_link': 'https://planext4u.net/rider/tasks/old',
      });
      await start;
      expect(links, isEmpty);
      expect(remote.events, isEmpty);
      await messaging.close();
    },
  );

  test('logout waits for issued registration and removes it last', () async {
    final messaging = _Messaging();
    final remote = _Remote()..registration = Completer<void>();
    final registration = _registration(messaging, remote, (_) {});
    final start = registration.start();
    await Future<void>.delayed(Duration.zero);
    expect(remote.events, ['register']);
    final end = registration.dispose(unregister: true);
    await Future<void>.delayed(Duration.zero);
    expect(remote.events, ['register']);
    remote.registration!.complete();
    await Future.wait([start, end]);
    expect(remote.events, ['register', 'unregister']);
    expect(registration.status, RolePushRegistrationStatus.idle);
    await messaging.close();
  });
}

RolePushRegistration _registration(
  _Messaging messaging,
  _Remote remote,
  void Function(Uri) opened,
) => RolePushRegistration(
  messaging: messaging,
  remote: remote,
  role: AppRole.rider,
  platform: 'ANDROID',
  onDeepLink: opened,
);

final class _Messaging implements RolePushMessaging {
  final tokens = StreamController<String>.broadcast();
  final opened = StreamController<Map<String, String>>.broadcast();
  Completer<bool>? permission;
  bool authorized = true;
  Completer<String?>? tokenResult;
  Completer<Map<String, String>?>? initial;
  @override
  Future<bool> authorize() => permission?.future ?? Future.value(authorized);
  @override
  Future<String?> token() =>
      tokenResult?.future ?? Future.value('test-device-token');
  @override
  Stream<String> get tokenRefreshes => tokens.stream;
  @override
  Future<Map<String, String>?> initialInteraction() =>
      initial?.future ?? Future.value();
  @override
  Stream<Map<String, String>> get interactions => opened.stream;
  Future<void> close() async {
    await tokens.close();
    await opened.close();
  }
}

final class _Remote implements RolePushDeviceRemote {
  final events = <String>[];
  final tokens = <String>[];
  Completer<void>? registration;
  bool failRemoval = false;
  @override
  Future<void> register({
    required String token,
    required String platform,
    required String locale,
  }) async {
    events.add('register');
    tokens.add(token);
    await registration?.future;
  }

  @override
  Future<void> unregister() async {
    events.add('unregister');
    if (failRemoval) throw StateError('Synthetic unregister outage');
  }
}

final class _FirebaseMessaging extends Fake implements FirebaseMessaging {
  int reads = 0;
  int requests = 0;
  AuthorizationStatus status = AuthorizationStatus.authorized;
  @override
  Future<NotificationSettings> getNotificationSettings() async {
    reads++;
    return _Settings(status);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #requestPermission) requests++;
    return super.noSuchMethod(invocation);
  }
}

final class _Settings extends Fake implements NotificationSettings {
  _Settings(this.authorizationStatus);
  @override
  final AuthorizationStatus authorizationStatus;
}
