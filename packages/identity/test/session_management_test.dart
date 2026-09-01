import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_identity/planext4u_identity.dart';

void main() {
  test('session management uses owned list and DELETE contracts', () async {
    final transport = _QueueTransport([
      _TransportFixture(200, {
        'sessions': [_sessionJson('session-current', current: true)],
      }),
      const _TransportFixture(204, null),
    ]);
    final api = IdentitySessionManagementApi(
      ApiClient(
        baseUrl: Uri.parse('https://api.example.test'),
        transport: transport,
        authSession: const _StaticAuthSession(),
        correlationIdFactory: () => 'corr-session-management',
      ),
    );

    final sessions = await api.sessions();
    await api.revokeSession('session-other');

    expect(sessions.single.current, isTrue);
    expect(transport.requests[0].method, 'GET');
    expect(transport.requests[0].url.path, '/v1/me/sessions');
    expect(transport.requests[1].method, 'DELETE');
    expect(transport.requests[1].url.path, '/v1/me/sessions/session-other');
    expect(transport.requests[1].body, isNull);
  });

  test('controller revokes only a non-current owned active session', () async {
    final remote = _SessionRemote();
    final controller = IdentitySessionManagementController(remote);
    await controller.load();

    expect(controller.state.status, IdentitySessionManagementStatus.ready);
    expect(controller.state.sessions, hasLength(2));
    await controller.revokeSession(controller.state.sessions.last);

    expect(remote.revoked, ['session-other']);
    expect(controller.state.sessions.single.current, isTrue);
    expect(
      controller.state.message,
      'The selected device session was signed out.',
    );
    await expectLater(
      controller.revokeSession(controller.state.sessions.single),
      throwsFormatException,
    );
  });
}

final class _SessionRemote implements IdentitySessionManagementRemote {
  final List<String> revoked = [];

  @override
  Future<List<IdentityDeviceSession>> sessions() async => [
    _session('session-current', current: true),
    _session('session-other'),
  ];

  @override
  Future<void> revokeSession(String sessionId) async => revoked.add(sessionId);
}

final class _StaticAuthSession implements ApiAuthSession {
  const _StaticAuthSession();

  @override
  Future<String?> accessToken() async => 'access-token-session-test';

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
      headers: {'X-Correlation-ID': 'corr-session-server'},
      body: Uint8List.fromList(
        fixture.body == null ? const [] : utf8.encode(jsonEncode(fixture.body)),
      ),
    );
  }
}

final class _TransportFixture {
  const _TransportFixture(this.statusCode, this.body);

  final int statusCode;
  final Object? body;
}

IdentityDeviceSession _session(String id, {bool current = false}) =>
    IdentityDeviceSession(
      id: id,
      deviceReference: 'redacted-device-reference',
      country: 'IN',
      authenticatedAt: DateTime.utc(2026, 8, 1),
      lastSeenAt: DateTime.utc(2026, 9, 1),
      expiresAt: DateTime.utc(2030),
      current: current,
    );

Map<String, Object?> _sessionJson(String id, {required bool current}) => {
  'id': id,
  'device_reference': 'redacted-device-reference',
  'country': 'IN',
  'authenticated_at': '2026-08-01T00:00:00Z',
  'last_seen_at': '2026-09-01T00:00:00Z',
  'expires_at': '2030-01-01T00:00:00Z',
  'current': current,
};
