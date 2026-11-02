import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:planext4u_vendor/main.dart' as app;

import '../../../packages/experience/test_support/published_education_journey.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'normal vendor completes published education and retains native completion after relogin',
    (tester) async {
      await verifyPublishedEducationJourney(
        tester,
        start: app.main,
        shell: find.byType(app.VendorApp),
        role: 'vendor',
        workspace: () {
          final current = tester.widget<app.VendorApp>(
            find.byType(app.VendorApp),
          );
          return (
            education: current.identityProfileController?.education,
            onSignOut: current.onSignOut,
          );
        },
      );
    },
  );
}
