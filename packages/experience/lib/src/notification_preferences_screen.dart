import 'dart:async';

import 'package:flutter/material.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';

import 'notification_preferences.dart';

final class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({required this.controller, super.key});

  final NotificationPreferencesController controller;

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    if (widget.controller.state.status == NotificationPreferencesStatus.idle) {
      unawaited(widget.controller.load());
    }
  }

  @override
  void didUpdateWidget(NotificationPreferencesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
      if (widget.controller.state.status ==
          NotificationPreferencesStatus.idle) {
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
    final hasPreferences = state.preferences.isNotEmpty;
    final unavailable =
        state.status == NotificationPreferencesStatus.offline ||
        state.status == NotificationPreferencesStatus.failure;
    return Scaffold(
      appBar: AppBar(title: const Text('Notification preferences')),
      body: SafeArea(
        child:
            state.status == NotificationPreferencesStatus.loading &&
                !hasPreferences
            ? const Planext4uStatePanel(
                state: Planext4uViewState.loading,
                title: 'Loading notification preferences',
                message: 'Checking your server-saved channel choices.',
              )
            : unavailable && !hasPreferences
            ? Planext4uStatePanel(
                state: state.status == NotificationPreferencesStatus.offline
                    ? Planext4uViewState.offline
                    : Planext4uViewState.error,
                title: 'Notification preferences unavailable',
                message: state.message ?? 'Try again shortly.',
                actionLabel: 'Try again',
                onAction: widget.controller.load,
              )
            : _content(state),
      ),
    );
  }

  Widget _content(NotificationPreferencesState state) => RefreshIndicator(
    onRefresh: widget.controller.load,
    child: ListView(
      key: const ValueKey('notification-preferences-list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(Planext4uSpacing.x4),
      children: [
        const Planext4uSectionHeader(
          title: 'Choose how we contact you',
          subtitle:
              'These choices are stored on your account and apply across signed-in devices.',
        ),
        const SizedBox(height: Planext4uSpacing.x3),
        if (state.message != null)
          Card(
            child: ListTile(
              leading: Icon(
                state.status == NotificationPreferencesStatus.offline
                    ? Icons.cloud_off_outlined
                    : Icons.info_outline,
              ),
              title: Semantics(liveRegion: true, child: Text(state.message!)),
              trailing:
                  state.status == NotificationPreferencesStatus.offline ||
                      state.status == NotificationPreferencesStatus.failure
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
        _securityCard(),
        const SizedBox(height: Planext4uSpacing.x3),
        _purposeCard(NotificationPreferencePurpose.transactional, state),
        const SizedBox(height: Planext4uSpacing.x3),
        _purposeCard(NotificationPreferencePurpose.marketing, state),
        const SizedBox(height: Planext4uSpacing.x3),
        const Text(
          'Turning off a channel does not cancel orders, bookings, payouts or account actions. Marketing messages also require separate marketing consent.',
        ),
      ],
    ),
  );

  Widget _securityCard() => Planext4uSectionCard(
    title: NotificationPreferencePurpose.security.label,
    subtitle:
        'Sign-in, privacy and fraud alerts cannot be disabled. They are sent only through supported account channels.',
    child: Column(
      children: [
        for (final channel in NotificationPreferenceChannel.values)
          SwitchListTile.adaptive(
            key: ValueKey('notification-SECURITY-${channel.wireValue}'),
            contentPadding: EdgeInsets.zero,
            secondary: Icon(_channelIcon(channel)),
            title: Text(channel.label),
            subtitle: const Text('Required for account security'),
            value: true,
            onChanged: null,
          ),
      ],
    ),
  );

  Widget _purposeCard(
    NotificationPreferencePurpose purpose,
    NotificationPreferencesState state,
  ) => Planext4uSectionCard(
    title: purpose.label,
    subtitle: purpose == NotificationPreferencePurpose.transactional
        ? 'Delivery, booking, payment, payout and service updates.'
        : 'Optional campaigns, offers and personalised recommendations.',
    child: Column(
      children: [
        for (final channel in NotificationPreferenceChannel.values)
          _preferenceSwitch(
            NotificationPreferenceKey(purpose: purpose, channel: channel),
            state,
          ),
      ],
    ),
  );

  Widget _preferenceSwitch(
    NotificationPreferenceKey key,
    NotificationPreferencesState state,
  ) {
    final preference = state.preferences[key];
    final saving = state.savingKey == key;
    return SwitchListTile.adaptive(
      key: ValueKey(
        'notification-${key.purpose.wireValue}-${key.channel.wireValue}',
      ),
      contentPadding: EdgeInsets.zero,
      secondary: saving
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(_channelIcon(key.channel)),
      title: Text(key.channel.label),
      subtitle: preference == null
          ? const Text('Preference unavailable')
          : Text('Saved on ${_displayDate(preference.updatedAt)}'),
      value: preference?.enabled ?? false,
      onChanged:
          state.status == NotificationPreferencesStatus.ready &&
              preference != null
          ? (enabled) => _change(key, enabled)
          : null,
    );
  }

  Future<void> _change(NotificationPreferenceKey key, bool enabled) async {
    if (!enabled) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Turn off ${key.channel.label.toLowerCase()}?'),
          content: Text(
            key.purpose == NotificationPreferencePurpose.transactional
                ? 'You may miss order, booking, payment or payout updates on this channel. Security alerts stay enabled.'
                : 'Offers and recommendations will stop on this channel. You can turn them on again later.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep enabled'),
            ),
            FilledButton(
              key: const ValueKey('confirm-notification-disable'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Turn off'),
            ),
          ],
        ),
      );
      if (accepted != true) return;
    }
    await widget.controller.setEnabled(key, enabled);
  }

  String _displayDate(DateTime value) =>
      MaterialLocalizations.of(context).formatMediumDate(value.toLocal());

  IconData _channelIcon(NotificationPreferenceChannel channel) =>
      switch (channel) {
        NotificationPreferenceChannel.push => Icons.notifications_outlined,
        NotificationPreferenceChannel.inApp => Icons.inbox_outlined,
        NotificationPreferenceChannel.email => Icons.email_outlined,
        NotificationPreferenceChannel.whatsApp => Icons.chat_outlined,
      };
}
