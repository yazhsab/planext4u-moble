import 'dart:async';

import 'package:flutter/material.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';

import 'catalog.dart';
import 'role_operations.dart';
import 'role_shell.dart';

final class VendorOperationsView extends StatefulWidget {
  const VendorOperationsView({
    required this.controller,
    required this.destination,
    super.key,
  });
  final VendorOperationsController controller;
  final RoleDestination destination;

  @override
  State<VendorOperationsView> createState() => _VendorOperationsViewState();
}

class _VendorOperationsViewState extends State<VendorOperationsView> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    if (widget.controller.state.status == OperationsStatus.idle) {
      unawaited(widget.controller.loadAll());
    }
    if (widget.destination.id == 'earnings') {
      unawaited(widget.controller.loadSettlements());
    }
  }

  @override
  void didUpdateWidget(VendorOperationsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
    if (oldWidget.destination.id != widget.destination.id &&
        widget.destination.id == 'earnings') {
      unawaited(widget.controller.loadSettlements());
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
    if (state.status == OperationsStatus.loading && state.application == null) {
      return const Planext4uStatePanel(
        state: Planext4uViewState.loading,
        title: 'Loading vendor workspace',
        message: 'Restoring your verified business state.',
      );
    }
    return RefreshIndicator(
      onRefresh: widget.destination.id == 'earnings'
          ? widget.controller.loadSettlements
          : widget.controller.loadAll,
      child: ListView(
        key: ValueKey('vendor-${widget.destination.id}-view'),
        padding: const EdgeInsets.all(Planext4uSpacing.x4),
        children: [
          if (state.message != null) _message(state.message!, state.status),
          switch (widget.destination.id) {
            'overview' => _overview(state),
            'orders' => _orders(state),
            'catalog' => _catalog(state),
            'earnings' => _earnings(state),
            'profile' => _profile(state),
            _ => const SizedBox.shrink(),
          },
        ],
      ),
    );
  }

  Widget _message(String message, OperationsStatus status) => MaterialBanner(
    content: Text(message),
    actions: [
      TextButton(
        onPressed: widget.controller.loadAll,
        child: const Text('Retry'),
      ),
    ],
  );

  Widget _overview(VendorOperationsState state) {
    final application = state.application;
    if (application == null) {
      return _VendorRegistrationCard(controller: widget.controller);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _statusHeader(
          application.businessName,
          application.status,
          application.verified,
        ),
        const SizedBox(height: Planext4uSpacing.x4),
        Wrap(
          spacing: Planext4uSpacing.x3,
          runSpacing: Planext4uSpacing.x3,
          children: [
            _metric(
              'Catalog',
              state.dashboard['catalog_items'] ?? state.catalog.length,
            ),
            _metric('Low stock', state.dashboard['low_stock_items'] ?? 0),
            _metric(
              'Open work',
              state.dashboard['open_work_items'] ?? state.work.length,
            ),
            _metric('Points', state.dashboard['points'] ?? 0),
          ],
        ),
        const SizedBox(height: Planext4uSpacing.x4),
        FilledButton.icon(
          onPressed: widget.controller.createPromotion,
          icon: const Icon(Icons.campaign_outlined),
          label: const Text('Create local promotion'),
        ),
        const SizedBox(height: Planext4uSpacing.x2),
        const Text(
          'Analytics are derived from immutable orders and settlement records. No customer contact data is shown here.',
        ),
      ],
    );
  }

  Widget _orders(VendorOperationsState state) {
    if (state.application?.verified != true) {
      return const Planext4uStatePanel(
        state: Planext4uViewState.permissionDenied,
        title: 'Approval required',
        message:
            'Complete KYC, field verification, zones and bank review first.',
      );
    }
    if (state.work.isEmpty) {
      return const Planext4uStatePanel(
        state: Planext4uViewState.empty,
        title: 'No active work',
        message: 'Product, service and food work queues will appear here.',
      );
    }
    return Column(
      children: [
        for (final item in state.work)
          Card(
            child: ListTile(
              title: Text('${item.referenceType} • ${item.status}'),
              subtitle: Text('${item.customerLabel} • ${item.total.display()}'),
              trailing: PopupMenuButton<String>(
                tooltip: 'Available server actions',
                onSelected: (status) =>
                    widget.controller.transitionWork(item, status),
                itemBuilder: (_) => [
                  for (final action in item.allowedActions)
                    PopupMenuItem(
                      value: action,
                      child: Text(action.replaceAll('_', ' ')),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _catalog(VendorOperationsState state) {
    if (state.application?.verified != true) {
      return const Planext4uStatePanel(
        state: Planext4uViewState.permissionDenied,
        title: 'Catalog locked',
        message: 'Admin approval is required before publishing supply.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          key: const ValueKey('vendor-create-catalog'),
          onPressed: () => widget.controller.createCatalog(
            kind: 'SERVICE',
            name: 'Deep cleaning',
            amountMinor: 20000,
          ),
          icon: const Icon(Icons.add),
          label: const Text('Add product, service or food item'),
        ),
        const SizedBox(height: Planext4uSpacing.x3),
        for (final item in state.catalog)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Planext4uSpacing.x3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.name),
                    subtitle: Text(
                      '${item.kind} • ${item.approvalStatus} • ${item.price.display()}\n'
                      'Stock ${item.stock} • revision ${item.revision}',
                    ),
                    isThreeLine: true,
                    trailing: Icon(
                      item.active ? Icons.visibility : Icons.visibility_off,
                    ),
                  ),
                  Wrap(
                    spacing: Planext4uSpacing.x2,
                    children: [
                      OutlinedButton(
                        onPressed: () => widget.controller.setInventory(
                          item,
                          item.stock + 1,
                        ),
                        child: const Text('Update stock'),
                      ),
                      OutlinedButton(
                        onPressed: () => widget.controller.setSchedule(item),
                        child: const Text('Set availability'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _earnings(VendorOperationsState state) => _SettlementView(
    ledger: state.ledger,
    payouts: state.payouts,
    onRequestPayout: widget.controller.requestPayout,
  );

  Widget _profile(VendorOperationsState state) {
    final application = state.application;
    if (application == null) {
      return _VendorRegistrationCard(controller: widget.controller);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _statusHeader(
          application.businessName,
          application.status,
          application.verified,
        ),
        const SizedBox(height: Planext4uSpacing.x4),
        _step(
          '1. Private documents and OCR review',
          '${application.documents.length} uploaded',
          application.documents.isEmpty
              ? widget.controller.submitDocuments
              : null,
        ),
        _step(
          '2. Field visit',
          application.status.contains('FIELD_VISIT')
              ? application.status.replaceAll('_', ' ')
              : 'Scheduled only when policy requires it',
          application.allowedActions.contains('SCHEDULE_FIELD_VISIT')
              ? widget.controller.scheduleFieldVisit
              : null,
        ),
        _step(
          '3. Service zones',
          '${application.zoneCount} configured',
          application.zoneCount == 0 ? widget.controller.configureZone : null,
        ),
        _step(
          '4. Tokenized bank account',
          application.bankStatus.replaceAll('_', ' '),
          application.bankStatus == 'NOT_CONFIGURED'
              ? widget.controller.configureBank
              : null,
        ),
        const ListTile(
          leading: Icon(Icons.support_agent),
          title: Text('Vendor support'),
          subtitle: Text('Open a KYC, catalog, work or payout support case'),
        ),
      ],
    );
  }

  Widget _statusHeader(String title, String status, bool verified) => Card(
    child: ListTile(
      leading: Icon(verified ? Icons.verified : Icons.hourglass_top),
      title: Text(title),
      subtitle: Text(status.replaceAll('_', ' ')),
      trailing: Text(
        'rev ${widget.controller.state.application?.revision ?? 0}',
      ),
    ),
  );

  Widget _metric(String label, Object value) => Semantics(
    label: '$label $value',
    child: SizedBox(
      width: 148,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Planext4uSpacing.x3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$value', style: Theme.of(context).textTheme.titleLarge),
              Text(label),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _step(
    String title,
    String subtitle,
    Future<void> Function()? action,
  ) => Card(
    child: ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: action == null
          ? const Icon(Icons.check_circle_outline)
          : TextButton(onPressed: action, child: const Text('Continue')),
    ),
  );
}

final class _VendorRegistrationCard extends StatefulWidget {
  const _VendorRegistrationCard({required this.controller});
  final VendorOperationsController controller;
  @override
  State<_VendorRegistrationCard> createState() =>
      _VendorRegistrationCardState();
}

class _VendorRegistrationCardState extends State<_VendorRegistrationCard> {
  final _business = TextEditingController(text: 'Planext4u Local Services');
  final _contact = TextEditingController(text: 'Business owner');
  @override
  void dispose() {
    _business.dispose();
    _contact.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(Planext4uSpacing.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Register your business',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: Planext4uSpacing.x3),
          TextField(
            key: const ValueKey('vendor-business-name'),
            controller: _business,
            decoration: const InputDecoration(labelText: 'Business name'),
          ),
          TextField(
            controller: _contact,
            decoration: const InputDecoration(labelText: 'Contact name'),
          ),
          const SizedBox(height: Planext4uSpacing.x3),
          FilledButton(
            key: const ValueKey('vendor-register'),
            onPressed: () => widget.controller.register(
              businessName: _business.text.trim(),
              businessType: 'Local services',
              contactName: _contact.text.trim(),
            ),
            child: const Text('Start verified onboarding'),
          ),
        ],
      ),
    ),
  );
}

final class RiderOperationsView extends StatefulWidget {
  const RiderOperationsView({
    required this.controller,
    required this.destination,
    super.key,
  });
  final RiderOperationsController controller;
  final RoleDestination destination;

  @override
  State<RiderOperationsView> createState() => _RiderOperationsViewState();
}

class _RiderOperationsViewState extends State<RiderOperationsView> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    if (widget.controller.state.status == OperationsStatus.idle) {
      unawaited(widget.controller.load());
    }
    _loadDestination();
  }

  @override
  void didUpdateWidget(RiderOperationsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
    if (oldWidget.destination.id != widget.destination.id) _loadDestination();
  }

  void _loadDestination() {
    if (widget.destination.id == 'assignments') {
      unawaited(widget.controller.refreshTasks());
    } else if (widget.destination.id == 'earnings') {
      unawaited(widget.controller.loadSettlements());
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
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        key: ValueKey('rider-${widget.destination.id}-view'),
        padding: const EdgeInsets.all(Planext4uSpacing.x4),
        children: [
          if (state.message != null)
            MaterialBanner(
              content: Text(state.message!),
              actions: [
                if (state.pendingCommands > 0)
                  TextButton(
                    onPressed: widget.controller.recoverOffline,
                    child: const Text('Sync now'),
                  ),
              ],
            ),
          switch (widget.destination.id) {
            'duty' => _duty(state),
            'assignments' => _assignments(state),
            'earnings' => _SettlementView(
              ledger: state.ledger,
              payouts: state.payouts,
              onRequestPayout: widget.controller.requestPayout,
            ),
            'emergency' => _emergency(),
            'profile' => _profile(state),
            _ => const SizedBox.shrink(),
          },
        ],
      ),
    );
  }

  Future<void> _refresh() => switch (widget.destination.id) {
    'assignments' => widget.controller.refreshTasks(),
    'earnings' => widget.controller.loadSettlements(),
    _ => widget.controller.load(),
  };

  Widget _duty(RiderOperationsState state) {
    final profile = state.profile;
    if (profile == null) {
      return Center(
        child: FilledButton.icon(
          key: const ValueKey('rider-register'),
          onPressed: widget.controller.register,
          icon: const Icon(Icons.badge_outlined),
          label: const Text('Submit rider KYC and bank details'),
        ),
      );
    }
    if (profile.status != 'APPROVED') {
      return Planext4uStatePanel(
        state: Planext4uViewState.empty,
        title: 'Verification in progress',
        message:
            '${profile.status.replaceAll('_', ' ')} • ${profile.vehicleNumber}\n'
            'You can start duty after KYC and bank approval.',
        actionLabel: 'Refresh',
        onAction: widget.controller.load,
      );
    }
    final active = state.duty?.status == 'ACTIVE';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: Card(
            color: active
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            child: ListTile(
              leading: Icon(
                active ? Icons.online_prediction : Icons.offline_bolt_outlined,
              ),
              title: Text(active ? 'You’re on duty' : 'You’re off duty'),
              subtitle: Text(
                active
                    ? 'Zone ${state.duty!.zoneId} • ${state.duty!.activeTasks} active tasks'
                    : 'Go online to receive atomic delivery offers.',
              ),
            ),
          ),
        ),
        const SizedBox(height: Planext4uSpacing.x3),
        FilledButton(
          key: const ValueKey('rider-duty-toggle'),
          onPressed: active
              ? widget.controller.endDuty
              : widget.controller.startDuty,
          child: Text(active ? 'End duty' : 'Start duty'),
        ),
        if (active)
          OutlinedButton.icon(
            onPressed: () => widget.controller.updateLocation(
              latitude: 13.0827,
              longitude: 80.2707,
              accuracyMeters: 8,
            ),
            icon: const Icon(Icons.my_location),
            label: const Text('Share live location while on task'),
          ),
        const SizedBox(height: Planext4uSpacing.x3),
        Text(
          'Location is sent only while on duty, uses monotonic sequence numbers, expires server-side, and pauses when permission is removed.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _assignments(RiderOperationsState state) {
    if (state.pendingCommands > 0) {
      return Column(
        children: [
          ListTile(
            leading: const Icon(Icons.cloud_upload_outlined),
            title: Text('${state.pendingCommands} offline actions pending'),
            subtitle: const Text('They will replay in device sequence order.'),
            trailing: TextButton(
              onPressed: widget.controller.recoverOffline,
              child: const Text('Sync'),
            ),
          ),
          ..._taskCards(state),
        ],
      );
    }
    if (state.offers.isEmpty && state.tasks.isEmpty) {
      return const Planext4uStatePanel(
        state: Planext4uViewState.empty,
        title: 'No delivery tasks',
        message: 'Time-bounded offers and accepted tasks appear here.',
      );
    }
    return Column(children: _taskCards(state));
  }

  List<Widget> _taskCards(RiderOperationsState state) => [
    for (final offer in state.offers)
      _RiderTaskCard(controller: widget.controller, task: offer, offer: true),
    for (final task in state.tasks)
      _RiderTaskCard(controller: widget.controller, task: task),
  ];

  Widget _emergency() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Safety centre', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: Planext4uSpacing.x3),
      FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Emergency support'),
            content: const Text(
              'Your active task, last safe location and rider identity are ready to share with the emergency response team.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Contact support'),
              ),
            ],
          ),
        ),
        icon: const Icon(Icons.emergency),
        label: const Text('Open emergency assistance'),
      ),
      const ListTile(
        leading: Icon(Icons.shield_outlined),
        title: Text('Privacy protected'),
        subtitle: Text(
          'Customer addresses are tokenized and chat contact details are redacted.',
        ),
      ),
    ],
  );

  Widget _profile(RiderOperationsState state) {
    final profile = state.profile;
    if (profile == null) return _duty(state);
    return Column(
      children: [
        CircleAvatar(
          radius: 36,
          child: Text(profile.fullName[0].toUpperCase()),
        ),
        const SizedBox(height: Planext4uSpacing.x3),
        Text(profile.fullName, style: Theme.of(context).textTheme.titleLarge),
        Text('${profile.status} • ${profile.vehicleNumber}'),
        const SizedBox(height: Planext4uSpacing.x4),
        ListTile(
          leading: const Icon(Icons.account_balance_outlined),
          title: const Text('Bank verification'),
          subtitle: Text(profile.bankStatus),
        ),
        ListTile(
          leading: const Icon(Icons.map_outlined),
          title: const Text('Service zones'),
          subtitle: Text(profile.zones.join(', ')),
        ),
        ListTile(
          leading: const Icon(Icons.fact_check_outlined),
          title: const Text('Attendance'),
          subtitle: Text(
            state.duty == null
                ? 'No active session'
                : 'Duty ${state.duty!.status} • last seen ${state.duty!.lastSeenAt.toLocal()}',
          ),
        ),
        const ListTile(
          leading: Icon(Icons.support_agent),
          title: Text('Rider support'),
          subtitle: Text('Tasks, POD, attendance, safety and payout help'),
        ),
      ],
    );
  }
}

