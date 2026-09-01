import 'dart:async';

import 'package:flutter/material.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';
import 'package:planext4u_identity/planext4u_identity.dart';

import 'account_privacy.dart';
import 'account_privacy_screen.dart';
import 'appearance_preferences.dart';
import 'appearance_preferences_screen.dart';
import 'catalog.dart';
import 'notification_preferences.dart';
import 'notification_preferences_screen.dart';
import 'role_operations.dart';
import 'role_shell.dart';
import 'session_management_screen.dart';

typedef RiderEvidenceCapture = Future<String?> Function(RiderTask task);
typedef RiderNavigationAction = Future<void> Function(RiderTask task);

enum _RiderTaskView { offers, active, history }

final class VendorOperationsView extends StatefulWidget {
  const VendorOperationsView({
    required this.controller,
    required this.destination,
    this.sessionManagementController,
    this.notificationPreferencesController,
    this.appearancePreferencesController,
    this.accountPrivacyController,
    super.key,
  });
  final VendorOperationsController controller;
  final RoleDestination destination;
  final IdentitySessionManagementController? sessionManagementController;
  final NotificationPreferencesController? notificationPreferencesController;
  final AppearancePreferencesController? appearancePreferencesController;
  final AccountPrivacyController? accountPrivacyController;

  @override
  State<VendorOperationsView> createState() => _VendorOperationsViewState();
}

