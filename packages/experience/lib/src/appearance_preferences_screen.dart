import 'dart:async';

import 'package:flutter/material.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';

import 'appearance_preferences.dart';

final class AppearancePreferencesScreen extends StatefulWidget {
  const AppearancePreferencesScreen({required this.controller, super.key});

  final AppearancePreferencesController controller;

  @override
  State<AppearancePreferencesScreen> createState() =>
      _AppearancePreferencesScreenState();
}

class _AppearancePreferencesScreenState
    extends State<AppearancePreferencesScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    if (widget.controller.state.status == AppearancePreferencesStatus.idle) {
      unawaited(widget.controller.load());
    }
  }

  @override
  void didUpdateWidget(AppearancePreferencesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
      if (widget.controller.state.status == AppearancePreferencesStatus.idle) {
        unawaited(widget.controller.load());
      }
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    if (state.status == AppearancePreferencesStatus.loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Appearance and accessibility')),
        body: const SafeArea(
          child: Planext4uStatePanel(
            state: Planext4uViewState.loading,
            title: 'Loading appearance settings',
            message: 'Restoring preferences saved on this device.',
          ),
        ),
      );
    }
    final preferences = state.preferences;
    final enabled = !state.busy;
    return Scaffold(
      appBar: AppBar(title: const Text('Appearance and accessibility')),
      body: SafeArea(
        child: ListView(
          key: const ValueKey('appearance-preferences-list'),
          padding: const EdgeInsets.all(Planext4uSpacing.x4),
          children: [
            const Planext4uSectionHeader(
              title: 'Make the app comfortable to use',
              subtitle:
                  'These settings are private to this device and apply immediately.',
            ),
            const SizedBox(height: Planext4uSpacing.x3),
            if (state.message != null)
              Card(
                child: ListTile(
                  leading: Icon(
                    state.status == AppearancePreferencesStatus.failure
                        ? Icons.warning_amber_outlined
                        : Icons.check_circle_outline,
                  ),
                  title: Semantics(
                    liveRegion: true,
                    child: Text(state.message!),
                  ),
                  trailing: IconButton(
                    tooltip: 'Dismiss message',
                    onPressed: widget.controller.clearMessage,
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
            Planext4uSectionCard(
              title: 'Theme',
              subtitle: 'Choose light, dark, or the device setting.',
              child: SegmentedButton<AppearanceThemePreference>(
                key: const ValueKey('appearance-theme'),
                direction: Axis.vertical,
                segments: [
                  for (final value in AppearanceThemePreference.values)
                    ButtonSegment(
                      value: value,
                      icon: Icon(_themeIcon(value)),
                      label: Text(value.label),
                    ),
                ],
                selected: {preferences.theme},
                onSelectionChanged: enabled
                    ? (values) => widget.controller.setTheme(values.single)
                    : null,
              ),
            ),
            const SizedBox(height: Planext4uSpacing.x3),
            Planext4uSectionCard(
              title: 'Language',
              subtitle:
                  'Use the device language or choose one of nine supported languages.',
              child: DropdownButtonFormField<String>(
                key: ValueKey(
                  'appearance-language-${preferences.localeCode ?? 'SYSTEM'}',
                ),
                initialValue: preferences.localeCode ?? 'SYSTEM',
                isExpanded: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.language_outlined),
                  labelText: 'App language',
                ),
                items: [
                  const DropdownMenuItem(
                    value: 'SYSTEM',
                    child: Text(
                      'Use device language',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  for (final entry in _languages.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: enabled
                    ? (value) => widget.controller.setLocale(
                        value == 'SYSTEM' ? null : value,
                      )
                    : null,
              ),
            ),
            const SizedBox(height: Planext4uSpacing.x3),
            Planext4uSectionCard(
              title: 'Text size',
              subtitle:
                  'Never reduces the device text size; large options set a safe minimum.',
              child: DropdownButtonFormField<AppearanceTextScalePreference>(
                key: ValueKey(
                  'appearance-text-${preferences.textScale.wireValue}',
                ),
                initialValue: preferences.textScale,
                isExpanded: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.text_fields_outlined),
                  labelText: 'Minimum text size',
                ),
                items: [
                  for (final value in AppearanceTextScalePreference.values)
                    DropdownMenuItem(
                      value: value,
                      child: Text(value.label, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: enabled
                    ? (value) {
                        if (value != null) {
                          widget.controller.setTextScale(value);
                        }
                      }
                    : null,
              ),
            ),
            const SizedBox(height: Planext4uSpacing.x3),
            Planext4uSectionCard(
              title: 'Comfort and connectivity',
              subtitle:
                  'These options supplement your operating-system accessibility settings.',
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    key: const ValueKey('appearance-reduce-motion'),
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.motion_photos_off_outlined),
                    title: const Text('Reduce motion'),
                    subtitle: const Text(
                      'Removes non-essential app animation and transitions',
                    ),
                    value: preferences.reduceMotion,
                    onChanged: enabled
                        ? widget.controller.setReduceMotion
                        : null,
                  ),
                  SwitchListTile.adaptive(
                    key: const ValueKey('appearance-data-saver'),
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.data_saver_on_outlined),
                    title: const Text('Data saver'),
                    subtitle: const Text(
                      'Load network images only when you request them',
                    ),
                    value: preferences.dataSaver,
                    onChanged: enabled ? widget.controller.setDataSaver : null,
                  ),
                ],
              ),
            ),
            if (state.status == AppearancePreferencesStatus.saving)
              const Padding(
                padding: EdgeInsets.only(top: Planext4uSpacing.x3),
                child: LinearProgressIndicator(
                  semanticsLabel: 'Saving appearance settings',
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _themeIcon(AppearanceThemePreference value) => switch (value) {
    AppearanceThemePreference.system => Icons.settings_brightness_outlined,
    AppearanceThemePreference.light => Icons.light_mode_outlined,
    AppearanceThemePreference.dark => Icons.dark_mode_outlined,
  };
}

const _languages = <String, String>{
  'en': 'English',
  'ta': 'தமிழ் — Tamil',
  'hi': 'हिन्दी — Hindi',
  'te': 'తెలుగు — Telugu',
  'kn': 'ಕನ್ನಡ — Kannada',
  'ml': 'മലയാളം — Malayalam',
  'mr': 'मराठी — Marathi',
  'bn': 'বাংলা — Bengali',
  'gu': 'ગુજરાતી — Gujarati',
};
