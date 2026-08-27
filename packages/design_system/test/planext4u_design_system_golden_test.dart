import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';

void main() {
  const viewports = <String, Size>{
    'phone': Size(390, 844),
    'tablet': Size(768, 1024),
  };
  const brightnesses = <String, Brightness>{
    'light': Brightness.light,
    'dark': Brightness.dark,
  };
  const textScales = <String, double>{'1_0': 1, '1_3': 1.3};

  for (final viewport in viewports.entries) {
    for (final brightness in brightnesses.entries) {
      for (final textScale in textScales.entries) {
        testWidgets(
          'catalogue ${viewport.key} ${brightness.key} ${textScale.key}',
          (tester) async {
            tester.view.physicalSize = viewport.value;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);

            await tester.pumpWidget(
              MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: Planext4uTheme.light,
                darkTheme: Planext4uTheme.dark,
                themeMode: brightness.value == Brightness.dark
                    ? ThemeMode.dark
                    : ThemeMode.light,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(textScale.value)),
                  child: child!,
                ),
                home: const Planext4uWidgetCatalogue(),
              ),
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            await expectLater(
              find.byType(Planext4uWidgetCatalogue),
              matchesGoldenFile(
                'goldens/catalogue_${Platform.operatingSystem}_${viewport.key}_${brightness.key}_${textScale.key}.png',
              ),
            );
          },
        );
      }
    }
  }
}
