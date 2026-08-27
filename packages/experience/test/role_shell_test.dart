import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_core/planext4u_core.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

void main() {
  test('navigation requires role, capability and an explicit feature flag', () {
    final destinations = RoleNavigationPolicy.destinations(
      applicationRole: AppRole.vendor,
      grantedRoles: {AppRole.vendor},
      capabilities: {
        RoleCapability.vendorOverview,
        RoleCapability.vendorOrders,
        RoleCapability.vendorCatalog,
        RoleCapability.profile,
      },
      featureFlags: {'vendor_orders': true},
    );

    expect(destinations.map((item) => item.id), [
      'overview',
      'orders',
      'profile',
    ]);
  });

  test('cross-role sessions receive no destinations', () {
    expect(
      RoleNavigationPolicy.destinations(
        applicationRole: AppRole.rider,
        grantedRoles: {AppRole.vendor},
        capabilities: RoleCapability.values.toSet(),
        featureFlags: const {'rider_assignments': true},
      ),
      isEmpty,
    );
  });

  testWidgets('role denial never renders privileged navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthenticatedRoleShell(
          applicationRole: AppRole.vendor,
          grantedRoles: const {AppRole.customer},
          capabilities: RoleCapability.values.toSet(),
          featureFlags: const {'vendor_orders': true},
          environmentLabel: 'development',
        ),
      ),
    );

    expect(find.text('This account can’t use this app'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
