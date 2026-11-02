import 'dart:async';

import 'package:flutter/material.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';

import 'account_privacy.dart';
import 'consent.dart';
import 'contact_matching_screen.dart';
import 'device_permissions_screen.dart';
import 'local_app_lock_widgets.dart';

final class AccountPrivacyScreen extends StatefulWidget {
  const AccountPrivacyScreen({required this.controller, super.key});

  final AccountPrivacyController controller;

  @override
  State<AccountPrivacyScreen> createState() => _AccountPrivacyScreenState();
}

class _AccountPrivacyScreenState extends State<AccountPrivacyScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _scheduleLifecycleLoad();
  }

  @override
  void didUpdateWidget(covariant AccountPrivacyScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_changed);
    widget.controller.addListener(_changed);
    _scheduleLifecycleLoad();
  }

  void _scheduleLifecycleLoad() {
    final controller = widget.controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && controller == widget.controller && controller.isActive) {
        unawaited(controller.lifecycle?.load());
      }
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _deactivate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate this account?'),
        content: const Text(
          'This signs out every device. Recover access with a fresh provider sign-in before any scheduled deletion deadline. Security restrictions cannot be removed through recovery.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deactivate account'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await widget.controller.lifecycle?.deactivate();
    }
  }

  Future<void> _export() async {
    final controller = widget.controller;
    final value = await controller.exportAccountData();
    if (!mounted ||
        value == null ||
        controller != widget.controller ||
        !controller.isActive) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Planext4uSpacing.x5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Account export ready',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: Planext4uSpacing.x3),
              SelectableText('Identity ${value.identityId}'),
              Text('${value.sessionCount} sessions'),
              Text('${value.consentCount} consent records'),
              Text('${value.consentHistoryCount} consent history records'),
              Text('${value.vendorApplicationCount} vendor applications'),
              Text('${value.riderProfileCount} rider profiles'),
              Text('Generated ${value.generatedAt.toLocal()}'),
              const SizedBox(height: Planext4uSpacing.x3),
              const Text(
                'Includes your profile, account roles, sessions, consent history and safe vendor/rider onboarding snapshots across countries. The file lists included and excluded data categories.',
              ),
              if (value.document != null) ...[
                const SizedBox(height: Planext4uSpacing.x3),
                const Text(
                  'The JSON file contains personal data. Choose a trusted location. Saved copies remain there until you remove them.',
                ),
                const SizedBox(height: Planext4uSpacing.x3),
                FilledButton.icon(
                  key: const ValueKey('save-account-export'),
                  onPressed: () async {
                    if (!controller.isActive ||
                        controller != widget.controller) {
                      return;
                    }
                    Navigator.pop(context);
                    await controller.saveExport(value);
                  },
                  icon: const Icon(Icons.save_alt),
                  label: const Text('Save JSON file'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _requestDeletion() async {
    var confirmation = '';
    var reason = '';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Schedule account deletion?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Your account will enter a 30-day recovery period. Type DELETE MY ACCOUNT to continue.',
                ),
                const SizedBox(height: Planext4uSpacing.x3),
                TextField(
                  key: const ValueKey('account-deletion-confirmation'),
                  autocorrect: false,
                  enableSuggestions: false,
                  onChanged: (value) =>
                      setDialogState(() => confirmation = value),
                  decoration: const InputDecoration(labelText: 'Confirmation'),
                ),
                TextField(
                  key: const ValueKey('account-deletion-reason'),
                  onChanged: (value) => reason = value,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Reason (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('confirm-account-deletion'),
              onPressed: confirmation == 'DELETE MY ACCOUNT'
                  ? () => Navigator.pop(context, true)
                  : null,
              child: const Text('Schedule deletion'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !mounted) return;
    final value = await widget.controller.requestAccountDeletion(reason);
    if (!mounted || value == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Deletion scheduled for ${value.effectiveAt.toLocal().toString().split(' ').first}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    final lifecycle = widget.controller.lifecycle;
    final busy = state.busy || lifecycle?.busy == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Account privacy')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Planext4uSpacing.x4),
          children: [
            Text(
              'Your data and account',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: Planext4uSpacing.x2),
            const Text(
              'Save your account data or schedule account deletion. Both actions require your active authenticated session.',
            ),
            if (busy) ...[
              const SizedBox(height: Planext4uSpacing.x4),
              const LinearProgressIndicator(),
            ],
            if (state.message != null) ...[
              const SizedBox(height: Planext4uSpacing.x4),
              Card(
                color: state.status == AccountPrivacyStatus.failure
                    ? Theme.of(context).colorScheme.errorContainer
                    : Theme.of(context).colorScheme.secondaryContainer,
                child: ListTile(
                  leading: Icon(
                    state.status == AccountPrivacyStatus.failure
                        ? Icons.error_outline
                        : Icons.check_circle_outline,
                  ),
                  title: Text(state.message!),
                  trailing: IconButton(
                    tooltip: 'Dismiss',
                    onPressed: widget.controller.clearMessage,
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
            ],
            const SizedBox(height: Planext4uSpacing.x4),
            if (widget.controller.consents
                case final ConsentController consents)
              _ConsentChoices(controller: consents),
            if (widget.controller.contacts case final contacts?) ...[
              const SizedBox(height: Planext4uSpacing.x4),
              ContactMatchingCard(controller: contacts),
            ],
            Planext4uSectionCard(
              title: 'Export account data',
              subtitle:
                  'Download your profile, sessions and complete consent history as a JSON file.',
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  key: const ValueKey('export-account-data'),
                  onPressed: busy ? null : _export,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Generate export'),
                ),
              ),
            ),
            const SizedBox(height: Planext4uSpacing.x4),
            Planext4uSectionCard(
              title: 'Device permissions',
              subtitle:
                  'Review Android access to location, camera, microphone and notifications.',
              child: OutlinedButton.icon(
                key: const ValueKey('manage-device-permissions'),
                onPressed: busy
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const DevicePermissionsScreen(),
                        ),
                      ),
                icon: const Icon(Icons.app_settings_alt_outlined),
                label: const Text('Manage device permissions'),
              ),
            ),
            if (widget.controller.appLock case final controller?) ...[
              const SizedBox(height: Planext4uSpacing.x4),
              LocalAppLockSettings(controller: controller),
            ],
            const SizedBox(height: Planext4uSpacing.x4),
            Planext4uSectionCard(
              title: 'Delete account',
              subtitle:
                  'Schedule erasure after the 30-day recovery period. This affects every Planext4u role on this account.',
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const ValueKey('request-account-deletion'),
                  onPressed: busy ? null : _requestDeletion,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('Schedule deletion'),
                ),
              ),
            ),
            if (lifecycle != null) ...[
              const SizedBox(height: Planext4uSpacing.x4),
              if (lifecycle.message != null) Text(lifecycle.message!),
              if (lifecycle.info?.deletion != null)
                Planext4uSectionCard(
                  title: 'Scheduled deletion',
                  subtitle:
                      'Recovery deadline: ${lifecycle.info!.deletion!.effectiveAt.toLocal().toString().split(' ').first}',
                  child: TextButton(
                    onPressed: busy ? null : lifecycle.cancelDeletion,
                    child: const Text('Keep my account'),
                  ),
                ),
              TextButton(
                onPressed: busy ? null : lifecycle.load,
                child: const Text('Refresh account status'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : _deactivate,
                icon: const Icon(Icons.pause_circle_outline),
                label: const Text('Deactivate account'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _ConsentChoices extends StatefulWidget {
  const _ConsentChoices({required this.controller});
  final ConsentController controller;
  @override
  State<_ConsentChoices> createState() => _ConsentChoicesState();
}

class _ConsentChoicesState extends State<_ConsentChoices> {
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _scheduleLoad();
  }

  @override
  void didUpdateWidget(covariant _ConsentChoices oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_changed);
    widget.controller.addListener(_changed);
    _scheduleLoad();
  }

  void _scheduleLoad() {
    final controller = widget.controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && controller == widget.controller) {
        unawaited(_load());
      }
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final controller = widget.controller;
    try {
      await controller.load();
      if (mounted && controller == widget.controller) {
        setState(() => _error = null);
      }
    } catch (_) {
      if (mounted && controller == widget.controller) {
        setState(
          () => _error =
              'Privacy choices could not be synchronized. Local denials still apply. Retry when connected.',
        );
      }
    }
  }

  Future<void> _withdraw(ConsentEvidence value) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.setConsent(
        purpose: value.purpose,
        granted: false,
        policyVersion: value.policyVersion,
      );
    } catch (_) {
      if (mounted) {
        _error =
            'This device has stopped using this consent. Synchronization is pending; retry when connected.';
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Planext4uSectionCard(
    title: 'Privacy choices',
    subtitle:
        'Withdraw a choice here. Allow it again only when the relevant feature explains its current policy. Device permissions are managed separately in Android settings.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.controller.loading) const LinearProgressIndicator(),
        if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
        for (final purpose in ConsentPurpose.values)
          if (widget.controller.evidence[purpose]
              case final ConsentEvidence value)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(switch (purpose) {
                ConsentPurpose.analytics => 'Analytics',
                ConsentPurpose.marketing => 'Marketing',
                ConsentPurpose.locationServiceability => 'Nearby availability',
                ConsentPurpose.locationDelivery => 'Delivery location',
                ConsentPurpose.contactMatching => 'Contact matching',
              }),
              subtitle: Text(
                widget.controller.hasUnconfirmedChange(purpose)
                    ? 'Stopped locally; synchronization pending'
                    : widget.controller.granted(purpose, value.policyVersion)
                    ? 'Allowed'
                    : 'Not allowed on this device',
              ),
              trailing: TextButton(
                key: ValueKey('withdraw-${purpose.wireValue}'),
                onPressed:
                    _busy ||
                        !value.granted &&
                            !widget.controller.hasUnconfirmedChange(purpose)
                    ? null
                    : () => _withdraw(value),
                child: const Text('Withdraw'),
              ),
            ),
        TextButton(
          onPressed: _busy ? null : _load,
          child: const Text('Refresh privacy choices'),
        ),
      ],
    ),
  );
}
