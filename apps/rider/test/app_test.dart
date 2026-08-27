import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_config/planext4u_config.dart';
import 'package:planext4u_core/planext4u_core.dart';
import 'package:planext4u_experience/planext4u_experience.dart';
import 'package:planext4u_rider/main.dart';

void main() {
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
}
