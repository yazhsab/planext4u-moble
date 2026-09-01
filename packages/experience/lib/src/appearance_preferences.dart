import 'package:flutter/material.dart';
import 'package:planext4u_storage/planext4u_storage.dart';

import 'localization.dart';

enum AppearanceThemePreference {
  system('SYSTEM', 'Use device setting'),
  light('LIGHT', 'Light'),
  dark('DARK', 'Dark');

  const AppearanceThemePreference(this.wireValue, this.label);

  final String wireValue;
  final String label;

  ThemeMode get themeMode => switch (this) {
    AppearanceThemePreference.system => ThemeMode.system,
    AppearanceThemePreference.light => ThemeMode.light,
    AppearanceThemePreference.dark => ThemeMode.dark,
  };
}

enum AppearanceTextScalePreference {
  system('SYSTEM', 'Use device text size', 1),
  large('LARGE', 'Large — at least 130%', 1.3),
  extraLarge('EXTRA_LARGE', 'Extra large — at least 200%', 2);

  const AppearanceTextScalePreference(
    this.wireValue,
    this.label,
    this.minimumScale,
  );

  final String wireValue;
  final String label;
  final double minimumScale;
}

final class AppearancePreferences {
  AppearancePreferences({
    required this.theme,
    required this.textScale,
    required this.reduceMotion,
    required this.dataSaver,
    this.localeCode,
  }) {
    if (localeCode != null && !supportedLocaleCodes.contains(localeCode)) {
      throw const FormatException('Appearance locale is unsupported.');
    }
  }

  factory AppearancePreferences.defaults() => AppearancePreferences(
    theme: AppearanceThemePreference.system,
    textScale: AppearanceTextScalePreference.system,
    reduceMotion: false,
    dataSaver: false,
  );

  factory AppearancePreferences.fromJson(Object? value) {
    if (value is! Map<String, Object?> || value['schema'] != 1) {
      throw const FormatException('Appearance preferences are invalid.');
    }
    final theme = AppearanceThemePreference.values.where(
      (item) => item.wireValue == value['theme'],
    );
    final textScale = AppearanceTextScalePreference.values.where(
      (item) => item.wireValue == value['text_scale'],
    );
    final localeCode = value['locale_code'];
    if (theme.length != 1 ||
        textScale.length != 1 ||
        localeCode is! String? ||
        value['reduce_motion'] is! bool ||
        value['data_saver'] is! bool) {
      throw const FormatException('Appearance preferences are invalid.');
    }
    return AppearancePreferences(
      theme: theme.single,
      localeCode: localeCode,
      textScale: textScale.single,
      reduceMotion: value['reduce_motion']! as bool,
      dataSaver: value['data_saver']! as bool,
    );
  }

  static final Set<String> supportedLocaleCodes = Set.unmodifiable(
    Planext4uLocalizations.supportedLocales.map((value) => value.languageCode),
  );

  final AppearanceThemePreference theme;
  final String? localeCode;
  final AppearanceTextScalePreference textScale;
  final bool reduceMotion;
  final bool dataSaver;

  ThemeMode get themeMode => theme.themeMode;
  Locale? get locale => localeCode == null ? null : Locale(localeCode!);

  AppearancePreferences copyWith({
    AppearanceThemePreference? theme,
    Object? localeCode = _unchangedLocale,
    AppearanceTextScalePreference? textScale,
    bool? reduceMotion,
    bool? dataSaver,
  }) => AppearancePreferences(
    theme: theme ?? this.theme,
    localeCode: identical(localeCode, _unchangedLocale)
        ? this.localeCode
        : localeCode as String?,
    textScale: textScale ?? this.textScale,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    dataSaver: dataSaver ?? this.dataSaver,
  );

  Map<String, Object?> toJson() => {
    'schema': 1,
    'theme': theme.wireValue,
    'locale_code': localeCode,
    'text_scale': textScale.wireValue,
    'reduce_motion': reduceMotion,
    'data_saver': dataSaver,
  };
}

const _unchangedLocale = Object();

abstract interface class AppearancePreferencesStore {
  Future<AppearancePreferences?> read();

  Future<void> write(AppearancePreferences value);
}