class _VendorOperationsViewState extends State<VendorOperationsView> {
  final _catalogName = TextEditingController(text: 'Deep cleaning');
  final _catalogDescription = TextEditingController(
    text: 'Verified home deep-cleaning service',
  );
  final _catalogSku = TextEditingController(text: 'CLEAN-DEEP-001');
  final _catalogAmount = TextEditingController(text: '20000');
  final _promotionTitle = TextEditingController(text: 'Local launch offer');
  final _promotionBudget = TextEditingController(text: '100000');
  final _promotionDays = TextEditingController(text: '7');
  String _catalogKind = 'SERVICE';

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
    _catalogName.dispose();
    _catalogDescription.dispose();
    _catalogSku.dispose();
    _catalogAmount.dispose();
    _promotionTitle.dispose();
    _promotionBudget.dispose();
    _promotionDays.dispose();
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
    if (state.application == null && state.status == OperationsStatus.offline) {
      return Planext4uStatePanel(
        state: Planext4uViewState.offline,
        title: 'Vendor workspace is offline',
        message: 'Reconnect to restore your verified business workspace.',
        actionLabel: 'Try again',
        onAction: widget.controller.loadAll,
      );
    }
    if (state.application == null && state.status == OperationsStatus.failure) {
      return Planext4uStatePanel(
        state: Planext4uViewState.error,
        title: 'Vendor workspace unavailable',
        message: 'The workspace could not be loaded safely.',
        actionLabel: 'Try again',
        onAction: widget.controller.loadAll,
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
            'bookings' => _bookings(state),
            'promotions' => _promotions(state),
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
    final sales = _dashboardSales(state.dashboard);
    final recommendations = switch (state.dashboard['recommendations']) {
      final List<Object?> values => values.whereType<String>().toList(),
      _ => const <String>[],
    };
    final lowStock = state.catalog
        .where((item) => item.stock < 5)
        .toList(growable: false);
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
            _metric('Sales', sales?.display() ?? '—'),
          ],
        ),
        if (recommendations.isNotEmpty) ...[
          const SizedBox(height: Planext4uSpacing.x4),
          Planext4uSectionCard(
            title: 'Recommended next steps',
            subtitle: 'Generated from the latest server dashboard snapshot.',
            child: Column(
              children: [
                for (final recommendation in recommendations)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.tips_and_updates_outlined),
                    title: Text(recommendation),
                  ),
              ],
            ),
          ),
        ],
        if (lowStock.isNotEmpty) ...[
          const SizedBox(height: Planext4uSpacing.x4),
          Planext4uSectionCard(
            title: 'Low-stock inventory',
            subtitle: 'Quantities below five need attention.',
            child: Column(
              children: [
                for (final item in lowStock)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.name),
                    subtitle: Text('SKU ${item.sku}'),
                    trailing: TextButton(
                      onPressed: item.allowedActions.contains('SET_INVENTORY')
                          ? () => _showInventoryDialog(item)
                          : null,
                      child: Text('Stock ${item.stock}'),
                    ),
                  ),
              ],
            ),
          ),
        ],
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

  CatalogMoney? _dashboardSales(Map<String, Object?> dashboard) {
    final value = dashboard['sales'];
    if (value == null) return null;
    try {
      return CatalogMoney.fromJson(value);
    } on FormatException {
      return null;
    }
  }

  Widget _orders(VendorOperationsState state) => _workQueue(
    state,
    title: 'Orders',
    emptyMessage: 'Product and food order work will appear here.',
    include: (item) => !_isBooking(item),
  );

  Widget _bookings(VendorOperationsState state) => _workQueue(
    state,
    title: 'Service bookings',
    emptyMessage: 'Accepted service bookings will appear here.',
    include: _isBooking,
  );

  bool _isBooking(VendorWorkItem item) =>
      item.referenceType.contains('BOOKING') ||
      item.referenceType.contains('SERVICE');

  Widget _workQueue(
    VendorOperationsState state, {
    required String title,
    required String emptyMessage,
    required bool Function(VendorWorkItem item) include,
  }) {
    if (state.application?.verified != true) {
      return const Planext4uStatePanel(
        state: Planext4uViewState.permissionDenied,
        title: 'Approval required',
        message:
            'Complete KYC, field verification, zones and bank review first.',
      );
    }
    final work = state.work.where(include).toList(growable: false);
    if (work.isEmpty) {
      return Planext4uStatePanel(
        state: Planext4uViewState.empty,
        title: 'No active $title',
        message: emptyMessage,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Planext4uSectionHeader(
          title: title,
          subtitle: 'Only server-allowed transitions are available.',
        ),
        const SizedBox(height: Planext4uSpacing.x3),
        for (final item in work)
          Card(
            child: ListTile(
              title: Text('${item.referenceType} • ${item.status}'),
              subtitle: Text(
                '${item.customerLabel} • ${item.total.display()}\n'
                '${item.referenceId.isEmpty ? item.id : item.referenceId}',
              ),
              isThreeLine: true,
              onTap: () => _showWorkDetails(item),
              trailing: item.allowedActions.isEmpty
                  ? const Icon(Icons.chevron_right)
                  : PopupMenuButton<String>(
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

  Future<void> _showWorkDetails(VendorWorkItem item) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              Planext4uSpacing.x4,
              0,
              Planext4uSpacing.x4,
              Planext4uSpacing.x4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${item.referenceType.replaceAll('_', ' ')} details',
                  style: Theme.of(sheetContext).textTheme.headlineSmall,
                ),
                const SizedBox(height: Planext4uSpacing.x3),
                _detailRow('Status', item.status.replaceAll('_', ' ')),
                _detailRow(
                  'Reference',
                  item.referenceId.isEmpty ? item.id : item.referenceId,
                ),
                _detailRow('Customer', item.customerLabel),
                _detailRow('Server total', item.total.display()),
                if (item.updatedAt != null)
                  _detailRow('Last updated', _displayMoment(item.updatedAt!)),
                const SizedBox(height: Planext4uSpacing.x3),
                if (item.allowedActions.isEmpty)
                  const Text('No further actions are available for this work.')
                else ...[
                  Text(
                    'Available actions',
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                  const SizedBox(height: Planext4uSpacing.x2),
                  Wrap(
                    spacing: Planext4uSpacing.x2,
                    runSpacing: Planext4uSpacing.x2,
                    children: [
                      for (final action in item.allowedActions)
                        FilledButton(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            unawaited(
                              widget.controller.transitionWork(item, action),
                            );
                          },
                          child: Text(action.replaceAll('_', ' ')),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      );

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: Planext4uSpacing.x2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
        Expanded(child: SelectableText(value)),
      ],
    ),
  );

  String _displayMoment(DateTime value) {
    final local = value.toLocal();
    final date = MaterialLocalizations.of(context).formatMediumDate(local);
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return '$date, $time';
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
        Planext4uSectionCard(
          title: 'Catalog editor',
          subtitle:
              'Save locally, then sync against the latest server revision.',
          trailing: _draftPill(state.catalogDraftStatus),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _catalogKind,
                decoration: const InputDecoration(labelText: 'Listing type'),
                items: const [
                  DropdownMenuItem(value: 'PRODUCT', child: Text('Product')),
                  DropdownMenuItem(value: 'SERVICE', child: Text('Service')),
                  DropdownMenuItem(value: 'FOOD', child: Text('Food')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _catalogKind = value);
                },
              ),
              const SizedBox(height: Planext4uSpacing.x3),
              Planext4uTextField(label: 'Name', controller: _catalogName),
              const SizedBox(height: Planext4uSpacing.x3),
              TextField(
                controller: _catalogDescription,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: Planext4uSpacing.x3),
              Planext4uTextField(
                label: 'SKU',
                helper: 'Letters, numbers, dot, underscore, colon or dash.',
                controller: _catalogSku,
              ),
              const SizedBox(height: Planext4uSpacing.x3),
              Planext4uTextField(
                label: 'Price in paise',
                helper: 'The server remains authoritative for final pricing.',
                controller: _catalogAmount,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: Planext4uSpacing.x3),
              Wrap(
                spacing: Planext4uSpacing.x2,
                runSpacing: Planext4uSpacing.x2,
                children: [
                  OutlinedButton.icon(
                    onPressed: _saveCatalogDraft,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save draft'),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('vendor-create-catalog'),
                    onPressed:
                        state.catalogDraft == null ||
                            state.catalogDraftStatus ==
                                VendorDraftSyncStatus.syncing
                        ? null
                        : widget.controller.publishCatalogDraft,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('Sync draft'),
                  ),
                ],
              ),
            ],
          ),
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
                      'SKU ${item.sku} • Stock ${item.stock} • revision ${item.revision}',
                    ),
                    isThreeLine: true,
                    trailing: Icon(
                      item.active ? Icons.visibility : Icons.visibility_off,
                    ),
                  ),
                  if (item.description.isNotEmpty) ...[
                    Text(item.description),
                    const SizedBox(height: Planext4uSpacing.x2),
                  ],
                  Text(
                    item.schedules.isEmpty
                        ? 'No availability published'
                        : '${item.schedules.length} availability window${item.schedules.length == 1 ? '' : 's'} published',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: Planext4uSpacing.x2),
                  Wrap(
                    spacing: Planext4uSpacing.x2,
                    runSpacing: Planext4uSpacing.x2,
                    children: [
                      if (item.allowedActions.contains('EDIT'))
                        OutlinedButton.icon(
                          onPressed: () => _showCatalogEditDialog(item),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit listing'),
                        ),
                      if (item.allowedActions.contains('SET_INVENTORY'))
                        OutlinedButton.icon(
                          key: ValueKey('vendor-set-stock-${item.id}'),
                          onPressed: () => _showInventoryDialog(item),
                          icon: const Icon(Icons.inventory_outlined),
                          label: const Text('Set stock'),
                        ),
                      if (item.allowedActions.contains('SET_SCHEDULE'))
                        OutlinedButton.icon(
                          onPressed: () => _showScheduleDialog(item),
                          icon: const Icon(Icons.schedule_outlined),
                          label: const Text('Edit availability'),
                        ),
                      if (state.scheduleDraft?.itemId == item.id)
                        FilledButton(
                          onPressed:
                              state.scheduleDraftStatus ==
                                  VendorDraftSyncStatus.syncing
                              ? null
                              : widget.controller.publishScheduleDraft,
                          child: const Text('Sync availability'),
                        ),
                    ],
                  ),
                  if (state.scheduleDraft?.itemId == item.id) ...[
                    const SizedBox(height: Planext4uSpacing.x2),
                    _draftPill(state.scheduleDraftStatus),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _saveCatalogDraft() {
    final amount = int.tryParse(_catalogAmount.text.trim());
    try {
      widget.controller.saveCatalogDraft(
        kind: _catalogKind,
        name: _catalogName.text,
        description: _catalogDescription.text,
        sku: _catalogSku.text,
        amountMinor: amount ?? 0,
      );
    } on FormatException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a valid name, description, SKU and positive price.',
          ),
        ),
      );
    }
  }

  Future<void> _showCatalogEditDialog(VendorCatalogItem item) async {
    var name = item.name;
    var description = item.description;
    var sku = item.sku;
    var amount = '${item.price.amountMinor}';
    var kind = item.kind;
    var submitting = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Edit catalog listing'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: kind,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'PRODUCT', child: Text('Product')),
                    DropdownMenuItem(value: 'SERVICE', child: Text('Service')),
                    DropdownMenuItem(value: 'FOOD', child: Text('Food')),
                  ],
                  onChanged: submitting
                      ? null
                      : (value) {
                          if (value != null) {
                            setDialogState(() => kind = value);
                          }
                        },
                ),
                TextFormField(
                  initialValue: name,
                  onChanged: (value) => name = value,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextFormField(
                  initialValue: description,
                  onChanged: (value) => description = value,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                TextFormField(
                  initialValue: sku,
                  onChanged: (value) => sku = value,
                  decoration: const InputDecoration(labelText: 'SKU'),
                ),
                TextFormField(
                  initialValue: amount,
                  onChanged: (value) => amount = value,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Price in paise',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('vendor-save-catalog-edit'),
              onPressed: submitting
                  ? null
                  : () async {
                      try {
                        setDialogState(() => submitting = true);
                        await widget.controller.updateCatalog(
                          item: item,
                          kind: kind,
                          name: name,
                          description: description,
                          sku: sku,
                          amountMinor: int.tryParse(amount.trim()) ?? -1,
                          currency: item.price.currency,
                        );
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      } on FormatException {
                        if (dialogContext.mounted) {
                          setDialogState(() => submitting = false);
                          _showVendorInputError(
                            'Enter a valid name, description, SKU and price.',
                          );
                        }
                      }
                    },
              child: Text(submitting ? 'Saving…' : 'Save changes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showInventoryDialog(VendorCatalogItem item) async {
    var stock = '${item.stock}';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Set stock for ${item.name}'),
        content: TextFormField(
          key: const ValueKey('vendor-stock-input'),
          initialValue: stock,
          onChanged: (value) => stock = value,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Available quantity',
            helperText: 'Enter a value from 0 to 1,000,000.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('vendor-save-stock'),
            onPressed: () {
              try {
                widget.controller.setInventory(
                  item,
                  int.tryParse(stock.trim()) ?? -1,
                );
                Navigator.of(dialogContext).pop();
              } on FormatException {
                _showVendorInputError(
                  'Enter an available quantity from 0 to 1,000,000.',
                );
              }
            },
            child: const Text('Save stock'),
          ),
        ],
      ),
    );
  }

  Future<void> _showScheduleDialog(VendorCatalogItem item) async {
    final existing = item.schedules.firstOrNull;
    final schedule = existing is Map<String, Object?>
        ? existing
        : const <String, Object?>{};
    var weekday = switch (schedule['weekday']) {
      final int value when value >= 1 && value <= 7 => value,
      _ => 1,
    };
    var starts = _clockText(schedule['starts_minute'] as int? ?? 540);
    var ends = _clockText(schedule['ends_minute'] as int? ?? 1020);
    var capacity = '${schedule['capacity'] as int? ?? 4}';
    var buffer = '${schedule['buffer_minutes'] as int? ?? 30}';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Availability for ${item.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: weekday,
                  decoration: const InputDecoration(labelText: 'Weekday'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Monday')),
                    DropdownMenuItem(value: 2, child: Text('Tuesday')),
                    DropdownMenuItem(value: 3, child: Text('Wednesday')),
                    DropdownMenuItem(value: 4, child: Text('Thursday')),
                    DropdownMenuItem(value: 5, child: Text('Friday')),
                    DropdownMenuItem(value: 6, child: Text('Saturday')),
                    DropdownMenuItem(value: 7, child: Text('Sunday')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => weekday = value);
                    }
                  },
                ),
                TextFormField(
                  key: const ValueKey('vendor-schedule-start'),
                  initialValue: starts,
                  onChanged: (value) => starts = value,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: 'Start time',
                    hintText: '09:00',
                  ),
                ),
                TextFormField(
                  initialValue: ends,
                  onChanged: (value) => ends = value,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: 'End time',
                    hintText: '17:00',
                  ),
                ),
                TextFormField(
                  initialValue: capacity,
                  onChanged: (value) => capacity = value,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Capacity'),
                ),
                TextFormField(
                  initialValue: buffer,
                  onChanged: (value) => buffer = value,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Buffer minutes',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('vendor-save-schedule'),
              onPressed: () {
                try {
                  widget.controller.saveScheduleDraft(
                    item,
                    schedules: [
                      {
                        'weekday': weekday,
                        'starts_minute': _parseClockMinute(starts),
                        'ends_minute': _parseClockMinute(ends),
                        'time_zone': 'Asia/Kolkata',
                        'capacity': int.tryParse(capacity.trim()) ?? 0,
                        'buffer_minutes': int.tryParse(buffer.trim()) ?? -1,
                      },
                      ...item.schedules
                          .skip(1)
                          .whereType<Map<String, Object?>>(),
                    ],
                  );
                  Navigator.of(dialogContext).pop();
                } on FormatException {
                  _showVendorInputError(
                    'Enter a valid non-overlapping time, capacity and buffer.',
                  );
                }
              },
              child: const Text('Save draft'),
            ),
          ],
        ),
      ),
    );
  }

  int _parseClockMinute(String input) {
    final match = RegExp(r'^([0-9]{1,2}):([0-9]{2})$').firstMatch(input.trim());
    if (match == null) throw const FormatException('Time is invalid.');
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour > 24 || minute > 59 || (hour == 24 && minute != 0)) {
      throw const FormatException('Time is invalid.');
    }
    return hour * 60 + minute;
  }

  String _clockText(int minute) =>
      '${(minute ~/ 60).toString().padLeft(2, '0')}:'
      '${(minute % 60).toString().padLeft(2, '0')}';

  void _showVendorInputError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _promotions(VendorOperationsState state) {
    if (state.application?.verified != true) {
      return const Planext4uStatePanel(
        state: Planext4uViewState.permissionDenied,
        title: 'Promotions locked',
        message: 'Admin approval is required before proposing campaigns.',
      );
    }
    return Planext4uSectionCard(
      title: 'Promotion editor',
      subtitle: 'Budget, eligibility and publication remain server-reviewed.',
      trailing: _draftPill(state.promotionDraftStatus),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Planext4uTextField(
            label: 'Campaign title',
            controller: _promotionTitle,
          ),
          const SizedBox(height: Planext4uSpacing.x3),
          Planext4uTextField(
            label: 'Budget in paise',
            controller: _promotionBudget,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: Planext4uSpacing.x3),
          Planext4uTextField(
            label: 'Duration in days',
            controller: _promotionDays,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: Planext4uSpacing.x3),
          Wrap(
            spacing: Planext4uSpacing.x2,
            runSpacing: Planext4uSpacing.x2,
            children: [
              OutlinedButton.icon(
                onPressed: _savePromotionDraft,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save draft'),
              ),
              FilledButton.icon(
                key: const ValueKey('vendor-publish-promotion'),
                onPressed:
                    state.promotionDraft == null ||
                        state.promotionDraftStatus ==
                            VendorDraftSyncStatus.syncing
                    ? null
                    : widget.controller.publishPromotionDraft,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Submit for review'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _savePromotionDraft() {
    final budget = int.tryParse(_promotionBudget.text.trim());
    final days = int.tryParse(_promotionDays.text.trim());
    try {
      widget.controller.savePromotionDraft(
        title: _promotionTitle.text,
        budgetMinor: budget ?? 0,
        durationDays: days ?? 0,
      );
    } on FormatException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid title, budget and 1–90 day duration.'),
        ),
      );
    }
  }

  Widget _draftPill(VendorDraftSyncStatus status) {
    final (label, tone) = switch (status) {
      VendorDraftSyncStatus.none => ('No draft', Planext4uStatusTone.neutral),
      VendorDraftSyncStatus.draft => (
        'Draft saved',
        Planext4uStatusTone.warning,
      ),
      VendorDraftSyncStatus.syncing => ('Syncing', Planext4uStatusTone.info),
      VendorDraftSyncStatus.synced => ('Synced', Planext4uStatusTone.success),
      VendorDraftSyncStatus.offline => (
        'Saved offline',
        Planext4uStatusTone.warning,
      ),
      VendorDraftSyncStatus.conflict => (
        'Conflict',
        Planext4uStatusTone.danger,
      ),
      VendorDraftSyncStatus.failure => (
        'Needs attention',
        Planext4uStatusTone.danger,
      ),
    };
    return Planext4uStatusPill(label: label, tone: tone);
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
    final completedSteps = [
      application.documents.isNotEmpty,
      application.status.contains('FIELD_VISIT') || application.verified,
      application.zoneCount > 0,
      application.bankStatus != 'NOT_CONFIGURED',
    ].where((value) => value).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _statusHeader(
          application.businessName,
          application.status,
          application.verified,
        ),
        const SizedBox(height: Planext4uSpacing.x4),
        Semantics(
          label: '$completedSteps of 4 onboarding steps saved',
          child: LinearProgressIndicator(value: completedSteps / 4),
        ),
        const SizedBox(height: Planext4uSpacing.x2),
        Text(
          '$completedSteps of 4 revisioned steps saved. You can resume after sign-in.',
        ),
        const SizedBox(height: Planext4uSpacing.x4),
        Planext4uSectionCard(
          title: 'Business identity',
          subtitle: 'Read-only details from the revisioned application.',
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.storefront_outlined),
                title: const Text('Business type'),
                subtitle: Text(
                  application.businessType.isEmpty
                      ? 'Not supplied'
                      : application.businessType,
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline),
                title: const Text('Primary contact'),
                subtitle: Text(
                  application.contactName.isEmpty
                      ? 'Not supplied'
                      : application.contactName,
                ),
              ),
              if (application.updatedAt != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.update_outlined),
                  title: const Text('Application updated'),
                  subtitle: Text(_displayMoment(application.updatedAt!)),
                ),
            ],
          ),
        ),
        const SizedBox(height: Planext4uSpacing.x3),
        _step(
          '1. Private documents and OCR review',
          application.documents.isEmpty
              ? 'Private upload provider required'
              : '${application.documents.length} uploaded',
          completed: application.documents.isNotEmpty,
        ),
        if (application.documentSummaries.isNotEmpty)
          for (final document in application.documentSummaries)
            Card(
              child: ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(document.kind.replaceAll('_', ' ')),
                subtitle: Text(
                  [
                    document.ocrStatus.replaceAll('_', ' '),
                    if (document.reviewReason != null) document.reviewReason!,
                  ].join(' • '),
                ),
              ),
            ),
        _step(
          '2. Field visit',
          application.fieldVisit != null
              ? 'Scheduled ${_displayMoment(application.fieldVisit!.scheduledAt)}'
              : application.status.contains('FIELD_VISIT')
              ? application.status.replaceAll('_', ' ')
              : 'Scheduled only when policy requires it',
          completed:
              application.fieldVisit?.checkedInAt != null ||
              application.status.contains('FIELD_VISIT_PASSED') ||
              application.verified,
          action: application.allowedActions.contains('SCHEDULE_FIELD_VISIT')
              ? widget.controller.scheduleFieldVisit
              : null,
        ),
        _step(
          '3. Service zones',
          application.zoneCount == 0
              ? 'Verified zone provider required'
              : '${application.zoneCount} configured',
          completed: application.zoneCount > 0,
        ),
        if (application.serviceZones.isNotEmpty)
          for (final zone in application.serviceZones)
            Card(
              child: ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: Text(zone.id),
                subtitle: Text(
                  '${zone.postalCodes.join(', ')} • ${zone.radiusKm.toStringAsFixed(1)} km\n'
                  'Policy ${zone.policyVersion}',
                ),
                isThreeLine: true,
              ),
            ),
        _step(
          '4. Tokenized bank account',
          application.bankStatus.replaceAll('_', ' '),
          completed: application.bankStatus != 'NOT_CONFIGURED',
        ),
        if (application.bank != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_balance_outlined),
              title: Text(application.bank!.holderName),
              subtitle: Text(
                'Account ending ${application.bank!.last4} • ${application.bank!.ifsc}\n'
                '${application.bank!.status.replaceAll('_', ' ')}',
              ),
              isThreeLine: true,
            ),
          ),
        if (application.timeline.isNotEmpty) ...[
          const SizedBox(height: Planext4uSpacing.x3),
          Planext4uSectionCard(
            title: 'Application timeline',
            subtitle: 'Latest server-recorded review events.',
            child: Column(
              children: [
                for (final event in application.timeline.reversed.take(6))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history_outlined),
                    title: Text(event.status.replaceAll('_', ' ')),
                    subtitle: Text(
                      [
                        _displayMoment(event.createdAt),
                        if (event.reason != null) event.reason!,
                      ].join(' • '),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const ListTile(
          leading: Icon(Icons.support_agent),
          title: Text('Vendor support'),
          subtitle: Text(
            'Support-case integration is not configured in this build.',
          ),
        ),
        if (widget.notificationPreferencesController != null)
          ListTile(
            key: const ValueKey('vendor-notification-preferences'),
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notification preferences'),
            subtitle: const Text(
              'Choose channels for operations, payouts and offers',
            ),
            onTap: () => _openNotificationPreferences(
              context,
              widget.notificationPreferencesController!,
            ),
          ),
        if (widget.appearancePreferencesController != null)
          ListTile(
            key: const ValueKey('vendor-appearance-preferences'),
            leading: const Icon(Icons.contrast_outlined),
            title: const Text('Appearance and accessibility'),
            subtitle: const Text(
              'Language, theme, text size, motion and data usage',
            ),
            onTap: () => _openAppearancePreferences(
              context,
              widget.appearancePreferencesController!,
            ),
          ),
        if (widget.accountPrivacyController != null)
          ListTile(
            key: const ValueKey('vendor-account-privacy'),
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Account privacy'),
            subtitle: const Text(
              'Export your data or schedule account deletion',
            ),
            onTap: () =>
                _openAccountPrivacy(context, widget.accountPrivacyController!),
          ),
        if (widget.sessionManagementController != null)
          ListTile(
            key: const ValueKey('vendor-signed-in-devices'),
            leading: const Icon(Icons.devices_outlined),
            title: const Text('Signed-in devices'),
            subtitle: const Text(
              'Review account sessions and sign out another device',
            ),
            onTap: () => _openSessionManagement(
              context,
              widget.sessionManagementController!,
            ),
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
    String subtitle, {
    required bool completed,
    Future<void> Function()? action,
  }) => Card(
    child: ListTile(
      leading: Icon(
        completed ? Icons.check_circle_outline : Icons.pending_outlined,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: action == null
          ? null
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
          const SizedBox(height: Planext4uSpacing.x1),
          const Text(
            'Step 1 of 4. Each completed onboarding step is stored by the server with a revision.',
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
    this.onNavigate,
    this.onCapturePhoto,
    this.onCaptureSignature,
    this.sessionManagementController,
    this.notificationPreferencesController,
    this.appearancePreferencesController,
    this.accountPrivacyController,
    super.key,
  });
  final RiderOperationsController controller;
  final RoleDestination destination;
  final RiderNavigationAction? onNavigate;
  final RiderEvidenceCapture? onCapturePhoto;
  final RiderEvidenceCapture? onCaptureSignature;
  final IdentitySessionManagementController? sessionManagementController;
  final NotificationPreferencesController? notificationPreferencesController;
  final AppearancePreferencesController? appearancePreferencesController;
  final AccountPrivacyController? accountPrivacyController;

  @override
  State<RiderOperationsView> createState() => _RiderOperationsViewState();
}

class _RiderOperationsViewState extends State<RiderOperationsView> {
  _RiderTaskView _taskView = _RiderTaskView.offers;
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
    if (state.status == OperationsStatus.loading && state.profile == null) {
      return const Planext4uStatePanel(
        state: Planext4uViewState.loading,
        title: 'Loading rider workspace',
        message: 'Restoring duty, task and offline sync state.',
      );
    }
    if (state.profile == null && state.status == OperationsStatus.offline) {
      return Planext4uStatePanel(
        state: Planext4uViewState.offline,
        title: 'Rider workspace is offline',
        message: 'Reconnect before starting a new duty session.',
        actionLabel: 'Try again',
        onAction: widget.controller.load,
      );
    }
    if (state.profile == null && state.status == OperationsStatus.failure) {
      return Planext4uStatePanel(
        state: Planext4uViewState.error,
        title: 'Rider workspace unavailable',
        message: 'Duty state could not be restored safely.',
        actionLabel: 'Try again',
        onAction: widget.controller.load,
      );
    }
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
            'emergency' => _emergency(state),
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
      return const Planext4uStatePanel(
        key: ValueKey('rider-register-provider-required'),
        state: Planext4uViewState.permissionDenied,
        title: 'Verified onboarding provider required',
        message:
            'Rider registration unlocks only after the private KYC, document upload and tokenized bank providers are configured.',
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
    final active = {'ACTIVE', 'ONLINE'}.contains(state.duty?.status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _locationReadiness(state),
        const SizedBox(height: Planext4uSpacing.x3),
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
            onPressed: state.locationStatus == RiderLocationStatus.tracking
                ? () => widget.controller.updateLocation(
                    latitude: 13.0827,
                    longitude: 80.2707,
                    accuracyMeters: 8,
                  )
                : null,
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

  Widget _locationReadiness(RiderOperationsState state) {
    final issue = switch (state.locationStatus) {
      RiderLocationStatus.serviceDisabled => (
        'Location services are off',
        'Enable device location services before starting duty.',
      ),
      RiderLocationStatus.permissionDenied => (
        'Location permission denied',
        'Allow location while on duty, then try again.',
      ),
      RiderLocationStatus.permissionPermanentlyDenied => (
        'Location permission blocked',
        'Open app settings and allow location before starting duty.',
      ),
      RiderLocationStatus.unavailable => (
        'Location provider unavailable',
        'Duty tracking needs the configured device location provider.',
      ),
      _ => null,
    };
    if (issue != null) {
      return Planext4uStatePanel(
        state: Planext4uViewState.permissionDenied,
        title: issue.$1,
        message: issue.$2,
        actionLabel: state.locationStatus == RiderLocationStatus.unavailable
            ? null
            : 'Open settings',
        onAction: widget.controller.openLocationSettings,
      );
    }
    final tracking = state.locationStatus == RiderLocationStatus.tracking;
    return Card(
      child: ListTile(
        leading: Icon(
          tracking ? Icons.location_searching : Icons.location_on_outlined,
        ),
        title: Text(tracking ? 'Location tracking active' : 'Location ready'),
        subtitle: Text(
          tracking
              ? 'Updates stop automatically when duty ends.'
              : 'Tracking starts only after you begin duty.',
        ),
        trailing: Planext4uStatusPill(
          label: tracking ? 'Tracking' : 'Ready',
          tone: tracking
              ? Planext4uStatusTone.success
              : Planext4uStatusTone.info,
        ),
      ),
    );
  }

  Widget _assignments(RiderOperationsState state) {
    final activeTasks = state.tasks
        .where((task) => !task.isTerminal)
        .toList(growable: false);
    final history = state.tasks
        .where((task) => task.isTerminal)
        .toList(growable: false);
    final effectiveView = switch (_taskView) {
      _RiderTaskView.offers
          when state.offers.isEmpty && activeTasks.isNotEmpty =>
        _RiderTaskView.active,
      _RiderTaskView.offers when state.offers.isEmpty && history.isNotEmpty =>
        _RiderTaskView.history,
      _RiderTaskView.active when activeTasks.isEmpty && history.isNotEmpty =>
        _RiderTaskView.history,
      final value => value,
    };
    final tasks = switch (effectiveView) {
      _RiderTaskView.offers => state.offers,
      _RiderTaskView.active => activeTasks,
      _RiderTaskView.history => history,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<_RiderTaskView>(
          segments: const [
            ButtonSegment(
              value: _RiderTaskView.offers,
              icon: Icon(Icons.timer_outlined),
              label: Text('Offers'),
            ),
            ButtonSegment(
              value: _RiderTaskView.active,
              icon: Icon(Icons.route_outlined),
              label: Text('Active jobs'),
            ),
            ButtonSegment(
              value: _RiderTaskView.history,
              icon: Icon(Icons.history),
              label: Text('History'),
            ),
          ],
          selected: {effectiveView},
          onSelectionChanged: (value) =>
              setState(() => _taskView = value.single),
        ),
        const SizedBox(height: Planext4uSpacing.x3),
        if (state.pendingCommands > 0)
          ListTile(
            leading: const Icon(Icons.cloud_upload_outlined),
            title: Text('${state.pendingCommands} offline actions pending'),
            subtitle: const Text('They will replay in device sequence order.'),
            trailing: TextButton(
              onPressed: widget.controller.recoverOffline,
              child: const Text('Sync'),
            ),
          ),
        if (tasks.isEmpty)
          Planext4uStatePanel(
            state: Planext4uViewState.empty,
            title: effectiveView == _RiderTaskView.offers
                ? 'No delivery offers'
                : effectiveView == _RiderTaskView.active
                ? 'No active jobs'
                : 'No delivery history',
            message: effectiveView == _RiderTaskView.offers
                ? 'Time-bounded offers will appear while you are on duty.'
                : effectiveView == _RiderTaskView.active
                ? 'Accepted pickup and delivery work will appear here.'
                : 'Completed and closed assignments will appear here.',
          )
        else
          for (final task in tasks)
            _RiderTaskCard(
              controller: widget.controller,
              task: task,
              offer: effectiveView == _RiderTaskView.offers,
              historical: effectiveView == _RiderTaskView.history,
              onNavigate: widget.onNavigate,
              onCapturePhoto: widget.onCapturePhoto,
              onCaptureSignature: widget.onCaptureSignature,
            ),
      ],
    );
  }

  Widget _emergency(RiderOperationsState state) {
    final activeTask = state.tasks
        .where((task) => !task.isTerminal)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Safety centre', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: Planext4uSpacing.x3),
        const Planext4uStatePanel(
          state: Planext4uViewState.permissionDenied,
          title: 'Emergency dispatch is not enabled',
          message:
              'The current mobile contract has no rider emergency escalation endpoint. Use local emergency services for immediate danger.',
        ),
        if (activeTask != null) ...[
          const SizedBox(height: Planext4uSpacing.x3),
          OutlinedButton.icon(
            key: const ValueKey('rider-active-task-chat'),
            onPressed: () => _openTaskChat(activeTask),
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Open active-task safe chat'),
          ),
        ],
        const ListTile(
          leading: Icon(Icons.shield_outlined),
          title: Text('Privacy protected'),
          subtitle: Text(
            'Customer addresses are tokenized and chat contact details are redacted.',
          ),
        ),
      ],
    );
  }

  Future<void> _openTaskChat(RiderTask task) async {
    await widget.controller.openChat(task.orderId);
    if (!mounted) return;
    if (widget.controller.state.conversation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Safe chat is unavailable for this task.'),
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrderChatScreen(controller: widget.controller),
      ),
    );
  }

  Widget _profile(RiderOperationsState state) {
    final profile = state.profile;
    if (profile == null) return _duty(state);
    final completed = state.tasks.where((task) => task.isTerminal).length;
    final active = state.tasks.length - completed;
    final availableEarnings = state.ledger.fold<int>(
      0,
      (total, entry) => total + entry.net.amountMinor,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          child: CircleAvatar(
            radius: 36,
            child: Text(profile.fullName[0].toUpperCase()),
          ),
        ),
        const SizedBox(height: Planext4uSpacing.x3),
        Text(
          profile.fullName,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          '${profile.status} • ${profile.vehicleNumber}',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Planext4uSpacing.x4),
        Planext4uSectionCard(
          title: 'Performance snapshot',
          subtitle: 'Calculated from the assignments available to this app.',
          child: Wrap(
            spacing: Planext4uSpacing.x4,
            runSpacing: Planext4uSpacing.x3,
            children: [
              _RiderMetric(label: 'Active', value: '$active'),
              _RiderMetric(label: 'Completed', value: '$completed'),
              _RiderMetric(
                label: 'Ledger net',
                value: CatalogMoney(
                  amountMinor: availableEarnings,
                  currency: state.ledger.firstOrNull?.net.currency ?? 'INR',
                ).display(),
              ),
            ],
          ),
        ),
        const SizedBox(height: Planext4uSpacing.x3),
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
        if (widget.notificationPreferencesController != null)
          ListTile(
            key: const ValueKey('rider-notification-preferences'),
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notification preferences'),
            subtitle: const Text(
              'Choose channels for assignments, payouts and offers',
            ),
            onTap: () => _openNotificationPreferences(
              context,
              widget.notificationPreferencesController!,
            ),
          ),
        if (widget.appearancePreferencesController != null)
          ListTile(
            key: const ValueKey('rider-appearance-preferences'),
            leading: const Icon(Icons.contrast_outlined),
            title: const Text('Appearance and accessibility'),
            subtitle: const Text(
              'Language, theme, text size, motion and data usage',
            ),
            onTap: () => _openAppearancePreferences(
              context,
              widget.appearancePreferencesController!,
            ),
          ),
        if (widget.accountPrivacyController != null)
          ListTile(
            key: const ValueKey('rider-account-privacy'),
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Account privacy'),
            subtitle: const Text(
              'Export your data or schedule account deletion',
            ),
            onTap: () =>
                _openAccountPrivacy(context, widget.accountPrivacyController!),
          ),
        if (widget.sessionManagementController != null)
          ListTile(
            key: const ValueKey('rider-signed-in-devices'),
            leading: const Icon(Icons.devices_outlined),
            title: const Text('Signed-in devices'),
            subtitle: const Text(
              'Review account sessions and sign out another device',
            ),
            onTap: () => _openSessionManagement(
              context,
              widget.sessionManagementController!,
            ),
          ),
      ],
    );
  }
}

Future<void> _openSessionManagement(
  BuildContext context,
  IdentitySessionManagementController controller,
) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => IdentitySessionManagementScreen(controller: controller),
  ),
);

