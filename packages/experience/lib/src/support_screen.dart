import 'dart:async';

import 'package:flutter/material.dart';
import 'package:planext4u_core/planext4u_core.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';

import 'support.dart';

final class SupportScreen extends StatefulWidget {
  const SupportScreen({required this.controller, super.key});

  final SupportController controller;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _message = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    if (widget.controller.state.status == SupportViewStatus.idle) {
      unawaited(widget.controller.load());
    }
  }

  @override
  void didUpdateWidget(SupportScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _message.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    final selected = state.selected;
    return Scaffold(
      appBar: AppBar(
        leading: selected == null
            ? null
            : IconButton(
                tooltip: 'Back to support tickets',
                onPressed: widget.controller.closeTicket,
                icon: const Icon(Icons.arrow_back),
              ),
        title: Text(
          selected == null
              ? '${widget.controller.role.label} support'
              : selected.subject,
        ),
      ),
      body: selected == null
          ? _ticketList(state)
          : _ticketDetail(state, selected),
      floatingActionButton: selected == null && !state.busy
          ? FloatingActionButton.extended(
              key: const ValueKey('support-create-ticket'),
              onPressed: _createTicket,
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('New ticket'),
            )
          : null,
    );
  }

  Widget _ticketList(SupportState state) {
    if (state.status == SupportViewStatus.loading && state.tickets.isEmpty) {
      return const Planext4uStatePanel(
        state: Planext4uViewState.loading,
        title: 'Loading support tickets',
        message: 'Restoring your role-owned support history.',
      );
    }
    if (state.status == SupportViewStatus.offline && state.tickets.isEmpty) {
      return Planext4uStatePanel(
        state: Planext4uViewState.offline,
        title: 'Support is offline',
        message: state.message ?? 'Reconnect to load support tickets.',
        actionLabel: 'Try again',
        onAction: widget.controller.load,
      );
    }
    if (state.status == SupportViewStatus.failure && state.tickets.isEmpty) {
      return Planext4uStatePanel(
        state: Planext4uViewState.error,
        title: 'Support is unavailable',
        message: state.message ?? 'Support tickets could not be loaded.',
        actionLabel: 'Try again',
        onAction: widget.controller.load,
      );
    }
    if (state.tickets.isEmpty) {
      return const Planext4uStatePanel(
        state: Planext4uViewState.empty,
        title: 'No support tickets',
        message: 'Create a ticket for account, payment or role-specific help.',
      );
    }
    return RefreshIndicator(
      onRefresh: widget.controller.load,
      child: ListView.separated(
        key: const ValueKey('support-ticket-list'),
        padding: const EdgeInsets.fromLTRB(
          Planext4uSpacing.x4,
          Planext4uSpacing.x3,
          Planext4uSpacing.x4,
          96,
        ),
        itemCount: state.tickets.length,
        separatorBuilder: (_, _) => const SizedBox(height: Planext4uSpacing.x2),
        itemBuilder: (context, index) {
          final ticket = state.tickets[index];
          return Card(
            child: ListTile(
              key: ValueKey('support-ticket-${ticket.id}'),
              leading: const Icon(Icons.support_agent_outlined),
              title: Text(ticket.subject),
              subtitle: Text(
                '${ticket.category.label} • ${_displayStatus(ticket.status)}\n'
                '${ticket.messages.length} message${ticket.messages.length == 1 ? '' : 's'}',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => widget.controller.select(ticket.id),
            ),
          );
        },
      ),
    );
  }

  Widget _ticketDetail(SupportState state, SupportTicket ticket) {
    return Column(
      children: [
        if (state.busy) const LinearProgressIndicator(),
        if (state.message != null)
          MaterialBanner(
            content: Text(state.message!),
            actions: [TextButton(onPressed: () {}, child: const Text('OK'))],
          ),
        Expanded(
          child: ListView(
            key: const ValueKey('support-message-list'),
            padding: const EdgeInsets.all(Planext4uSpacing.x4),
            children: [
              Planext4uSectionCard(
                title: ticket.category.label,
                subtitle:
                    '${_displayStatus(ticket.status)} • ${ticket.priority.wireValue.toLowerCase()} priority',
                child: Text(
                  ticket.relatedReference == null
                      ? 'Ticket ${ticket.id}'
                      : 'Reference ${ticket.relatedReference}',
                ),
              ),
              const SizedBox(height: Planext4uSpacing.x3),
              for (final message in ticket.messages)
                Align(
                  alignment: message.author == SupportMessageAuthor.requester
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Card(
                    color: message.author == SupportMessageAuthor.requester
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(Planext4uSpacing.x3),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.author == SupportMessageAuthor.requester
                                  ? 'You'
                                  : 'Planext4u support',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            const SizedBox(height: Planext4uSpacing.x1),
                            Text(message.body),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(Planext4uSpacing.x3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('support-message-input'),
                    controller: _message,
                    enabled:
                        !state.busy &&
                        ticket.status != SupportTicketStatus.closed,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 8000,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      hintText: 'Add details for the support team',
                    ),
                  ),
                ),
                const SizedBox(width: Planext4uSpacing.x2),
                IconButton.filled(
                  key: const ValueKey('support-send-message'),
                  tooltip: 'Send message',
                  onPressed:
                      state.busy || ticket.status == SupportTicketStatus.closed
                      ? null
                      : () async {
                          if (await widget.controller.send(_message.text)) {
                            _message.clear();
                          }
                        },
                  icon: const Icon(Icons.send_outlined),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _createTicket() async {
    final subject = TextEditingController();
    final description = TextEditingController();
    final reference = TextEditingController();
    var category = _roleCategory(widget.controller.role);
    var priority = SupportPriority.normal;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create support ticket'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<SupportCategory>(
                  key: const ValueKey('support-category'),
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: _categories(widget.controller.role)
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => category = value);
                  },
                ),
                TextField(
                  key: const ValueKey('support-subject'),
                  controller: subject,
                  maxLength: 160,
                  decoration: const InputDecoration(labelText: 'Subject'),
                ),
                TextField(
                  key: const ValueKey('support-description'),
                  controller: description,
                  maxLength: 8000,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'What happened?',
                  ),
                ),
                TextField(
                  controller: reference,
                  maxLength: 128,
                  decoration: const InputDecoration(
                    labelText: 'Order, task or payment reference (optional)',
                  ),
                ),
                DropdownButtonFormField<SupportPriority>(
                  initialValue: priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: SupportPriority.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.wireValue.toLowerCase()),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => priority = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('support-submit-ticket'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (submitted == true && mounted) {
      await widget.controller.create(
        category: category,
        subject: subject.text,
        description: description.text,
        relatedReference: reference.text,
        priority: priority,
      );
    }
    subject.dispose();
    description.dispose();
    reference.dispose();
  }
}

SupportCategory _roleCategory(AppRole role) => switch (role) {
  AppRole.vendor => SupportCategory.vendorOperations,
  AppRole.rider => SupportCategory.riderOperations,
  _ => SupportCategory.order,
};

List<SupportCategory> _categories(AppRole role) => [
  SupportCategory.account,
  if (role == AppRole.customer) SupportCategory.order,
  SupportCategory.payment,
  if (role == AppRole.vendor) SupportCategory.vendorOperations,
  if (role == AppRole.rider) SupportCategory.riderOperations,
  SupportCategory.other,
];

String _displayStatus(SupportTicketStatus value) => value.wireValue
    .toLowerCase()
    .split('_')
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');