final class _RiderTaskCard extends StatelessWidget {
  const _RiderTaskCard({
    required this.controller,
    required this.task,
    this.offer = false,
  });
  final RiderOperationsController controller;
  final RiderTask task;
  final bool offer;

  @override
  Widget build(BuildContext context) {
    final remaining = task.offerRemaining(DateTime.now()).inSeconds;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Planext4uSpacing.x3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                offer ? Icons.timer_outlined : Icons.route_outlined,
              ),
              title: Text(
                '${task.orderType} • ${task.status.replaceAll('_', ' ')}',
              ),
              subtitle: Text(
                '${task.pickupLabel} → ${task.dropoffLabel}\n'
                '${(task.distanceMeters / 1000).toStringAsFixed(1)} km • ${task.earning.display()}',
              ),
              isThreeLine: true,
              trailing: offer
                  ? Semantics(
                      label: '$remaining seconds remaining',
                      child: Text('${remaining}s'),
                    )
                  : null,
            ),
            if (offer)
              FilledButton(
                key: ValueKey('accept-${task.id}'),
                onPressed: remaining > 0 ? () => controller.accept(task) : null,
                child: const Text('Accept delivery'),
              )
            else ...[
              Wrap(
                spacing: Planext4uSpacing.x2,
                children: [
                  if (task.allowedActions.contains('NAVIGATE_PICKUP'))
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.navigation_outlined),
                      label: const Text('Navigate'),
                    ),
                  if (task.allowedActions.contains('MARK_PICKED_UP'))
                    FilledButton(
                      key: ValueKey('pickup-${task.id}'),
                      onPressed: () => controller.pickup(task),
                      child: const Text('Picked up'),
                    ),
                  if (task.allowedActions.contains('COMPLETE'))
                    FilledButton(
                      key: ValueKey('complete-${task.id}'),
                      onPressed: () => _complete(context),
                      child: const Text('Capture POD'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => _chat(context),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Safe chat'),
                  ),
                ],
              ),
              if (task.podAssetId.isNotEmpty)
                const ListTile(
                  leading: Icon(Icons.verified_outlined),
                  title: Text('Delivery evidence verified'),
                  subtitle: Text(
                    'Blurred photo reference stored; raw image is not displayed.',
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _complete(BuildContext context) async {
    final otp = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Proof of delivery'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('delivery-otp'),
              controller: otp,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Customer delivery code',
              ),
            ),
            const Text(
              'A blurred photo reference is uploaded privately. Signature is used only when policy requires it.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('submit-pod'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit securely'),
          ),
        ],
      ),
    );
    if (accepted == true) await controller.complete(task, otp: otp.text);
    otp.dispose();
  }

  Future<void> _chat(BuildContext context) async {
    await controller.openChat(task.orderId);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrderChatScreen(controller: controller),
      ),
    );
  }
}

