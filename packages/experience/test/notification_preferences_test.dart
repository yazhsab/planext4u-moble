import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

void main() {
  test('notification API uses versioned GET and PUT contracts', () async {
    final transport = _QueueTransport([
      _TransportFixture(200, _preferenceJson(enabled: true, version: 4)),
      _TransportFixture(200, _preferenceJson(enabled: false, version: 5)),
    ]);
    final api = NotificationPreferencesApi(
      ApiClient(
        baseUrl: Uri.parse('https://api.example.test'),
        transport: transport,
        authSession: const _StaticAuthSession(),
        correlationIdFactory: () => 'corr-notification-preference',
      ),
    );
    const key = NotificationPreferenceKey(
      purpose: NotificationPreferencePurpose.transactional,
      channel: NotificationPreferenceChannel.push,
    );

    final current = await api.preference(key);
    final updated = await api.update(current: current, enabled: false);

    expect(updated.version, 5);
    expect(updated.enabled, isFalse);
    expect(transport.requests[0].method, 'GET');
    expect(
      transport.requests[0].url.path,
      '/v1/notification/preferences/TRANSACTIONAL/PUSH',
    );
    expect(transport.requests[1].method, 'PUT');
    expect(jsonDecode(utf8.decode(transport.requests[1].body!)), {
      'enabled': false,
      'expected_version': 4,
    });
  });

  test(
    'controller loads every configurable channel and updates by version',
    () async {
      final remote = _PreferenceRemote();
      final controller = NotificationPreferencesController(remote);

      await controller.load();

      expect(controller.state.status, NotificationPreferencesStatus.ready);
      expect(controller.state.preferences, hasLength(8));
      const key = NotificationPreferenceKey(
        purpose: NotificationPreferencePurpose.transactional,
        channel: NotificationPreferenceChannel.push,
      );
      await controller.setEnabled(key, false);

      expect(remote.updates, [key]);
      expect(controller.state.preferences[key]?.enabled, isFalse);
      expect(controller.state.preferences[key]?.version, 2);
      expect(controller.state.message, 'Push notifications preference saved.');

      await expectLater(
        controller.setEnabled(
          const NotificationPreferenceKey(
            purpose: NotificationPreferencePurpose.security,
            channel: NotificationPreferenceChannel.email,
          ),
          false,
        ),
        throwsFormatException,
      );
    },
  );

  testWidgets(
    'preference screen confirms disabling and keeps security mandatory',
    (tester) async {
      final remote = _PreferenceRemote();
      final controller = NotificationPreferencesController(remote);
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationPreferencesScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Required for account security'), findsNWidgets(4));
      expect(
        find.byKey(const ValueKey('notification-SECURITY-PUSH')),
        findsOneWidget,
      );
      final preference = find.byKey(
        const ValueKey('notification-TRANSACTIONAL-PUSH'),
      );
      await tester.drag(
        find.byKey(const ValueKey('notification-preferences-list')),
        const Offset(0, -520),
      );
      await tester.pumpAndSettle();
      expect(preference, findsOneWidget);
      await tester.tap(preference);
      await tester.pumpAndSettle();

      expect(find.text('Turn off push notifications?'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('confirm-notification-disable')),
      );
      await tester.pumpAndSettle();

      expect(remote.updates.single.value, 'TRANSACTIONAL:PUSH');
      expect(controller.state.message, 'Push notifications preference saved.');
    },
  );
}

final class _PreferenceRemote implements NotificationPreferencesRemote {
  final Map<NotificationPreferenceKey, NotificationPreference> values = {};
  final List<NotificationPreferenceKey> updates = [];

  @override
  Future<NotificationPreference> preference(
    NotificationPreferenceKey key,
  ) async => values.putIfAbsent(
    key,
    () => NotificationPreference(
      subjectId: 'customer-notification-test',
      purpose: key.purpose,
      channel: key.channel,
      enabled: true,
      version: 1,
      updatedAt: DateTime.utc(2026, 9, 1),
    ),
  );

  @override
  Future<NotificationPreference> update({
    required NotificationPreference current,
    required bool enabled,
  }) async {
    updates.add(current.key);
    final updated = NotificationPreference(
      subjectId: current.subjectId,
      purpose: current.purpose,
      channel: current.channel,
      enabled: enabled,
      version: current.version + 1,
      updatedAt: DateTime.utc(2026, 9, 1, 1),
    );
    values[current.key] = updated;
    return updated;
  }
}

final class _StaticAuthSession implements ApiAuthSession {
  const _StaticAuthSession();

  @override
  Future<String?> accessToken() async => 'access-token-preference-test';

  @override
  Future<bool> refresh() async => false;
}

final class _QueueTransport implements ApiTransport {
  _QueueTransport(this.fixtures);

  final List<_TransportFixture> fixtures;
  final List<TransportRequest> requests = [];

  @override
  Future<TransportResponse> send(
    TransportRequest request, {
    required Duration timeout,
    required ApiCancellationToken cancellationToken,
  }) async {
    requests.add(request);
    final fixture = fixtures.removeAt(0);
    return TransportResponse(
      statusCode: fixture.statusCode,
      headers: {'X-Correlation-ID': 'corr-preference-server'},
      body: Uint8List.fromList(utf8.encode(jsonEncode(fixture.body))),
    );
  }
}

final class _TransportFixture {
  const _TransportFixture(this.statusCode, this.body);

  final int statusCode;
  final Object body;
}

Map<String, Object?> _preferenceJson({
  required bool enabled,
  required int version,
}) => {
  'subject_id': 'customer-notification-test',
  'purpose': 'TRANSACTIONAL',
  'channel': 'PUSH',
  'enabled': enabled,
  'version': version,
  'updated_at': '2026-09-01T00:00:00Z',
};
