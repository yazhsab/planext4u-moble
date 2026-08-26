import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_config/planext4u_config.dart';
import 'package:planext4u_rider/main.dart';

void main() {
  testWidgets('renders the rider foundation shell', (tester) async {
    await tester.pumpWidget(
      RiderApp(
        config: AppConfig.parse(
          rawEnvironment: 'production',
          rawApiBaseUrl: 'https://api.planext4u.net',
        ),
      ),
    );

    expect(find.text('Rider application'), findsOneWidget);
    expect(find.text('Rider shell ready'), findsOneWidget);
    expect(find.text('PRODUCTION'), findsOneWidget);
  });
}
