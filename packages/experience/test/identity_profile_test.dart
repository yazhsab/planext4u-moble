import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_core/planext4u_core.dart';
import 'package:planext4u_experience/planext4u_experience.dart';
import 'package:planext4u_identity/planext4u_identity.dart';

void main() {
  for (final role in AppRole.values) {
    test(
      '${role.name} profile preserves verified contacts on update',
      () async {
        final remote = _ProfileRemote(role);
        final controller = IdentityProfileController(
          expectedRole: role,
          remote: remote,
        );

        await controller.load();
        await controller.save(
          displayName: '${role.label} Updated',
          locale: 'ta',
          timeZone: 'Asia/Kolkata',
        );

        final profile = controller.state.current!.profile;
        expect(controller.state.status, IdentityProfileStatus.ready);
        expect(profile.displayName, '${role.label} Updated');
        expect(profile.locale, 'ta');
        expect(profile.email, 'profile@example.test');
        expect(profile.phone, '+919876543210');
        expect(profile.version, 2);
        controller.dispose();
      },
    );
  }

  test('profile conflict reloads the authoritative revision', () async {
    final remote = _ProfileRemote(AppRole.vendor)..conflict = true;
    final controller = IdentityProfileController(
      expectedRole: AppRole.vendor,
      remote: remote,
    );
    await controller.load();

    await controller.save(
      displayName: 'Stale vendor edit',
      locale: 'en',
      timeZone: 'Asia/Kolkata',
    );

    expect(controller.state.status, IdentityProfileStatus.conflict);
    expect(controller.state.current?.profile.displayName, 'Server update');
    expect(controller.state.current?.profile.version, 3);
    expect(controller.state.message, contains('another device'));
    controller.dispose();
  });

  test('profile rejects a response outside the application role', () async {
    final controller = IdentityProfileController(
      expectedRole: AppRole.rider,
      remote: _ProfileRemote(AppRole.customer),
    );

    await controller.load();

    expect(controller.state.status, IdentityProfileStatus.failure);
    expect(controller.state.current, isNull);
    controller.dispose();
  });

  testWidgets('profile screen edits only safe account fields', (tester) async {
    final remote = _ProfileRemote(AppRole.customer);
    final controller = IdentityProfileController(
      expectedRole: AppRole.customer,
      remote: remote,
    );
    await tester.pumpWidget(
      MaterialApp(home: IdentityProfileScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('profile@example.test'), findsOneWidget);
    expect(find.text('+919876543210'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    await tester.enterText(
      find.byKey(const ValueKey('identity-profile-display-name')),
      'Customer Updated',
    );
    await tester.tap(find.byKey(const ValueKey('save-identity-profile')));
    await tester.pumpAndSettle();

    expect(controller.state.current?.profile.displayName, 'Customer Updated');
    expect(find.text('Profile changes saved.'), findsOneWidget);
    expect(remote.updatedFields, {
      'display_name': 'Customer Updated',
      'locale': 'en',
      'time_zone': 'Asia/Kolkata',
    });
    controller.dispose();
  });
}

final class _ProfileRemote implements IdentityProfileRemote {
  _ProfileRemote(this.role);

  final AppRole role;
  bool conflict = false;
  int currentCalls = 0;
  Map<String, String> updatedFields = const {};

  @override
  Future<CurrentIdentityProfile> current() async {
    currentCalls++;
    return _current(
      role,
      version: currentCalls > 1 ? 3 : 1,
      displayName: currentCalls > 1 ? 'Server update' : role.label,
    );
  }

  @override
  Future<IdentityProfile> update({
    required IdentityProfile current,
    required String displayName,
    required String locale,
    required String timeZone,
  }) async {
    if (conflict) {
      throw const ApiConflictFailure(
        code: 'IDENTITY_PROFILE_VERSION_CONFLICT',
        message: 'The profile changed.',
        correlationId: 'corr-profile-conflict',
        retryable: false,
      );
    }
    updatedFields = {
      'display_name': displayName,
      'locale': locale,
      'time_zone': timeZone,
    };
    return IdentityProfile(
      displayName: displayName,
      email: current.email,
      phone: current.phone,
      locale: locale,
      timeZone: timeZone,
      version: current.version + 1,
      updatedAt: DateTime.utc(2026, 9, 2),
    );
  }
}

CurrentIdentityProfile _current(
  AppRole role, {
  required int version,
  required String displayName,
}) => CurrentIdentityProfile(
  identityId: 'identity-${role.name}',
  tenantId: 'tenant-1',
  country: 'IN',
  roles: {role},
  profile: IdentityProfile(
    displayName: displayName,
    email: 'profile@example.test',
    phone: '+919876543210',
    locale: planext4uDefaultLocaleCode,
    timeZone: 'Asia/Kolkata',
    version: version,
    updatedAt: DateTime.utc(2026, 9, 1),
  ),
);
