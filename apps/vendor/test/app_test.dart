import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_config/planext4u_config.dart';
import 'package:planext4u_vendor/main.dart';

void main() {
  testWidgets('renders the vendor foundation shell', (tester) async {
    await tester.pumpWidget(
      VendorApp(
        config: AppConfig.parse(
          rawEnvironment: 'staging',
          rawApiBaseUrl: 'https://api.staging.planext4u.net',
        ),
      ),
    );

    expect(find.text('Vendor application'), findsOneWidget);
    expect(find.text('Vendor shell ready'), findsOneWidget);
    expect(find.text('STAGING'), findsOneWidget);
  });
}
