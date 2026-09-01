import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_experience/planext4u_experience.dart';
import 'package:planext4u_identity/planext4u_identity.dart';

void main() {
  testWidgets('session screen redacts device IDs and revokes another device', (
    tester,
  ) async {
    final remote = _SessionRemote();
    final controller = IdentitySessionManagementController(remote);
    await tester.pumpWidget(
      MaterialApp(
        home: IdentitySessionManagementScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('This device'), findsOneWidget);
    expect(find.text('Other signed-in device'), findsOneWidget);
    expect(find.textContaining('private-device-reference'), findsNothing);
    await tester.tap(find.text('Sign out this device'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-session-revoke')));
    await tester.pumpAndSettle();

    expect(remote.revoked, ['session-other']);
    expect(find.text('Other signed-in device'), findsNothing);
    expect(
      find.text('The selected device session was signed out.'),
      findsOneWidget,
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

IdentityDeviceSession _session(String id, {bool current = false}) =>
    IdentityDeviceSession(
      id: id,
      deviceReference: 'private-device-reference-$id',
      country: 'IN',
      authenticatedAt: DateTime.utc(2026, 8, 1),
      lastSeenAt: DateTime.utc(2026, 9, 1),
      expiresAt: DateTime.utc(2030),
      current: current,
    );
