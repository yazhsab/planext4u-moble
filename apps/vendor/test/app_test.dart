import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_config/planext4u_config.dart';
import 'package:planext4u_experience/planext4u_experience.dart';
import 'package:planext4u_vendor/main.dart';

void main() {
  testWidgets('renders only permitted and flagged vendor destinations', (
    tester,
  ) async {
    await tester.pumpWidget(
      VendorApp(
        config: AppConfig.parse(
          rawEnvironment: 'staging',
          rawApiBaseUrl: 'https://api.staging.planext4u.net',
        ),
        capabilities: const {
          RoleCapability.vendorOverview,
          RoleCapability.vendorOrders,
          RoleCapability.vendorCatalog,
          RoleCapability.profile,
        },
        featureFlags: const {'vendor_orders': true},
      ),
    );

    expect(find.text('Planext4u Vendor'), findsOneWidget);
    expect(find.text('Overview'), findsWidgets);
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Catalog'), findsNothing);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('STAGING'), findsOneWidget);
  });
}