Future<void> _openNotificationPreferences(
  BuildContext context,
  NotificationPreferencesController controller,
) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => NotificationPreferencesScreen(controller: controller),
  ),
);

Future<void> _openAppearancePreferences(
  BuildContext context,
  AppearancePreferencesController controller,
) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => AppearancePreferencesScreen(controller: controller),
  ),
);

Future<void> _openAccountPrivacy(
  BuildContext context,
  AccountPrivacyController controller,
) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => AccountPrivacyScreen(controller: controller),
  ),
);

final class _RiderTaskCard extends StatelessWidget {
  const _RiderTaskCard({
    required this.controller,
    required this.task,
    this.offer = false,
    this.historical = false,
    this.onNavigate,
    this.onCapturePhoto,
    this.onCaptureSignature,
  });
  final RiderOperationsController controller;
  final RiderTask task;
  final bool offer;
  final bool historical;
  final RiderNavigationAction? onNavigate;
  final RiderEvidenceCapture? onCapturePhoto;
  final RiderEvidenceCapture? onCaptureSignature;

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
            else if (!historical) ...[
              Wrap(
                spacing: Planext4uSpacing.x2,
                children: [
                  if (task.allowedActions.contains('NAVIGATE_PICKUP'))
                    OutlinedButton.icon(
                      onPressed: () => _navigate(context),
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
            ] else
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  task.status == 'DELIVERED'
                      ? Icons.check_circle_outline
                      : Icons.history,
                ),
                title: Text(
                  task.status == 'DELIVERED'
                      ? 'Delivery completed'
                      : 'Assignment closed',
                ),
                subtitle: Text(
                  task.podAssetId.isEmpty
                      ? 'No proof reference is exposed on this record.'
                      : 'Private proof reference verified by the server.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigate(BuildContext context) async {
    if (onNavigate != null) {
      try {
        await onNavigate!(task);
        return;
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Navigation provider is unavailable. Showing the safe task summary.',
              ),
            ),
          );
        }
      }
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => RiderNavigationView(task: task)),
    );
  }

  Future<void> _complete(BuildContext context) async {
    final otp = TextEditingController();
    String photoAssetId = '';
    String signatureAssetId = '';
    final requiresOtp = task.requiredEvidence.contains('OTP');
    final requiresPhoto = task.requiredEvidence.contains('PHOTO');
    final requiresSignature = task.requiredEvidence.contains('SIGNATURE');
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final otpValid =
              !requiresOtp || RegExp(r'^\d{4,8}$').hasMatch(otp.text);
          final ready =
              otpValid &&
              (!requiresPhoto || photoAssetId.isNotEmpty) &&
              (!requiresSignature || signatureAssetId.isNotEmpty);
          return AlertDialog(
            title: const Text('Proof of delivery'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Required by server: ${task.requiredEvidence.join(', ')}',
                  ),
                  if (requiresOtp) ...[
                    const SizedBox(height: Planext4uSpacing.x3),
                    TextField(
                      key: const ValueKey('delivery-otp'),
                      controller: otp,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 8,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Customer delivery code',
                        helperText: 'Enter the 4–8 digit server-issued code.',
                      ),
                    ),
                  ],
                  if (requiresPhoto) ...[
                    const SizedBox(height: Planext4uSpacing.x3),
                    OutlinedButton.icon(
                      key: const ValueKey('capture-pod-photo'),
                      onPressed: onCapturePhoto == null
                          ? null
                          : () async {
                              final value = await onCapturePhoto!(task);
                              if (value?.isNotEmpty == true) {
                                setDialogState(() => photoAssetId = value!);
                              }
                            },
                      icon: Icon(
                        photoAssetId.isEmpty
                            ? Icons.add_a_photo_outlined
                            : Icons.check_circle_outline,
                      ),
                      label: Text(
                        photoAssetId.isEmpty
                            ? 'Capture private photo'
                            : 'Photo captured',
                      ),
                    ),
                    if (onCapturePhoto == null)
                      const Text(
                        'Photo capture becomes available after the private media provider is configured.',
                      ),
                  ],
                  if (requiresSignature) ...[
                    const SizedBox(height: Planext4uSpacing.x3),
                    OutlinedButton.icon(
                      key: const ValueKey('capture-pod-signature'),
                      onPressed: onCaptureSignature == null
                          ? null
                          : () async {
                              final value = await onCaptureSignature!(task);
                              if (value?.isNotEmpty == true) {
                                setDialogState(() => signatureAssetId = value!);
                              }
                            },
                      icon: Icon(
                        signatureAssetId.isEmpty
                            ? Icons.draw_outlined
                            : Icons.check_circle_outline,
                      ),
                      label: Text(
                        signatureAssetId.isEmpty
                            ? 'Capture recipient signature'
                            : 'Signature captured',
                      ),
                    ),
                    if (onCaptureSignature == null)
                      const Text(
                        'Signature capture becomes available after the evidence provider is configured.',
                      ),
                  ],
                  const SizedBox(height: Planext4uSpacing.x3),
                  const Text(
                    'Evidence is private, blurred where required, and immutable after server acceptance.',
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
                key: const ValueKey('submit-pod'),
                onPressed: ready ? () => Navigator.pop(context, true) : null,
                child: const Text('Submit securely'),
              ),
            ],
          );
        },
      ),
    );
    if (accepted == true) {
      await controller.complete(
        task,
        otp: otp.text,
        blurredPhotoAssetId: photoAssetId,
        signatureAssetId: signatureAssetId,
      );
    }
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

