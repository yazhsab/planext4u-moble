import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_config/planext4u_config.dart';
import 'package:planext4u_customer/main.dart';

void main() {
  testWidgets('renders the customer foundation shell', (tester) async {
    await tester.pumpWidget(
      CustomerApp(
        config: AppConfig.parse(
          rawEnvironment: 'development',
          rawApiBaseUrl: 'http://localhost:8080',
        ),
      ),
    );

    expect(find.text('Customer application'), findsOneWidget);
    expect(find.text('Customer shell ready'), findsOneWidget);
    expect(find.text('DEVELOPMENT'), findsOneWidget);
  });
}
