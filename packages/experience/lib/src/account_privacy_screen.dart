import 'package:flutter/material.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';

import 'account_privacy.dart';

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
  }

  @override
  void didUpdateWidget(covariant AccountPrivacyScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_changed);
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _export() async {
    final value = await widget.controller.exportAccountData();
    if (!mounted || value == null) return;
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
              Text('Generated ${value.generatedAt.toLocal()}'),
              const SizedBox(height: Planext4uSpacing.x3),
              const Text(
                'The authenticated response contains no access tokens, provider credentials or raw device identifiers.',
              ),
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
              'Export a privacy-safe account summary or schedule account deletion. Both actions require your active authenticated session.',
            ),
            if (state.busy) ...[
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
            Planext4uSectionCard(
              title: 'Export account data',
              subtitle:
                  'Generate a redacted summary of your profile, sessions and consent evidence.',
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  key: const ValueKey('export-account-data'),
                  onPressed: state.busy ? null : _export,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Generate export'),
                ),
              ),
            ),
            const SizedBox(height: Planext4uSpacing.x4),
            Planext4uSectionCard(
              title: 'Delete account',
              subtitle:
                  'Schedule erasure after the 30-day recovery period. This affects every Planext4u role on this account.',
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const ValueKey('request-account-deletion'),
                  onPressed: state.busy ? null : _requestDeletion,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('Schedule deletion'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
