import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';

void main() {
  testWidgets('data saver requires an explicit image request', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => Planext4uAdaptiveAppBuilder(
          dataSaver: true,
          child: child ?? const SizedBox.shrink(),
        ),
        home: const Scaffold(
          body: Planext4uNetworkImage(
            url: 'https://images.planext4u.net/synthetic-product.webp',
            semanticLabel: 'Synthetic product',
          ),
        ),
      ),
    );
    expect(find.text('Image paused'), findsOneWidget);
    expect(find.text('Load image'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('adaptive builder propagates reduced motion and focus order', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(accessibleNavigation: true),
        child: MaterialApp(
          builder: (context, child) => Planext4uAdaptiveAppBuilder(
            child: child ?? const SizedBox.shrink(),
          ),
          home: Builder(
            builder: (context) =>
                Text(MediaQuery.disableAnimationsOf(context).toString()),
          ),
        ),
      ),
    );
    expect(find.text('true'), findsOneWidget);
    expect(find.byType(FocusTraversalGroup), findsWidgets);
  });

  testWidgets(
    'user accessibility settings set minimums without shrinking OS text',
    (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.1)),
          child: MaterialApp(
            builder: (context, child) => Planext4uAdaptiveAppBuilder(
              forceReducedMotion: true,
              minimumTextScale: 1.3,
              child: child ?? const SizedBox.shrink(),
            ),
            home: Builder(
              builder: (context) => Text(
                '${MediaQuery.textScalerOf(context).scale(1)}|'
                '${MediaQuery.disableAnimationsOf(context)}',
              ),
            ),
          ),
        ),
      );
      expect(find.text('1.3|true'), findsOneWidget);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: MaterialApp(
            builder: (context, child) => Planext4uAdaptiveAppBuilder(
              minimumTextScale: 1.3,
              child: child ?? const SizedBox.shrink(),
            ),
            home: Builder(
              builder: (context) =>
                  Text('${MediaQuery.textScalerOf(context).scale(1)}'),
            ),
          ),
        ),
      );
      expect(find.text('2.0'), findsOneWidget);
    },
  );
}
