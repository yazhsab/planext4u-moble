import 'dart:async';

import 'package:flutter/material.dart';
import 'package:planext4u_core/planext4u_core.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';

import 'identity_profile.dart';

final class IdentityProfileScreen extends StatefulWidget {
  const IdentityProfileScreen({required this.controller, super.key});

  final IdentityProfileController controller;

  @override
  State<IdentityProfileScreen> createState() => _IdentityProfileScreenState();
}

class _IdentityProfileScreenState extends State<IdentityProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayName = TextEditingController();
  final _timeZone = TextEditingController();
  String _locale = planext4uDefaultLocaleCode;
  int? _loadedVersion;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _syncFields();
    if (widget.controller.state.status == IdentityProfileStatus.idle) {
      unawaited(widget.controller.load());
    }
  }

  @override
  void didUpdateWidget(IdentityProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
      _loadedVersion = null;
      _syncFields();
      if (widget.controller.state.status == IdentityProfileStatus.idle) {
        unawaited(widget.controller.load());
      }
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _displayName.dispose();
    _timeZone.dispose();
    super.dispose();
  }

  void _changed() {
    _syncFields();
    if (mounted) setState(() {});
  }

  void _syncFields() {
    final profile = widget.controller.state.current?.profile;
    if (profile == null || profile.version == _loadedVersion) return;
    _loadedVersion = profile.version;
    _displayName.text = profile.displayName;
    _timeZone.text = profile.timeZone;
    _locale = profile.locale;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    final current = state.current;
    if (current == null && state.status == IdentityProfileStatus.loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit profile')),
        body: const SafeArea(
          child: Planext4uStatePanel(
            state: Planext4uViewState.loading,
            title: 'Loading your profile',
            message: 'Checking the latest account revision.',
          ),
        ),
      );
    }
    if (current == null) {
      final offline = state.status == IdentityProfileStatus.offline;
      return Scaffold(
        appBar: AppBar(title: const Text('Edit profile')),
        body: SafeArea(
          child: Planext4uStatePanel(
            state: offline
                ? Planext4uViewState.offline
                : Planext4uViewState.error,
            title: 'Profile unavailable',
            message: state.message ?? 'Try again shortly.',
            actionLabel: 'Try again',
            onAction: widget.controller.load,
          ),
        ),
      );
    }
    final canSave =
        state.status == IdentityProfileStatus.ready ||
        state.status == IdentityProfileStatus.conflict;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            key: const ValueKey('identity-profile-form'),
            padding: const EdgeInsets.all(Planext4uSpacing.x4),
            children: [
              Planext4uSectionHeader(
                title: '${widget.controller.expectedRole.label} profile',
                subtitle:
                    'Only safe profile fields are editable. Contact verification remains server-controlled.',
              ),
              const SizedBox(height: Planext4uSpacing.x4),
              if (state.message != null)
                Card(
                  child: ListTile(
                    leading: Icon(
                      state.status == IdentityProfileStatus.conflict
                          ? Icons.sync_problem_outlined
                          : state.status == IdentityProfileStatus.offline
                          ? Icons.cloud_off_outlined
                          : Icons.check_circle_outline,
                    ),
                    title: Semantics(
                      liveRegion: true,
                      child: Text(state.message!),
                    ),
                    trailing:
                        state.status == IdentityProfileStatus.conflict ||
                            state.status == IdentityProfileStatus.offline ||
                            state.status == IdentityProfileStatus.failure
                        ? TextButton(
                            onPressed: widget.controller.load,
                            child: const Text('Refresh'),
                          )
                        : IconButton(
                            tooltip: 'Dismiss message',
                            onPressed: widget.controller.clearMessage,
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
              TextFormField(
                key: const ValueKey('identity-profile-display-name'),
                controller: _displayName,
                enabled: canSave,
                maxLength: 100,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(labelText: 'Display name'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a display name.'
                    : null,
              ),
              const SizedBox(height: Planext4uSpacing.x3),
              DropdownButtonFormField<String>(
                key: ValueKey(
                  'identity-profile-locale-${current.profile.version}',
                ),
                initialValue: _locale,
                decoration: const InputDecoration(labelText: 'Language'),
                items: [
                  for (final locale in planext4uSupportedLocaleCodes)
                    DropdownMenuItem(
                      value: locale,
                      child: Text(_localeLabel(locale)),
                    ),
                ],
                onChanged: canSave
                    ? (value) {
                        if (value != null) _locale = value;
                      }
                    : null,
              ),
              const SizedBox(height: Planext4uSpacing.x3),
              TextFormField(
                key: const ValueKey('identity-profile-time-zone'),
                controller: _timeZone,
                enabled: canSave,
                maxLength: 64,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Time zone',
                  helperText: 'Use an IANA zone such as Asia/Kolkata.',
                ),
                validator: (value) =>
                    value == null ||
                        value.trim().isEmpty ||
                        !RegExp(r'^[A-Za-z0-9._+\-/]+$').hasMatch(value.trim())
                    ? 'Enter a valid time zone.'
                    : null,
              ),
              const SizedBox(height: Planext4uSpacing.x2),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.email_outlined),
                title: const Text('Verified email'),
                subtitle: Text(current.profile.email ?? 'Not configured'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phone_outlined),
                title: const Text('Verified phone'),
                subtitle: Text(current.profile.phone ?? 'Not configured'),
              ),
              const SizedBox(height: Planext4uSpacing.x3),
              FilledButton.icon(
                key: const ValueKey('save-identity-profile'),
                onPressed: canSave ? _save : null,
                icon: state.status == IdentityProfileStatus.saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Save profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await widget.controller.save(
      displayName: _displayName.text,
      locale: _locale,
      timeZone: _timeZone.text,
    );
  }
}

String _localeLabel(String locale) => switch (locale) {
  'en' => 'English',
  'ta' => 'தமிழ்',
  'hi' => 'हिन्दी',
  'te' => 'తెలుగు',
  'kn' => 'ಕನ್ನಡ',
  'ml' => 'മലയാളം',
  'mr' => 'मराठी',
  'bn' => 'বাংলা',
  'gu' => 'ગુજરાતી',
  _ => locale,
};
