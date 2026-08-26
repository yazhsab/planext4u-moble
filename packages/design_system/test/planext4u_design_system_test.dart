import 'package:flutter/material.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_core/planext4u_core.dart';

void main() {
  test('themes retain approved brand and semantic colours', () {
    expect(Planext4uTheme.light.colorScheme.primary, Planext4uColors.teal);
    expect(Planext4uTheme.light.colorScheme.error, Planext4uColors.danger);
    expect(Planext4uTheme.dark.brightness, Brightness.dark);
  });

  testWidgets('foundation shell exposes role and environment semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Planext4uFoundationApp(
        role: AppRole.customer,
        environmentLabel: 'staging',
      ),
    );

    expect(find.text('Customer application'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Build environment: staging',
      ),
      findsOneWidget,
    );
    expect(find.text('Customer shell ready'), findsOneWidget);
  });
}