final class RiderNavigationView extends StatelessWidget {
  const RiderNavigationView({required this.task, super.key});

  final RiderTask task;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Task navigation')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(Planext4uSpacing.x4),
        children: [
          _RiderRouteOverview(task: task),
          const SizedBox(height: Planext4uSpacing.x4),
          const Planext4uStatePanel(
            state: Planext4uViewState.empty,
            title: 'Turn-by-turn provider not configured',
            message:
                'The safe task summary remains available. External navigation is enabled only through the environment-owned maps provider.',
          ),
          const SizedBox(height: Planext4uSpacing.x4),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to active task'),
          ),
        ],
      ),
    ),
  );
}

final class _RiderRouteOverview extends StatelessWidget {
  const _RiderRouteOverview({required this.task});

  final RiderTask task;

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        'Route from ${task.pickupLabel} to ${task.dropoffLabel}, ${(task.distanceMeters / 1000).toStringAsFixed(1)} kilometres',
    child: Planext4uSectionCard(
      title: 'Route overview',
      subtitle: 'Customer coordinates remain hidden from visible copy.',
      child: Column(
        children: [
          _RiderRouteStop(
            icon: Icons.store_mall_directory_outlined,
            label: 'Pickup',
            value: task.pickupLabel,
            active: task.allowedActions.contains('NAVIGATE_PICKUP'),
          ),
          Container(
            width: 2,
            height: 36,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          _RiderRouteStop(
            icon: Icons.location_on_outlined,
            label: 'Drop-off',
            value: task.dropoffLabel,
            active: !task.allowedActions.contains('NAVIGATE_PICKUP'),
          ),
          const SizedBox(height: Planext4uSpacing.x3),
          Planext4uStatusPill(
            label:
                '${(task.distanceMeters / 1000).toStringAsFixed(1)} km total',
            tone: Planext4uStatusTone.info,
          ),
        ],
      ),
    ),
  );
}

final class _RiderRouteStop extends StatelessWidget {
  const _RiderRouteStop({
    required this.icon,
    required this.label,
    required this.value,
    required this.active,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool active;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(
      backgroundColor: active
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(icon),
    ),
    title: Text(label),
    subtitle: Text(value),
    trailing: active
        ? const Planext4uStatusPill(
            label: 'Next',
            tone: Planext4uStatusTone.success,
          )
        : null,
  );
}

final class _RiderMetric extends StatelessWidget {
  const _RiderMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label $value',
    child: SizedBox(
      width: 96,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
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