final class OrderChatScreen extends StatefulWidget {
  const OrderChatScreen({required this.controller, super.key});
  final RiderOperationsController controller;
  @override
  State<OrderChatScreen> createState() => _OrderChatScreenState();
}

class _OrderChatScreenState extends State<OrderChatScreen> {
  final _message = TextEditingController();
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
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
    final conversation = widget.controller.state.conversation;
    final available = conversation?.availableAt(DateTime.now()) ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Order chat')),
      body: SafeArea(
        child: Column(
          children: [
            MaterialBanner(
              content: Text(
                available
                    ? 'Chat is available until ${conversation!.expiresAt.toLocal()}. Contact details are automatically redacted.'
                    : 'This order chat has expired or was blocked.',
              ),
              actions: const [],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(Planext4uSpacing.x4),
                children: [
                  for (final message
                      in conversation?.messages ?? const <ChatMessageRecord>[])
                    ListTile(
                      leading: Icon(
                        message.redacted
                            ? Icons.privacy_tip_outlined
                            : Icons.chat_outlined,
                      ),
                      title: Text(message.body),
                      subtitle: Text(message.createdAt.toLocal().toString()),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Planext4uSpacing.x3),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('chat-message'),
                      controller: _message,
                      enabled: available,
                      decoration: const InputDecoration(labelText: 'Message'),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Send message',
                    onPressed: available
                        ? () async {
                            await widget.controller.sendMessage(_message.text);
                            _message.clear();
                          }
                        : null,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _SettlementView extends StatelessWidget {
  const _SettlementView({
    required this.ledger,
    required this.payouts,
    required this.onRequestPayout,
  });
  final List<SettlementEntry> ledger;
  final List<PayoutRecord> payouts;
  final Future<void> Function() onRequestPayout;

  @override
  Widget build(BuildContext context) {
    final net = ledger.fold<int>(
      0,
      (total, entry) => total + entry.net.amountMinor,
    );
    final currency = ledger.isEmpty ? 'INR' : ledger.first.net.currency;
    final display = CatalogMoney(
      amountMinor: net,
      currency: currency,
    ).display();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Earnings and settlements',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: Planext4uSpacing.x3),
        Card(
          child: ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: Text(display),
            subtitle: const Text('Immutable net ledger balance'),
          ),
        ),
        for (final entry in ledger)
          ExpansionTile(
            title: Text('${entry.kind} • ${entry.net.display()}'),
            subtitle: Text(
              '${entry.referenceId} • ${entry.calculationVersion}',
            ),
            children: [
              ListTile(
                title: const Text('Gross'),
                trailing: Text(entry.gross.display()),
              ),
              ListTile(
                title: const Text('Commission'),
                trailing: Text(entry.commission.display()),
              ),
              ListTile(
                title: const Text('Tax'),
                trailing: Text(entry.tax.display()),
              ),
              ListTile(
                title: const Text('Available'),
                trailing: Text(entry.availableAt.toLocal().toString()),
              ),
            ],
          ),
        if (ledger.isNotEmpty)
          FilledButton(
            key: const ValueKey('request-payout'),
            onPressed: onRequestPayout,
            child: const Text('Request available payout'),
          ),
        const SizedBox(height: Planext4uSpacing.x4),
        Text('Payout status', style: Theme.of(context).textTheme.titleMedium),
        for (final payout in payouts)
          ListTile(
            leading: const Icon(Icons.payments_outlined),
            title: Text(payout.amount.display()),
            subtitle: Text(
              '${payout.status.replaceAll('_', ' ')} • attempt ${payout.attemptCount}',
            ),
          ),
        if (ledger.isEmpty && payouts.isEmpty)
          const Planext4uStatePanel(
            state: Planext4uViewState.empty,
            title: 'No earnings yet',
            message:
                'Completed work will appear with gross, commission, tax and calculation version.',
          ),
      ],
    );
  }
}
