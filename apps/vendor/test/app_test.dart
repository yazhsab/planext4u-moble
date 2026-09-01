import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_config/planext4u_config.dart';
import 'package:planext4u_experience/planext4u_experience.dart';
import 'package:planext4u_vendor/main.dart';

void main() {
  testWidgets('vendor shell uses the selected supported locale', (
    tester,
  ) async {
    tester.platformDispatcher.localeTestValue = const Locale('ta');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);

    await tester.pumpWidget(
      VendorApp(
        locale: const Locale('ta'),
        config: AppConfig.parse(
          rawEnvironment: 'production',
          rawApiBaseUrl: 'https://api.planext4u.net',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('மேலோட்டம்'), findsWidgets);
    expect(find.text('விற்பனையாளர் • மேலோட்டம்'), findsOneWidget);
  });

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

  testWidgets('full vendor navigation is usable at 200% text', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      VendorApp(
        config: AppConfig.parse(
          rawEnvironment: 'production',
          rawApiBaseUrl: 'https://api.planext4u.net',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.text('Bookings'), findsOneWidget);
    expect(find.text('Promotions'), findsOneWidget);
    expect(find.text('Earnings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