final class EncryptedAppearancePreferencesStore
    implements AppearancePreferencesStore {
  EncryptedAppearancePreferencesStore(this._store);

  factory EncryptedAppearancePreferencesStore.platform({
    required String namespace,
  }) => EncryptedAppearancePreferencesStore(
    EncryptedRecordStore(
      records: FileBinaryRecordStore(namespace: namespace),
      keyProvider: PlatformCacheKeyProvider(namespace: namespace),
      namespace: namespace,
      maxPlaintextBytes: 4096,
    ),
  );

  static const _recordKey = 'appearance.preferences';
  final EncryptedRecordStore _store;

  @override
  Future<AppearancePreferences?> read() async =>
      (await _store.get(_recordKey, AppearancePreferences.fromJson)).value;

  @override
  Future<void> write(AppearancePreferences value) {
    final now = DateTime.now().toUtc();
    final retention = now.add(const Duration(days: 3650));
    return _store.put(
      _recordKey,
      value.toJson(),
      expiresAt: retention,
      staleUntil: retention,
    );
  }
}

enum AppearancePreferencesStatus { idle, loading, ready, saving, failure }

final class AppearancePreferencesState {
  AppearancePreferencesState({
    AppearancePreferences? preferences,
    this.status = AppearancePreferencesStatus.idle,
    this.message,
  }) : preferences = preferences ?? AppearancePreferences.defaults();

  final AppearancePreferences preferences;
  final AppearancePreferencesStatus status;
  final String? message;

  bool get busy =>
      status == AppearancePreferencesStatus.loading ||
      status == AppearancePreferencesStatus.saving;
}

final class AppearancePreferencesController extends ChangeNotifier {
  AppearancePreferencesController(this._store);

  factory AppearancePreferencesController.platform({
    required String namespace,
  }) => AppearancePreferencesController(
    EncryptedAppearancePreferencesStore.platform(namespace: namespace),
  );

  final AppearancePreferencesStore _store;
  AppearancePreferencesState _state = AppearancePreferencesState();

  AppearancePreferencesState get state => _state;

  Future<void> load() async {
    if (_state.busy) return;
    _set(
      AppearancePreferencesState(
        preferences: _state.preferences,
        status: AppearancePreferencesStatus.loading,
      ),
    );
    try {
      final stored = await _store.read();
      _set(
        AppearancePreferencesState(
          preferences: stored ?? AppearancePreferences.defaults(),
          status: AppearancePreferencesStatus.ready,
        ),
      );
    } catch (_) {
      _set(
        AppearancePreferencesState(
          preferences: AppearancePreferences.defaults(),
          status: AppearancePreferencesStatus.failure,
          message:
              'Saved appearance settings could not be restored. Device defaults are active.',
        ),
      );
    }
  }

  Future<void> setTheme(AppearanceThemePreference value) =>
      _save(_state.preferences.copyWith(theme: value));

  Future<void> setLocale(String? value) =>
      _save(_state.preferences.copyWith(localeCode: value));

  Future<void> setTextScale(AppearanceTextScalePreference value) =>
      _save(_state.preferences.copyWith(textScale: value));

  Future<void> setReduceMotion(bool value) =>
      _save(_state.preferences.copyWith(reduceMotion: value));

  Future<void> setDataSaver(bool value) =>
      _save(_state.preferences.copyWith(dataSaver: value));

  void clearMessage() {
    if (_state.message == null) return;
    _set(
      AppearancePreferencesState(
        preferences: _state.preferences,
        status: _state.status,
      ),
    );
  }

  Future<void> _save(AppearancePreferences value) async {
    if (_state.busy || _samePreferences(value, _state.preferences)) return;
    final previous = _state.preferences;
    _set(
      AppearancePreferencesState(
        preferences: previous,
        status: AppearancePreferencesStatus.saving,
      ),
    );
    try {
      await _store.write(value);
      _set(
        AppearancePreferencesState(
          preferences: value,
          status: AppearancePreferencesStatus.ready,
          message: 'Appearance settings saved on this device.',
        ),
      );
    } catch (_) {
      _set(
        AppearancePreferencesState(
          preferences: previous,
          status: AppearancePreferencesStatus.failure,
          message:
              'Appearance settings were not changed. Check device storage and try again.',
        ),
      );
    }
  }

  void _set(AppearancePreferencesState value) {
    _state = value;
    notifyListeners();
  }
}

bool _samePreferences(
  AppearancePreferences left,
  AppearancePreferences right,
) =>
    left.theme == right.theme &&
    left.localeCode == right.localeCode &&
    left.textScale == right.textScale &&
    left.reduceMotion == right.reduceMotion &&
    left.dataSaver == right.dataSaver;
