import 'dart:async';

import 'package:flutter/material.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';
import 'package:planext4u_identity/planext4u_identity.dart';

final class IdentitySessionManagementScreen extends StatefulWidget {
  const IdentitySessionManagementScreen({required this.controller, super.key});

  final IdentitySessionManagementController controller;

  @override
  State<IdentitySessionManagementScreen> createState() =>
      _IdentitySessionManagementScreenState();
}

class _IdentitySessionManagementScreenState
    extends State<IdentitySessionManagementScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    if (widget.controller.state.status ==
        IdentitySessionManagementStatus.idle) {
      unawaited(widget.controller.load());
    }
  }

  @override
  void didUpdateWidget(IdentitySessionManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
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
    final hasSessions = state.sessions.isNotEmpty;
    final initialLoading =
        state.status == IdentitySessionManagementStatus.loading && !hasSessions;
    final unavailable =
        state.status == IdentitySessionManagementStatus.offline ||
        state.status == IdentitySessionManagementStatus.failure;
    return Scaffold(
      appBar: AppBar(title: const Text('Signed-in devices')),
      body: SafeArea(
        child: initialLoading
            ? const Planext4uStatePanel(
                state: Planext4uViewState.loading,
                title: 'Loading signed-in devices',
                message: 'Checking redacted session records.',
              )
            : unavailable && !hasSessions
            ? Planext4uStatePanel(
                state: state.status == IdentitySessionManagementStatus.offline
                    ? Planext4uViewState.offline
                    : Planext4uViewState.error,
                title: 'Signed-in devices unavailable',
                message: state.message ?? 'Try again shortly.',
                actionLabel: 'Try again',
                onAction: widget.controller.load,
              )
            : _content(state),
      ),
    );
  }

  Widget _content(IdentitySessionManagementState state) {
    final sessions = [...state.sessions]
      ..sort((left, right) {
        if (left.current != right.current) return left.current ? -1 : 1;
        return right.lastSeenAt.compareTo(left.lastSeenAt);
      });
    return RefreshIndicator(
      onRefresh: widget.controller.load,
      child: ListView(
        key: const ValueKey('identity-session-list'),
        padding: const EdgeInsets.all(Planext4uSpacing.x4),
        children: [
          const Planext4uSectionHeader(
            title: 'Account sessions',
            subtitle:
                'Review recent access and sign out devices you no longer use.',
          ),
          const SizedBox(height: Planext4uSpacing.x3),
          if (state.message != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: Semantics(liveRegion: true, child: Text(state.message!)),
                trailing:
                    state.status == IdentitySessionManagementStatus.offline ||
                        state.status == IdentitySessionManagementStatus.failure
                    ? TextButton(
                        onPressed: widget.controller.load,
                        child: const Text('Retry'),
                      )
                    : null,
              ),
            ),
          if (sessions.isEmpty)
            const Planext4uStatePanel(
              state: Planext4uViewState.empty,
              title: 'No session records',
              message: 'No signed-in device records were returned.',
            )
          else
            for (final session in sessions) _sessionCard(session, state),
          const SizedBox(height: Planext4uSpacing.x2),
          const Text(
            'Device identifiers and authentication credentials are not displayed. Signing out this device is available from the main account menu.',
          ),
        ],
      ),
    );
  }

  Widget _sessionCard(
    IdentityDeviceSession session,
    IdentitySessionManagementState state,
  ) {
    final revoked = session.revokedAt != null;
    final expired = !session.expiresAt.isAfter(DateTime.now().toUtc());
    final active = !revoked && !expired;
    final label = session.current
        ? 'This device'
        : revoked
        ? 'Signed-out device'
        : expired
        ? 'Expired device session'
        : 'Other signed-in device';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Planext4uSpacing.x3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                session.current
                    ? Icons.smartphone
                    : active
                    ? Icons.devices_outlined
                    : Icons.phonelink_erase_outlined,
              ),
              title: Text(label),
              subtitle: Text(
                '${session.country} • last active ${_displayMoment(session.lastSeenAt)}',
              ),
              trailing: Planext4uStatusPill(
                label: session.current
                    ? 'Current'
                    : active
                    ? 'Active'
                    : 'Ended',
                tone: session.current
                    ? Planext4uStatusTone.success
                    : active
                    ? Planext4uStatusTone.info
                    : Planext4uStatusTone.neutral,
              ),
            ),
            Text('Signed in ${_displayMoment(session.authenticatedAt)}'),
            Text('Expires ${_displayMoment(session.expiresAt)}'),
            if (!session.current && active) ...[
              const SizedBox(height: Planext4uSpacing.x2),
              OutlinedButton.icon(
                key: ValueKey('revoke-session-${session.id}'),
                onPressed:
                    state.status == IdentitySessionManagementStatus.revoking
                    ? null
                    : () => _confirmRevoke(session),
                icon: const Icon(Icons.logout),
                label: const Text('Sign out this device'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRevoke(IdentityDeviceSession session) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out this device?'),
        content: const Text(
          'That device will need to authenticate again. This action does not affect the current device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('confirm-session-revoke'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out device'),
          ),
        ],
      ),
    );
    if (accepted == true) await widget.controller.revokeSession(session);
  }

  String _displayMoment(DateTime value) {
    final local = value.toLocal();
    final date = MaterialLocalizations.of(context).formatMediumDate(local);
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return '$date, $time';
  }
}
