import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_config/planext4u_config.dart';
import 'package:planext4u_core/planext4u_core.dart';
import 'package:planext4u_experience/planext4u_experience.dart';
import 'package:planext4u_rider/main.dart';

void main() {
  testWidgets('rider shell uses the selected supported locale', (tester) async {
    tester.platformDispatcher.localeTestValue = const Locale('hi');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);

    await tester.pumpWidget(
      RiderApp(
        locale: const Locale('hi'),
        config: AppConfig.parse(
          rawEnvironment: 'production',
          rawApiBaseUrl: 'https://api.planext4u.net',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ड्यूटी'), findsWidgets);
    expect(find.text('Planext4u डिलीवरी सहयोगी'), findsOneWidget);
  });

  testWidgets('denies a cross-role rider session', (tester) async {
    await tester.pumpWidget(
      RiderApp(
        config: AppConfig.parse(
          rawEnvironment: 'production',
          rawApiBaseUrl: 'https://api.planext4u.net',
        ),
        grantedRoles: const {AppRole.vendor},
        capabilities: const {RoleCapability.riderDuty, RoleCapability.profile},
      ),
    );

    expect(find.text('This account can’t use this app'), findsOneWidget);
    expect(find.text('Duty'), findsNothing);
  });

  testWidgets('rider navigation remains usable at 200% text', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      RiderApp(
        config: AppConfig.parse(
          rawEnvironment: 'production',
          rawApiBaseUrl: 'https://api.planext4u.net',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Duty'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
