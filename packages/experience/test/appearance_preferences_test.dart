import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_core/planext4u_core.dart';
import 'package:planext4u_experience/planext4u_experience.dart';
import 'package:planext4u_storage/planext4u_storage.dart';

void main() {
  test(
    'appearance preferences accept exactly the nine supported languages',
    () {
      expect(AppearancePreferences.supportedLocaleCodes, hasLength(9));
      expect(
        Planext4uLocalizations.supportedLocales.map(
          (locale) => locale.languageCode,
        ),
        planext4uSupportedLocaleCodes,
      );
      for (final locale in Planext4uLocalizations.supportedLocales) {
        expect(
          () => AppearancePreferences.defaults().copyWith(
            localeCode: locale.languageCode,
          ),
          returnsNormally,
        );
      }
      expect(
        () => AppearancePreferences.defaults().copyWith(localeCode: 'fr'),
        throwsFormatException,
      );
    },
  );

  test(
    'appearance settings persist encrypted and restore after restart',
    () async {
      final records = MemoryBinaryRecordStore();
      final encrypted = EncryptedRecordStore(
        records: records,
        keyProvider: MemoryCacheKeyProvider(),
        namespace: 'appearance-test',
        maxPlaintextBytes: 4096,
      );
      final first = AppearancePreferencesController(
        EncryptedAppearancePreferencesStore(encrypted),
      );
      await first.load();
      await first.setTheme(AppearanceThemePreference.dark);
      await first.setLocale('ta');
      await first.setTextScale(AppearanceTextScalePreference.large);
      await first.setReduceMotion(true);
      await first.setDataSaver(true);

      final raw = await records.read('appearance.preferences');
      expect(raw, isNotNull);
      final envelope = utf8.decode(raw!);
      expect(envelope, isNot(contains('"theme":"DARK"')));
      expect(envelope, isNot(contains('"locale_code":"ta"')));

      final restored = AppearancePreferencesController(
        EncryptedAppearancePreferencesStore(encrypted),
      );
      await restored.load();
      final value = restored.state.preferences;
      expect(value.theme, AppearanceThemePreference.dark);
      expect(value.localeCode, 'ta');
      expect(value.textScale, AppearanceTextScalePreference.large);
      expect(value.reduceMotion, isTrue);
      expect(value.dataSaver, isTrue);
    },
  );

  test('failed writes keep the last applied preference', () async {
    final store = _AppearanceStore()..failWrites = true;
    final controller = AppearancePreferencesController(store);
    await controller.load();

    await controller.setTheme(AppearanceThemePreference.dark);

    expect(controller.state.status, AppearancePreferencesStatus.failure);
    expect(
      controller.state.preferences.theme,
      AppearanceThemePreference.system,
    );
    expect(controller.state.message, contains('were not changed'));
  });

  testWidgets('appearance screen saves motion and data controls', (
    tester,
  ) async {
    final store = _AppearanceStore();
    final controller = AppearancePreferencesController(store);
    await tester.pumpWidget(
      MaterialApp(home: AppearancePreferencesScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('appearance-preferences-list')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    final motion = find.byKey(const ValueKey('appearance-reduce-motion'));
    expect(motion, findsOneWidget);
    await tester.tap(motion);
    await tester.pumpAndSettle();
    expect(controller.state.preferences.reduceMotion, isTrue);

    final dataSaver = find.byKey(const ValueKey('appearance-data-saver'));
    expect(dataSaver, findsOneWidget);
    await tester.tap(dataSaver);
    await tester.pumpAndSettle();
    expect(controller.state.preferences.dataSaver, isTrue);
    expect(store.writes, hasLength(2));
  });

  testWidgets('appearance settings fit a narrow device at 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final controller = AppearancePreferencesController(_AppearanceStore());

    await tester.pumpWidget(
      MaterialApp(home: AppearancePreferencesScreen(controller: controller)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    for (var index = 0; index < 4; index++) {
      await tester.drag(
        find.byKey(const ValueKey('appearance-preferences-list')),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}

final class _AppearanceStore implements AppearancePreferencesStore {
  AppearancePreferences? value;
  bool failWrites = false;
  final List<AppearancePreferences> writes = [];

  @override
  Future<AppearancePreferences?> read() async => value;

  @override
  Future<void> write(AppearancePreferences next) async {
    if (failWrites) throw StateError('synthetic storage failure');
    writes.add(next);
    value = next;
  }
}
