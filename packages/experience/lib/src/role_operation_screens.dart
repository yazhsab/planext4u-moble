import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';
import 'package:planext4u_identity/planext4u_identity.dart';

import 'account_privacy.dart';
import 'account_privacy_screen.dart';
import 'appearance_preferences.dart';
import 'appearance_preferences_screen.dart';
import 'catalog.dart';
import 'identity_profile.dart';
import 'identity_profile_screen.dart';
import 'notification_preferences.dart';
import 'notification_preferences_screen.dart';
import 'role_operations.dart';
import 'onboarding_progress.dart';
import 'private_onboarding_progress.dart';
import 'role_shell.dart';
import 'session_management_screen.dart';
import 'support.dart';
import 'support_screen.dart';

typedef RiderEvidenceCapture = Future<String?> Function(RiderTask task);
typedef RiderSignatureEvidenceUpload =
    Future<String?> Function(RiderTask task, Uint8List pngBytes);
typedef RiderNavigationAction = Future<void> Function(RiderTask task);

enum _RiderTaskView { offers, active, history }

RecoverableOnboardingDocuments? _recoverableDocuments(Object? provider) {
  if (provider is RecoverableOnboardingDocuments &&
      provider.retainsDocumentProgress) {
    return provider;
  }
  return null;
}

final class VendorOperationsView extends StatefulWidget {
  const VendorOperationsView({
    required this.controller,
    required this.destination,
    this.onboardingProvider,
    this.zonePolicyVersion = 'zone-policy-v1',
    this.identityProfileController,
    this.sessionManagementController,
    this.notificationPreferencesController,
    this.supportController,
    this.appearancePreferencesController,
    this.accountPrivacyController,
    super.key,
  });
  final VendorOperationsController controller;
  final RoleDestination destination;
  final VendorOnboardingProvider? onboardingProvider;
  final String zonePolicyVersion;
  final IdentityProfileController? identityProfileController;
  final IdentitySessionManagementController? sessionManagementController;
  final NotificationPreferencesController? notificationPreferencesController;
  final SupportController? supportController;
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
  bool _onboardingBusy = false;
  String? _onboardingMessage;
  int _onboardingGeneration = 0;

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
      ++_onboardingGeneration;
      _onboardingBusy = false;
      _onboardingMessage = null;
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
    ++_onboardingGeneration;
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
        if (application.status == 'REJECTED' &&
            application.allowedActions.contains('RESUBMIT_DOCUMENTS')) ...[
          const SizedBox(height: Planext4uSpacing.x3),
          _VendorReworkCard(
            key: ValueKey(
              'vendor-rework-${application.id}-${application.revision}',
            ),
            controller: widget.controller,
            application: application,
            provider: widget.onboardingProvider,
          ),
        ],
        const SizedBox(height: Planext4uSpacing.x4),
        Semantics(
          label: '$completedSteps of 4 onboarding steps saved',
          child: LinearProgressIndicator(value: completedSteps / 4),
        ),
        const SizedBox(height: Planext4uSpacing.x2),
        Text(
          '$completedSteps of 4 revisioned steps saved. You can resume after sign-in.',
        ),
        if (_onboardingBusy) ...[
          const SizedBox(height: Planext4uSpacing.x3),
          const LinearProgressIndicator(
            key: ValueKey('vendor-onboarding-progress'),
          ),
        ],
        if (_onboardingMessage != null) ...[
          const SizedBox(height: Planext4uSpacing.x3),
          Semantics(
            liveRegion: true,
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(_onboardingMessage!),
              ),
            ),
          ),
        ],
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
              ? !_vendorDocumentsAvailable(widget.onboardingProvider)
                    ? 'Private document provider is not configured.'
                    : 'Ready for secure document collection.'
              : '${application.documents.length} uploaded',
          completed: application.documents.isNotEmpty,
          action:
              application.allowedActions.contains('SUBMIT_DOCUMENTS') &&
                  _vendorDocumentsAvailable(widget.onboardingProvider) &&
                  !_onboardingBusy
              ? _collectVendorDocuments
              : null,
          actionLabel: 'Verify',
        ),
        if (application.allowedActions.contains('SUBMIT_DOCUMENTS') &&
            !_vendorDocumentsAvailable(widget.onboardingProvider))
          const _OnboardingProviderUnavailable(
            key: ValueKey('vendor-document-provider-unavailable'),
            capability: 'Document and KYC verification',
          ),
        if (_vendorDocumentRecovery != null) ...[
          const Text(
            'Private document progress is encrypted on this device for 7 days. Continue verification to recheck saved uploads. Submitted evidence follows the verification retention policy.',
          ),
          TextButton(
            key: const ValueKey('vendor-discard-private-document-progress'),
            onPressed: _onboardingBusy ? null : _discardVendorDocumentProgress,
            child: const Text('Clear saved document progress'),
          ),
        ],
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
              ? _scheduleVendorFieldVisit
              : null,
          actionLabel: application.fieldVisit == null
              ? 'Schedule'
              : 'Reschedule',
        ),
        _step(
          '3. Service zones',
          application.zoneCount == 0
              ? 'Add an operating area covered by the current zone policy.'
              : '${application.zoneCount} configured',
          completed: application.zoneCount > 0,
          action:
              application.allowedActions.contains('SET_ZONES') &&
                  !_onboardingBusy
              ? _configureVendorZones
              : null,
          actionLabel: application.zoneCount == 0 ? 'Add zone' : 'Update',
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
          application.bankStatus == 'NOT_CONFIGURED' &&
                  !_vendorBankAvailable(widget.onboardingProvider)
              ? 'Bank-tokenization provider is not configured.'
              : application.bankStatus.replaceAll('_', ' '),
          completed: application.bankStatus != 'NOT_CONFIGURED',
          action:
              application.allowedActions.contains('SUBMIT_BANK') &&
                  _vendorBankAvailable(widget.onboardingProvider) &&
                  !_onboardingBusy
              ? _tokenizeVendorBank
              : null,
          actionLabel: application.bankStatus == 'NOT_CONFIGURED'
              ? 'Add bank'
              : 'Resubmit',
        ),
        if (application.allowedActions.contains('SUBMIT_BANK') &&
            !_vendorBankAvailable(widget.onboardingProvider))
          const _OnboardingProviderUnavailable(
            key: ValueKey('vendor-bank-provider-unavailable'),
            capability: 'Bank account tokenization',
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
        if (widget.identityProfileController != null)
          ListTile(
            key: const ValueKey('vendor-edit-identity-profile'),
            leading: const Icon(Icons.manage_accounts_outlined),
            title: const Text('Personal profile'),
            subtitle: const Text(
              'Edit your display name, language and time zone',
            ),
            onTap: () => _openIdentityProfile(
              context,
              widget.identityProfileController!,
            ),
          ),
        ListTile(
          key: const ValueKey('vendor-support'),
          leading: const Icon(Icons.support_agent),
          title: const Text('Vendor support'),
          subtitle: const Text('Catalogue, order, payment and payout help'),
          onTap: widget.supportController == null
              ? null
              : () => _openSupport(context, widget.supportController!),
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

  Future<void> _collectVendorDocuments() async {
    final provider = widget.onboardingProvider;
    if (provider == null) return;
    final controller = widget.controller;
    await _runOnboarding(() async {
      final generation = _onboardingGeneration;
      final documents = await provider.collectDocuments();
      if (!mounted ||
          widget.controller != controller ||
          generation != _onboardingGeneration) {
        if (_recoverableDocuments(provider) == null &&
            provider is VendorDocumentCleanup) {
          try {
            await (provider as VendorDocumentCleanup)
                .discardUnsubmittedDocuments(documents);
          } catch (_) {
            // The owning server still controls retention when cleanup fails.
          }
        }
        return;
      }
      final ids = documents.map((value) => value.assetId).toSet();
      final recovery = _recoverableDocuments(provider);
      await recovery?.prepareDocumentSubmission(ids);
      if (!mounted ||
          widget.controller != controller ||
          generation != _onboardingGeneration) {
        return;
      }
      await controller.submitOnboardingDocuments(documents);
      if (controller.state.status == OperationsStatus.ready) {
        try {
          await recovery?.forgetSubmittedDocuments(ids);
        } catch (_) {
          if (mounted &&
              widget.controller == controller &&
              generation == _onboardingGeneration) {
            _onboardingMessage =
                'Documents submitted for review. Saved progress cleanup is pending; refresh before collecting replacements.';
          }
        }
      }
    }, 'Documents submitted for private OCR and KYC review.');
  }

  RecoverableOnboardingDocuments? get _vendorDocumentRecovery {
    return _recoverableDocuments(widget.onboardingProvider);
  }

  Future<void> _discardVendorDocumentProgress() async {
    final recovery = _vendorDocumentRecovery;
    if (recovery == null) return;
    await _runOnboarding(
      recovery.discardSavedDocuments,
      'Saved document progress cleared. Refresh the current application before collecting replacement documents.',
    );
  }

  Future<void> _tokenizeVendorBank() async {
    final provider = widget.onboardingProvider;
    if (provider == null) return;
    final controller = widget.controller;
    await _runOnboarding(() async {
      final generation = _onboardingGeneration;
      final bank = await provider.tokenizeBankAccount();
      if (!mounted ||
          widget.controller != controller ||
          generation != _onboardingGeneration) {
        return;
      }
      await controller.configureOnboardingBank(bank);
    }, 'Tokenized bank details submitted for verification.');
  }

  Future<void> _configureVendorZones() async {
    final controller = widget.controller;
    final zone = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) =>
          _VendorZoneDialog(policyVersion: widget.zonePolicyVersion),
    );
    if (zone == null || !mounted || widget.controller != controller) return;
    await _runOnboarding(
      () => controller.configureZones([zone]),
      'Service zone saved.',
    );
  }

  Future<void> _scheduleVendorFieldVisit() async {
    final controller = widget.controller;
    final visit = await showDialog<VendorFieldVisitDraft>(
      context: context,
      builder: (_) => const _VendorFieldVisitDialog(),
    );
    if (visit == null || !mounted || widget.controller != controller) return;
    await _runOnboarding(
      () => controller.scheduleFieldVisit(visit),
      'Field visit scheduled.',
    );
  }

  Future<void> _runOnboarding(
    Future<void> Function() action,
    String successMessage,
  ) async {
    if (_onboardingBusy) return;
    final generation = ++_onboardingGeneration;
    setState(() {
      _onboardingBusy = true;
      _onboardingMessage = null;
    });
    try {
      await action();
      if (!mounted || generation != _onboardingGeneration) return;
      if (widget.controller.state.status == OperationsStatus.ready &&
          _onboardingMessage == null) {
        _onboardingMessage = successMessage;
      }
    } catch (_) {
      if (!mounted || generation != _onboardingGeneration) return;
      _onboardingMessage =
          'The onboarding provider did not return a safe, complete result.';
    } finally {
      if (mounted && generation == _onboardingGeneration) {
        setState(() => _onboardingBusy = false);
      }
    }
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
    String actionLabel = 'Continue',
  }) => Card(
    child: ListTile(
      leading: Icon(
        completed ? Icons.check_circle_outline : Icons.pending_outlined,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: action == null
          ? null
          : TextButton(onPressed: action, child: Text(actionLabel)),
    ),
  );
}

bool _vendorDocumentsAvailable(VendorOnboardingProvider? provider) =>
    provider != null &&
    (provider is! VendorOnboardingCapabilities ||
        (provider as VendorOnboardingCapabilities).canCollectDocuments);

bool _vendorBankAvailable(VendorOnboardingProvider? provider) =>
    provider != null &&
    (provider is! VendorOnboardingCapabilities ||
        (provider as VendorOnboardingCapabilities).canTokenizeBankAccount);

final class _OnboardingProviderUnavailable extends StatelessWidget {
  const _OnboardingProviderUnavailable({required this.capability, super.key});

  final String capability;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: ListTile(
        leading: const Icon(Icons.lock_outline),
        title: Text('$capability unavailable'),
        subtitle: const Text(
          'An approved private provider must be configured before this step can continue.',
        ),
      ),
    ),
  );
}

final class _VendorZoneDialog extends StatefulWidget {
  const _VendorZoneDialog({required this.policyVersion});

  final String policyVersion;

  @override
  State<_VendorZoneDialog> createState() => _VendorZoneDialogState();
}

class _VendorZoneDialogState extends State<_VendorZoneDialog> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _postalCodes = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _radius = TextEditingController(text: '10');

  @override
  void dispose() {
    _id.dispose();
    _postalCodes.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _radius.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add service zone'),
    content: Form(
      key: _form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const ValueKey('vendor-zone-id'),
              controller: _id,
              decoration: const InputDecoration(labelText: 'Zone name'),
              validator: _required,
            ),
            TextFormField(
              key: const ValueKey('vendor-zone-postal-codes'),
              controller: _postalCodes,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Postal codes',
                helperText: 'Comma-separated, 4–10 digits each.',
              ),
              validator: (value) {
                final codes = _codes(value);
                return codes.isEmpty ||
                        codes.any(
                          (code) => !RegExp(r'^[0-9]{4,10}$').hasMatch(code),
                        )
                    ? 'Enter valid postal codes.'
                    : null;
              },
            ),
            TextFormField(
              key: const ValueKey('vendor-zone-latitude'),
              controller: _latitude,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(labelText: 'Latitude'),
              validator: (value) => _coordinate(value, 90),
            ),
            TextFormField(
              key: const ValueKey('vendor-zone-longitude'),
              controller: _longitude,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(labelText: 'Longitude'),
              validator: (value) => _coordinate(value, 180),
            ),
            TextFormField(
              key: const ValueKey('vendor-zone-radius'),
              controller: _radius,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Radius (km)'),
              validator: (value) {
                final radius = double.tryParse(value?.trim() ?? '');
                return radius == null || radius <= 0 || radius > 250
                    ? 'Enter a radius from 0 to 250 km.'
                    : null;
              },
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey('vendor-save-zone'),
        onPressed: _save,
        child: const Text('Save zone'),
      ),
    ],
  );

  void _save() {
    if (!(_form.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(<String, Object?>{
      'id': _id.text.trim(),
      'postal_codes': _codes(_postalCodes.text),
      'latitude': double.parse(_latitude.text.trim()),
      'longitude': double.parse(_longitude.text.trim()),
      'radius_km': double.parse(_radius.text.trim()),
      'policy_version': widget.policyVersion,
    });
  }

  static String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;

  static List<String> _codes(String? value) => (value ?? '')
      .split(',')
      .map((code) => code.trim())
      .where((code) => code.isNotEmpty)
      .toSet()
      .toList(growable: false);

  static String? _coordinate(String? value, double limit) {
    final coordinate = double.tryParse(value?.trim() ?? '');
    return coordinate == null ||
            !coordinate.isFinite ||
            coordinate.abs() > limit
        ? 'Enter a valid coordinate.'
        : null;
  }
}

final class _VendorFieldVisitDialog extends StatefulWidget {
  const _VendorFieldVisitDialog();

  @override
  State<_VendorFieldVisitDialog> createState() =>
      _VendorFieldVisitDialogState();
}

class _VendorFieldVisitDialogState extends State<_VendorFieldVisitDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _scheduledAt;
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _radius = TextEditingController(text: '200');

  @override
  void initState() {
    super.initState();
    _scheduledAt = TextEditingController(
      text: DateTime.now()
          .toUtc()
          .add(const Duration(days: 1))
          .toIso8601String(),
    );
  }

  @override
  void dispose() {
    _scheduledAt.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _radius.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Schedule field visit'),
    content: Form(
      key: _form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const ValueKey('vendor-visit-time'),
              controller: _scheduledAt,
              decoration: const InputDecoration(
                labelText: 'Scheduled time (ISO 8601)',
              ),
              validator: (value) =>
                  DateTime.tryParse(value?.trim() ?? '') == null
                  ? 'Enter a valid date and time.'
                  : null,
            ),
            TextFormField(
              key: const ValueKey('vendor-visit-latitude'),
              controller: _latitude,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(labelText: 'Business latitude'),
              validator: (value) =>
                  _VendorZoneDialogState._coordinate(value, 90),
            ),
            TextFormField(
              key: const ValueKey('vendor-visit-longitude'),
              controller: _longitude,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Business longitude',
              ),
              validator: (value) =>
                  _VendorZoneDialogState._coordinate(value, 180),
            ),
            TextFormField(
              key: const ValueKey('vendor-visit-radius'),
              controller: _radius,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Check-in radius (metres)',
              ),
              validator: (value) {
                final radius = int.tryParse(value?.trim() ?? '');
                return radius == null || radius < 25 || radius > 1000
                    ? 'Enter a radius from 25 to 1000 metres.'
                    : null;
              },
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey('vendor-schedule-visit'),
        onPressed: _save,
        child: const Text('Schedule'),
      ),
    ],
  );

  void _save() {
    if (!(_form.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      VendorFieldVisitDraft(
        scheduledAt: DateTime.parse(_scheduledAt.text.trim()).toUtc(),
        latitude: double.parse(_latitude.text.trim()),
        longitude: double.parse(_longitude.text.trim()),
        allowedRadiusMeters: int.parse(_radius.text.trim()),
      ),
    );
  }
}

final class _VendorReworkCard extends StatefulWidget {
  const _VendorReworkCard({
    super.key,
    required this.controller,
    required this.application,
    required this.provider,
  });

  final VendorOperationsController controller;
  final VendorApplication application;
  final VendorOnboardingProvider? provider;

  @override
  State<_VendorReworkCard> createState() => _VendorReworkCardState();
}

class _VendorReworkCardState extends State<_VendorReworkCard> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _businessName;
  late final TextEditingController _businessType;
  late final TextEditingController _contactName;
  List<VendorOnboardingDocument> _documents = const [];
  bool _busy = false;
  bool _submissionStarted = false;
  bool _restoring = false;
  int _generation = 0;
  int _formIntent = 0;
  String? _message;

  @override
  void initState() {
    super.initState();
    _businessName = TextEditingController(
      text: widget.application.businessName,
    );
    _businessType = TextEditingController(
      text: widget.application.businessType,
    );
    _contactName = TextEditingController(text: widget.application.contactName);
    for (final field in [_businessName, _businessType, _contactName]) {
      field.addListener(_saveProgress);
    }
    _restoreProgress();
  }

  Future<void> _restoreProgress() async {
    final store = widget.controller.onboardingProgress;
    if (store == null) return;
    final generation = _generation;
    _restoring = _busy = true;
    try {
      final saved = await store.read();
      if (!mounted || generation != _generation) return;
      if (saved != null) {
        if (saved.applicationId == widget.application.id &&
            saved.applicationRevision == widget.application.revision) {
          _businessName.text = saved.businessName;
          _businessType.text = saved.businessType;
          _contactName.text = saved.contactName;
          _message =
              'Saved correction form restored. Review private documents before submitting.';
        } else {
          _message =
              'A saved form belongs to another application review. Current server details are shown.';
        }
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        _message =
            'Saved correction form could not be read. Re-enter the fields.';
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _restoring = _busy = false);
      }
    }
  }

  void _saveProgress() {
    final store = widget.controller.onboardingProgress;
    if (_restoring || _submissionStarted || store == null) return;
    final generation = _generation;
    final intent = ++_formIntent;
    final value = VendorOnboardingProgress(
      businessName: _businessName.text,
      businessType: _businessType.text,
      contactName: _contactName.text,
      applicationId: widget.application.id,
      applicationRevision: widget.application.revision,
    );
    unawaited(
      Future.sync(() => store.save(value)).catchError((Object _) {
        if (mounted && generation == _generation && intent == _formIntent) {
          setState(
            () => _message =
                'This form change could not be saved. Keep the app open or retry.',
          );
        }
      }),
    );
  }

  Future<void> _discardFormProgress() async {
    final store = widget.controller.onboardingProgress;
    if (store == null || _busy) return;
    final generation = _generation;
    setState(() => _busy = true);
    try {
      await store.clear();
      if (!mounted || generation != _generation) return;
      _restoring = true;
      _businessName.text = widget.application.businessName;
      _businessType.text = widget.application.businessType;
      _contactName.text = widget.application.contactName;
      _message = 'Saved form deleted. Current application details restored.';
    } catch (_) {
      if (mounted && generation == _generation) {
        _message = 'Saved form could not be deleted. Retry.';
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _restoring = _busy = false);
      }
    }
  }

  RecoverableOnboardingDocuments? get _recovery =>
      _recoverableDocuments(widget.provider);

  @override
  void didUpdateWidget(covariant _VendorReworkCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller &&
        oldWidget.application.id == widget.application.id &&
        oldWidget.application.revision == widget.application.revision) {
      return;
    }
    ++_generation;
    if (!_submissionStarted &&
        _documents.isNotEmpty &&
        _recoverableDocuments(oldWidget.provider) == null &&
        oldWidget.provider is VendorDocumentCleanup) {
      unawaited(
        (oldWidget.provider! as VendorDocumentCleanup)
            .discardUnsubmittedDocuments(_documents),
      );
    }
    _documents = const [];
    _submissionStarted = false;
    _busy = false;
    _restoring = true;
    _businessName.text = widget.application.businessName;
    _businessType.text = widget.application.businessType;
    _contactName.text = widget.application.contactName;
    _restoring = false;
    _message = null;
    _restoreProgress();
  }

  @override
  void dispose() {
    ++_generation;
    if (!_submissionStarted && _documents.isNotEmpty && _recovery == null) {
      final provider = widget.provider;
      if (provider is VendorDocumentCleanup) {
        unawaited(
          (provider as VendorDocumentCleanup).discardUnsubmittedDocuments(
            _documents,
          ),
        );
      }
    }
    _businessName.dispose();
    _businessType.dispose();
    _contactName.dispose();
    super.dispose();
  }

  String _copy(BuildContext context, String english, String tamil) =>
      Localizations.localeOf(context).languageCode == 'ta' ? tamil : english;

  @override
  Widget build(BuildContext context) {
    final reason =
        widget.application.timeline.reversed
            .where((event) => event.reason?.trim().isNotEmpty == true)
            .map((event) => event.reason!)
            .firstOrNull ??
        widget.application.documentSummaries
            .where(
              (document) => document.reviewReason?.trim().isNotEmpty == true,
            )
            .map((document) => document.reviewReason!)
            .firstOrNull;
    final providerReady = _vendorDocumentsAvailable(widget.provider);
    return Planext4uSectionCard(
      title: _copy(
        context,
        'Correct rejected application',
        'நிராகரிக்கப்பட்ட விண்ணப்பத்தைத் திருத்தவும்',
      ),
      subtitle: _copy(
        context,
        'Update business details and submit fresh private documents together. The application returns to review.',
        'வணிக விவரங்களைத் திருத்தி புதிய தனிப்பட்ட ஆவணங்களை ஒன்றாகச் சமர்ப்பிக்கவும். விண்ணப்பம் மீண்டும் சரிபார்க்கப்படும்.',
      ),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (reason != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  '${_copy(context, 'Review reason', 'சரிபார்ப்பு காரணம்')}: $reason',
                  key: const ValueKey('vendor-rework-reason'),
                ),
              ),
            if (widget.controller.onboardingProgress != null) ...[
              Text(
                _copy(
                  context,
                  'Business form fields are encrypted on this device for 7 days. Private documents have separate progress.',
                  'வணிகப் படிவ விவரங்கள் இந்தச் சாதனத்தில் 7 நாட்கள் குறியாக்கம் செய்யப்படும். தனிப்பட்ட ஆவணங்களுக்கு தனி முன்னேற்றம் உள்ளது.',
                ),
              ),
              TextButton(
                key: const ValueKey('vendor-rework-discard-form'),
                onPressed: _busy ? null : _discardFormProgress,
                child: Text(
                  _copy(
                    context,
                    'Delete saved form',
                    'சேமித்த படிவத்தை அழிக்கவும்',
                  ),
                ),
              ),
            ],
            if (!providerReady)
              const _OnboardingProviderUnavailable(
                key: ValueKey('vendor-rework-provider-unavailable'),
                capability: 'Document and KYC verification',
              ),
            if (_message != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  _message!,
                  key: const ValueKey('vendor-rework-message'),
                ),
              ),
            TextFormField(
              key: const ValueKey('vendor-rework-business-name'),
              controller: _businessName,
              enabled: !_busy,
              maxLength: 120,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: _copy(context, 'Business name', 'வணிகத்தின் பெயர்'),
              ),
              validator: (value) => (value?.trim().length ?? 0) < 3
                  ? _copy(
                      context,
                      'Enter a business name.',
                      'வணிகத்தின் பெயரை உள்ளிடவும்.',
                    )
                  : null,
            ),
            TextFormField(
              key: const ValueKey('vendor-rework-business-type'),
              controller: _businessType,
              enabled: !_busy,
              maxLength: 120,
              decoration: InputDecoration(
                labelText: _copy(context, 'Business type', 'வணிக வகை'),
              ),
              validator: (value) => (value?.trim().length ?? 0) < 3
                  ? _copy(
                      context,
                      'Enter a business type.',
                      'வணிக வகையை உள்ளிடவும்.',
                    )
                  : null,
            ),
            TextFormField(
              key: const ValueKey('vendor-rework-contact-name'),
              controller: _contactName,
              enabled: !_busy,
              maxLength: 120,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: _copy(context, 'Primary contact', 'முதன்மை தொடர்பு'),
              ),
              validator: (value) => (value?.trim().length ?? 0) < 3
                  ? _copy(
                      context,
                      'Enter a contact name.',
                      'தொடர்பு பெயரை உள்ளிடவும்.',
                    )
                  : null,
            ),
            Text(
              _documents.isEmpty
                  ? _copy(
                      context,
                      'Fresh business and owner documents are required.',
                      'புதிய வணிக மற்றும் உரிமையாளர் ஆவணங்கள் தேவை.',
                    )
                  : _copy(
                      context,
                      '${_documents.length} private documents ready. Uploading does not approve KYC.',
                      '${_documents.length} தனிப்பட்ட ஆவணங்கள் தயார். பதிவேற்றம் KYC ஒப்புதல் அல்ல.',
                    ),
            ),
            OutlinedButton.icon(
              key: const ValueKey('vendor-rework-collect-documents'),
              onPressed: !providerReady || _busy ? null : _collectDocuments,
              icon: const Icon(Icons.document_scanner_outlined),
              label: Text(
                _copy(
                  context,
                  'Continue private documents',
                  'தனிப்பட்ட ஆவணங்களைத் தொடரவும்',
                ),
              ),
            ),
            if (_recovery != null) ...[
              Text(
                _copy(
                  context,
                  'Private document progress is encrypted for 7 days. It is rechecked after restart. Clear it before collecting replacement evidence.',
                  'தனிப்பட்ட ஆவண முன்னேற்றம் 7 நாட்கள் குறியாக்கம் செய்யப்படுகிறது. மறுதொடக்கத்திற்குப் பின் மீண்டும் சரிபார்க்கப்படும். மாற்று ஆவணங்களுக்கு முன் அதை அழிக்கவும்.',
                ),
              ),
              TextButton(
                key: const ValueKey('vendor-rework-discard-documents'),
                onPressed: _busy ? null : _discardDocuments,
                child: Text(
                  _copy(
                    context,
                    'Clear saved document progress',
                    'சேமித்த ஆவண முன்னேற்றத்தை அழிக்கவும்',
                  ),
                ),
              ),
            ],
            FilledButton.icon(
              key: const ValueKey('vendor-rework-submit'),
              onPressed: !providerReady || _busy || _documents.isEmpty
                  ? null
                  : _submit,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_user_outlined),
              label: Text(
                _copy(
                  context,
                  'Submit corrections for review',
                  'திருத்தங்களைச் சரிபார்ப்புக்கு சமர்ப்பிக்கவும்',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _collectDocuments() async {
    final provider = widget.provider;
    if (provider == null || _busy) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final documents = await provider.collectDocuments();
      if (!mounted || generation != _generation) {
        if (_recovery == null && provider is VendorDocumentCleanup) {
          await (provider as VendorDocumentCleanup).discardUnsubmittedDocuments(
            documents,
          );
        }
        return;
      }
      final previous = _documents;
      _documents = documents;
      if (_recovery == null &&
          provider is VendorDocumentCleanup &&
          !_submissionStarted) {
        await (provider as VendorDocumentCleanup).discardUnsubmittedDocuments(
          previous,
        );
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        _message = _copy(
          context,
          'Documents were not collected. Retry with a clear photo and an active connection.',
          'ஆவணங்களைச் சேகரிக்க முடியவில்லை. தெளிவான படத்துடனும் இணைய இணைப்புடனும் மீண்டும் முயற்சிக்கவும்.',
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _discardDocuments() async {
    final recovery = _recovery;
    if (recovery == null || _busy) return;
    final generation = ++_generation;
    setState(() => _busy = true);
    try {
      await recovery.discardSavedDocuments();
      if (!mounted || generation != _generation) return;
      _documents = const [];
      _submissionStarted = false;
      _message = _copy(
        context,
        'Saved documents cleared. Refresh the application before collecting replacements.',
        'சேமித்த ஆவணங்கள் அழிக்கப்பட்டன. மாற்று ஆவணங்களுக்கு முன் விண்ணப்பத்தைப் புதுப்பிக்கவும்.',
      );
    } catch (_) {
      if (mounted && generation == _generation) {
        _message = _copy(
          context,
          'Saved documents could not be cleared. Retry with an active connection.',
          'சேமித்த ஆவணங்களை அழிக்க முடியவில்லை. இணைய இணைப்புடன் மீண்டும் முயற்சிக்கவும்.',
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    final generation = _generation;
    final controller = widget.controller;
    final recovery = _recovery;
    final documents = List<VendorOnboardingDocument>.of(_documents);
    final ids = documents.map((document) => document.assetId).toSet();
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await recovery?.prepareDocumentSubmission(ids);
      if (!mounted || generation != _generation) return;
      _submissionStarted = true;
      await controller.resubmitApplication(
        businessName: _businessName.text,
        businessType: _businessType.text,
        contactName: _contactName.text,
        documents: documents.map((document) => document.toJson()).toList(),
      );
      var cleanupPending = false;
      if (controller.state.status == OperationsStatus.ready) {
        try {
          await recovery?.forgetSubmittedDocuments(ids);
        } catch (_) {
          cleanupPending = true;
        }
      }
      if (!mounted || generation != _generation) return;
      if (controller.state.status != OperationsStatus.ready) {
        _message = _copy(
          context,
          'Submission could not be confirmed. Refresh the application before retrying.',
          'சமர்ப்பிப்பை உறுதிப்படுத்த முடியவில்லை. மீண்டும் முயற்சிக்கும் முன் விண்ணப்பத்தைப் புதுப்பிக்கவும்.',
        );
        return;
      }
      if (cleanupPending) {
        _message = _copy(
          context,
          'Corrections submitted. Saved progress cleanup is pending.',
          'திருத்தங்கள் சமர்ப்பிக்கப்பட்டன. சேமித்த முன்னேற்றத்தை அழிப்பது நிலுவையில் உள்ளது.',
        );
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        _message = _copy(
          context,
          'The private provider did not return a safe, complete result. Refresh the application.',
          'தனிப்பட்ட வழங்குநரிடமிருந்து பாதுகாப்பான முழுமையான முடிவு கிடைக்கவில்லை. விண்ணப்பத்தைப் புதுப்பிக்கவும்.',
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }
}

final class _VendorRegistrationCard extends StatefulWidget {
  const _VendorRegistrationCard({required this.controller});
  final VendorOperationsController controller;
  @override
  State<_VendorRegistrationCard> createState() =>
      _VendorRegistrationCardState();
}

class _VendorRegistrationCardState extends State<_VendorRegistrationCard> {
  final _form = GlobalKey<FormState>();
  final _business = TextEditingController();
  final _businessType = TextEditingController();
  final _contact = TextEditingController();
  bool _busy = false;
  bool _restoring = false;
  bool _submissionStarted = false;
  int _generation = 0;
  int _formIntent = 0;
  String? _message;

  @override
  void initState() {
    super.initState();
    for (final field in [_business, _businessType, _contact]) {
      field.addListener(_saveProgress);
    }
    _restoreProgress();
  }

  Future<void> _restoreProgress() async {
    final store = widget.controller.onboardingProgress;
    if (store == null) return;
    final generation = _generation;
    _restoring = _busy = true;
    try {
      final saved = await store.read();
      if (!mounted || generation != _generation) return;
      if (saved != null) {
        if (saved.applicationId.isEmpty && saved.applicationRevision == 0) {
          _business.text = saved.businessName;
          _businessType.text = saved.businessType;
          _contact.text = saved.contactName;
          _message = 'Your saved business form was restored.';
        } else {
          _message =
              'Saved corrections belong to an existing application and were not restored.';
        }
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        _message =
            'Saved business form could not be read. Re-enter the fields.';
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _restoring = _busy = false);
      }
    }
  }

  void _saveProgress() {
    final store = widget.controller.onboardingProgress;
    if (_restoring || _submissionStarted || store == null) return;
    final generation = _generation;
    final intent = ++_formIntent;
    final value = VendorOnboardingProgress(
      businessName: _business.text,
      businessType: _businessType.text,
      contactName: _contact.text,
    );
    unawaited(
      Future.sync(() => store.save(value)).catchError((Object _) {
        if (mounted && generation == _generation && intent == _formIntent) {
          setState(
            () => _message =
                'This form change could not be saved. Keep the app open or retry.',
          );
        }
      }),
    );
  }

  Future<void> _discardProgress() async {
    final store = widget.controller.onboardingProgress;
    if (store == null || _busy) return;
    final generation = _generation;
    setState(() => _busy = true);
    try {
      await store.clear();
      if (!mounted || generation != _generation) return;
      _restoring = true;
      _business.clear();
      _businessType.clear();
      _contact.clear();
      _message = 'Saved business form deleted.';
    } catch (_) {
      if (mounted && generation == _generation) {
        _message = 'Saved business form could not be deleted. Retry.';
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _restoring = _busy = false);
      }
    }
  }

  @override
  void didUpdateWidget(covariant _VendorRegistrationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    ++_generation;
    _busy = false;
    _submissionStarted = false;
    _restoring = true;
    _business.clear();
    _businessType.clear();
    _contact.clear();
    _restoring = false;
    _message = null;
    _restoreProgress();
  }

  @override
  void dispose() {
    ++_generation;
    _business.dispose();
    _businessType.dispose();
    _contact.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(Planext4uSpacing.x4),
      child: Form(
        key: _form,
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
            if (widget.controller.onboardingProgress != null) ...[
              const Text(
                'Business form fields are encrypted on this device for 7 days until registration. No document or bank details are stored here.',
              ),
              TextButton(
                key: const ValueKey('vendor-discard-onboarding-progress'),
                onPressed: _busy ? null : _discardProgress,
                child: const Text('Delete saved form'),
              ),
            ],
            if (_message != null)
              Semantics(liveRegion: true, child: Text(_message!)),
            TextFormField(
              key: const ValueKey('vendor-business-name'),
              controller: _business,
              enabled: !_busy,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Business name'),
              validator: (value) => (value?.trim().length ?? 0) < 3
                  ? 'Enter a business name.'
                  : null,
            ),
            TextFormField(
              key: const ValueKey('vendor-business-type'),
              controller: _businessType,
              enabled: !_busy,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Business type'),
              validator: (value) => (value?.trim().length ?? 0) < 3
                  ? 'Enter a business type.'
                  : null,
            ),
            TextFormField(
              key: const ValueKey('vendor-contact-name'),
              controller: _contact,
              enabled: !_busy,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Contact name'),
              validator: (value) => (value?.trim().length ?? 0) < 3
                  ? 'Enter a contact name.'
                  : null,
            ),
            const SizedBox(height: Planext4uSpacing.x3),
            FilledButton(
              key: const ValueKey('vendor-register'),
              onPressed: _busy ? null : _submit,
              child: const Text('Start verified onboarding'),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _submit() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    final controller = widget.controller;
    final generation = _generation;
    setState(() {
      _busy = true;
      _message = null;
    });
    _submissionStarted = true;
    await controller.register(
      businessName: _business.text.trim(),
      businessType: _businessType.text.trim(),
      contactName: _contact.text.trim(),
    );
    if (!mounted ||
        generation != _generation ||
        widget.controller != controller) {
      return;
    }
    setState(() {
      _busy = false;
      if (controller.state.status != OperationsStatus.ready) {
        _message =
            'Registration could not be confirmed. Refresh before retrying.';
      }
    });
  }
}

final class _RiderRegistrationCard extends StatefulWidget {
  const _RiderRegistrationCard({
    super.key,
    required this.controller,
    required this.provider,
    this.rework,
  });

  final RiderOperationsController controller;
  final RiderOnboardingProvider? provider;
  final RiderProfile? rework;

  @override
  State<_RiderRegistrationCard> createState() => _RiderRegistrationCardState();
}

class _RiderRegistrationCardState extends State<_RiderRegistrationCard> {
  final _form = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _vehicleNumber = TextEditingController();
  final _zones = TextEditingController();
  String _vehicleType = 'MOTORBIKE';
  bool _dutyLocationConsent = false;
  bool _busy = false;
  String? _message;
  List<RiderDocumentDraft> _documents = const [];
  int _generation = 0;
  bool _submissionStarted = false;
  bool _restoring = false;
  int _formIntent = 0;

  @override
  void initState() {
    super.initState();
    final current = widget.rework;
    if (current != null) {
      _fullName.text = current.fullName;
      _vehicleNumber.text = current.vehicleNumber;
      _zones.text = current.zones.join(', ');
      _vehicleType = current.vehicleType == 'BIKE'
          ? 'MOTORBIKE'
          : current.vehicleType;
    }
    for (final field in [_fullName, _vehicleNumber, _zones]) {
      field.addListener(_saveProgress);
    }
    _restoreProgress();
  }

  Future<void> _restoreProgress() async {
    final store = widget.controller.onboardingProgress;
    if (store == null) return;
    final generation = _generation;
    _restoring = _busy = true;
    try {
      final saved = await store.read();
      if (!mounted || generation != _generation) return;
      if (saved != null) {
        final current = widget.rework;
        final matchesApplication = current == null
            ? saved.applicationId.isEmpty && saved.applicationRevision == 0
            : saved.applicationId == current.id &&
                  saved.applicationRevision == current.revision;
        if (matchesApplication) {
          _fullName.text = saved.fullName;
          _vehicleNumber.text = saved.vehicleNumber;
          _zones.text = saved.postalCodes;
          _vehicleType = saved.vehicleType;
          _message =
              'Your saved form is restored. Continue private documents and review consent again before submitting.';
        } else {
          _message =
              'A saved form belongs to another application review. Current server details are shown; you can delete the older saved form.';
        }
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        _message =
            'Saved form progress could not be read. You can re-enter the form.';
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _restoring = _busy = false;
        });
      }
    }
  }

  void _saveProgress() {
    final store = widget.controller.onboardingProgress;
    if (_restoring || store == null || _submissionStarted) return;
    final generation = _generation;
    final intent = ++_formIntent;
    final value = RiderOnboardingProgress(
      fullName: _fullName.text,
      vehicleType: _vehicleType,
      vehicleNumber: _vehicleNumber.text,
      postalCodes: _zones.text,
      applicationId: widget.rework?.id ?? '',
      applicationRevision: widget.rework?.revision ?? 0,
    );
    unawaited(
      Future.sync(() => store.save(value)).catchError((Object _) {
        if (mounted && generation == _generation && intent == _formIntent) {
          setState(
            () => _message =
                'This form change could not be saved. Keep the app open or retry before leaving.',
          );
        }
      }),
    );
  }

  Future<void> _discardProgress() async {
    final store = widget.controller.onboardingProgress;
    if (store == null || _busy) return;
    final generation = _generation;
    setState(() => _busy = true);
    try {
      await store.clear();
      if (!mounted || generation != _generation) return;
      _restoring = true;
      final current = widget.rework;
      _fullName.text = current?.fullName ?? '';
      _vehicleNumber.text = current?.vehicleNumber ?? '';
      _zones.text = current?.zones.join(', ') ?? '';
      _vehicleType = current == null
          ? 'MOTORBIKE'
          : current.vehicleType == 'BIKE'
          ? 'MOTORBIKE'
          : current.vehicleType;
      _dutyLocationConsent = false;
      _message = 'Saved form deleted.';
    } catch (_) {
      if (mounted && generation == _generation) {
        _message = 'Saved form could not be deleted. Retry.';
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _restoring = _busy = false;
        });
      }
    }
  }

  RiderDocumentOnboardingProvider? get _documentsProvider =>
      widget.provider is RiderDocumentOnboardingProvider
      ? widget.provider! as RiderDocumentOnboardingProvider
      : null;

  RecoverableOnboardingDocuments? get _documentRecovery {
    return _recoverableDocuments(widget.provider);
  }

  Future<void> _discardDocumentProgress() async {
    final recovery = _documentRecovery;
    if (recovery == null || _busy) return;
    final generation = ++_generation;
    setState(() => _busy = true);
    try {
      await recovery.discardSavedDocuments();
      if (!mounted || generation != _generation) return;
      _documents = const [];
      _submissionStarted = false;
      _message =
          'Saved document progress cleared. Refresh the current application before collecting replacements.';
    } catch (_) {
      if (mounted && generation == _generation) {
        _message =
            'Saved document progress could not be cleared. Retry with an active connection.';
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  @override
  void didUpdateWidget(covariant _RiderRegistrationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      ++_generation;
      _documents = const [];
      _submissionStarted = false;
      _busy = false;
      _restoring = true;
      _fullName.clear();
      _vehicleNumber.clear();
      _zones.clear();
      _vehicleType = 'MOTORBIKE';
      _dutyLocationConsent = false;
      _restoring = false;
      _restoreProgress();
    }
  }

  @override
  void dispose() {
    ++_generation;
    // Once submission starts its result may be ambiguous. Never delete evidence
    // that the server might already have attached to an application.
    if (!_submissionStarted && _documents.isNotEmpty) {
      unawaited(_documentsProvider?.discardUnsubmittedDocuments(_documents));
    }
    _fullName.dispose();
    _vehicleNumber.dispose();
    _zones.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Planext4uSectionHeader(
          title: 'Rider onboarding',
          subtitle:
              'Your documents are stored privately for verification. Bank details are handled by the bank verification provider.',
        ),
        if (widget.rework case final RiderProfile current) ...[
          Text(
            'Corrections requested: ${current.reviewReason}',
            key: const ValueKey('rider-rework-reason'),
          ),
          const Text(
            'Upload corrected evidence and review consent again. Your application will return to independent review.',
          ),
        ],
        const SizedBox(height: Planext4uSpacing.x3),
        if (widget.controller.onboardingProgress != null) ...[
          const Text(
            'Form fields are encrypted on this device for 7 days. Review consent again before submitting.',
          ),
          TextButton(
            key: const ValueKey('rider-discard-onboarding-progress'),
            onPressed: _busy ? null : _discardProgress,
            child: const Text('Delete saved form'),
          ),
        ],
        if (widget.provider == null)
          const _OnboardingProviderUnavailable(
            key: ValueKey('rider-register-provider-unavailable'),
            capability: 'Rider KYC and bank verification',
          ),
        if (_documentsProvider
            case final RiderDocumentOnboardingProvider provider) ...[
          if (!provider.canTokenizeBankAccount)
            const _OnboardingProviderUnavailable(
              capability: 'Bank verification',
            ),
          Text(
            _documents.isEmpty
                ? 'Step 1: privately upload your required documents.'
                : (_documentRecovery != null
                      ? '${_documents.length} private documents checked for this registration. Progress can be continued after restart. Uploading does not approve KYC.'
                      : '${_documents.length} private documents ready for this registration screen. Uploading does not approve KYC. Unsubmitted documents are not saved after leaving this screen.'),
          ),
          OutlinedButton.icon(
            key: const ValueKey('rider-collect-documents'),
            onPressed: _busy || !provider.canCollectDocuments
                ? null
                : _collectDocuments,
            icon: const Icon(Icons.document_scanner_outlined),
            label: Text(
              _documents.isEmpty
                  ? (_documentRecovery != null
                        ? 'Continue private documents'
                        : 'Upload identity and vehicle documents')
                  : 'Replace documents',
            ),
          ),
          if (_documentRecovery != null) ...[
            const Text(
              'Private document progress is encrypted for 7 days and rechecked with the server when you continue. Clear saved progress before changing vehicle type. Submitted evidence follows the verification retention policy.',
            ),
            TextButton(
              key: const ValueKey('rider-discard-private-document-progress'),
              onPressed: _busy ? null : _discardDocumentProgress,
              child: const Text('Clear saved document progress'),
            ),
          ],
        ],
        if (_message != null)
          Semantics(
            liveRegion: true,
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(_message!),
              ),
            ),
          ),
        TextFormField(
          key: const ValueKey('rider-registration-name'),
          controller: _fullName,
          enabled: !_busy,
          maxLength: 120,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Full name'),
          validator: (value) {
            final length = value?.trim().length ?? 0;
            return length < 2 ? 'Enter your full name.' : null;
          },
        ),
        const SizedBox(height: Planext4uSpacing.x2),
        DropdownButtonFormField<String>(
          key: const ValueKey('rider-registration-vehicle-type'),
          initialValue: _vehicleType,
          decoration: const InputDecoration(labelText: 'Vehicle type'),
          items: const [
            DropdownMenuItem(value: 'BICYCLE', child: Text('Bicycle')),
            DropdownMenuItem(value: 'MOTORBIKE', child: Text('Motorbike')),
            DropdownMenuItem(value: 'CAR', child: Text('Car')),
            DropdownMenuItem(value: 'VAN', child: Text('Van')),
          ],
          onChanged: _busy
              ? null
              : (value) {
                  if (value != null) setState(() => _vehicleType = value);
                  ++_generation;
                  final previous = _documents;
                  _documents = const [];
                  _saveProgress();
                  if (!_submissionStarted) {
                    unawaited(
                      _documentsProvider?.discardUnsubmittedDocuments(previous),
                    );
                  }
                },
        ),
        const SizedBox(height: Planext4uSpacing.x2),
        TextFormField(
          key: const ValueKey('rider-registration-vehicle-number'),
          controller: _vehicleNumber,
          enabled: !_busy,
          maxLength: 20,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Vehicle number'),
          validator: (value) =>
              !RegExp(r'^[A-Za-z0-9 -]{4,20}$').hasMatch(value?.trim() ?? '')
              ? 'Enter a valid vehicle number.'
              : null,
        ),
        const SizedBox(height: Planext4uSpacing.x2),
        TextFormField(
          key: const ValueKey('rider-registration-zones'),
          controller: _zones,
          maxLength: 240,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Service postal codes',
            helperText: 'Comma-separated, 4–10 digits each.',
          ),
          validator: (value) {
            final zones = _normalizedZones(value);
            return zones.isEmpty ||
                    zones.any(
                      (zone) => !RegExp(r'^[0-9]{4,10}$').hasMatch(zone),
                    )
                ? 'Enter valid service postal codes.'
                : null;
          },
        ),
        CheckboxListTile(
          key: const ValueKey('rider-duty-location-consent'),
          contentPadding: EdgeInsets.zero,
          value: _dutyLocationConsent,
          onChanged: _busy
              ? null
              : (value) =>
                    setState(() => _dutyLocationConsent = value ?? false),
          title: const Text(
            'I agree to share location only while I am on duty.',
          ),
          subtitle: const Text(
            'Duty cannot start without this consent. Location stops when duty ends.',
          ),
        ),
        const SizedBox(height: Planext4uSpacing.x2),
        FilledButton.icon(
          key: const ValueKey('rider-submit-registration'),
          onPressed:
              widget.provider == null ||
                  _busy ||
                  (_documentsProvider != null &&
                      (!_documentsProvider!.canTokenizeBankAccount ||
                          _documents.isEmpty))
              ? null
              : _submit,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.verified_user_outlined),
          label: const Text('Verify and submit'),
        ),
      ],
    ),
  );

  Future<void> _collectDocuments() async {
    final provider = _documentsProvider;
    if (_busy || provider == null) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final documents = await provider.collectDocuments(
        vehicleType: _vehicleType,
      );
      if (!mounted || generation != _generation) {
        await provider.discardUnsubmittedDocuments(documents);
        return;
      }
      final previous = _documents;
      _documents = documents;
      if (!_submissionStarted) {
        await provider.discardUnsubmittedDocuments(previous);
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        _message =
            'Documents were not collected. Retry with a clear photo and an active connection.';
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (!_dutyLocationConsent) {
      setState(() {
        _message = 'Duty-location consent is required before registration.';
      });
      return;
    }
    final provider = widget.provider;
    if (provider == null) return;
    final generation = _generation;
    final controller = widget.controller;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final staged = _documentsProvider;
      final evidence = staged == null
          ? await provider.collectEvidence(vehicleType: _vehicleType)
          : RiderOnboardingEvidence(
              documents: _documents,
              bankReference: await staged.tokenizeBankAccount(),
            );
      if (!mounted || generation != _generation) return;
      final ids = evidence.documents.map((value) => value.assetId).toSet();
      final recovery = _documentRecovery;
      await recovery?.prepareDocumentSubmission(ids);
      if (!mounted || generation != _generation) return;
      _submissionStarted = true;
      final submit = widget.rework == null
          ? controller.register
          : controller.resubmit;
      await submit(
        RiderRegistrationDraft(
          fullName: _fullName.text,
          vehicleType: _vehicleType,
          vehicleNumber: _vehicleNumber.text,
          documents: evidence.documents,
          bankReference: evidence.bankReference,
          zones: _normalizedZones(_zones.text),
          dutyLocationConsent: _dutyLocationConsent,
        ),
      );
      var cleanupPending = false;
      if (controller.state.status == OperationsStatus.ready) {
        try {
          await recovery?.forgetSubmittedDocuments(ids);
        } catch (_) {
          cleanupPending = true;
        }
      }
      if (!mounted || generation != _generation) return;
      if (controller.state.status != OperationsStatus.ready) {
        _message =
            'Submission could not be confirmed. Refresh the application before retrying.';
      } else if (cleanupPending) {
        _message =
            'Registration submitted. Saved progress cleanup is pending; refresh the current application before collecting replacements.';
      }
    } catch (_) {
      if (!mounted || generation != _generation) return;
      _message =
          'The onboarding provider did not return a safe, complete result.';
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  static List<String> _normalizedZones(String? value) => (value ?? '')
      .split(',')
      .map((zone) => zone.trim())
      .where((zone) => zone.isNotEmpty)
      .toSet()
      .toList(growable: false);
}

final class RiderOperationsView extends StatefulWidget {
  const RiderOperationsView({
    required this.controller,
    required this.destination,
    this.onboardingProvider,
    this.onNavigate,
    this.onCapturePhoto,
    this.onCaptureSignature,
    this.identityProfileController,
    this.sessionManagementController,
    this.notificationPreferencesController,
    this.supportController,
    this.appearancePreferencesController,
    this.accountPrivacyController,
    super.key,
  });
  final RiderOperationsController controller;
  final RoleDestination destination;
  final RiderOnboardingProvider? onboardingProvider;
  final RiderNavigationAction? onNavigate;
  final RiderEvidenceCapture? onCapturePhoto;
  final RiderSignatureEvidenceUpload? onCaptureSignature;
  final IdentityProfileController? identityProfileController;
  final IdentitySessionManagementController? sessionManagementController;
  final NotificationPreferencesController? notificationPreferencesController;
  final SupportController? supportController;
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
                TextButton(
                  onPressed: widget.controller.clearMessage,
                  child: const Text('Dismiss'),
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
    'emergency' when widget.controller.state.emergencyIncident != null =>
      widget.controller.refreshEmergencyIncident(),
    _ => widget.controller.load(),
  };

  Widget _duty(RiderOperationsState state) {
    final profile = state.profile;
    if (profile == null) {
      return _RiderRegistrationCard(
        controller: widget.controller,
        provider: widget.onboardingProvider,
      );
    }
    if (profile.status == 'SUSPENDED' &&
        profile.reworkAllowed &&
        profile.allowedActions.contains('RESUBMIT_APPLICATION')) {
      return _RiderRegistrationCard(
        key: ValueKey('rider-rework-${profile.id}-${profile.revision}'),
        controller: widget.controller,
        provider: widget.onboardingProvider,
        rework: profile,
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
              : widget.controller.deliveryLocationAllowed
              ? widget.controller.startDuty
              : null,
          child: Text(active ? 'End duty' : 'Start duty'),
        ),
        if (widget.controller.deliveryPrivacyEnforced &&
            !widget.controller.deliveryPolicyAvailable)
          const Text(
            'Duty-location privacy rules are unavailable. Refresh when connected before starting location sharing.',
          ),
        if (widget.controller.deliveryPrivacyEnforced &&
            widget.controller.deliveryPolicyAvailable &&
            !widget.controller.deliveryLocationAllowed) ...[
          const Text(
            'Your device shares location while duty is active to assign deliveries and protect the route. Sharing stops when you end duty or withdraw this choice.',
          ),
          OutlinedButton(
            onPressed: state.status == OperationsStatus.submitting
                ? null
                : widget.controller.allowDeliveryLocation,
            child: const Text('Allow duty location'),
          ),
        ],
        if (active &&
            widget.controller.deliveryLocationAllowed &&
            state.locationStatus != RiderLocationStatus.tracking)
          OutlinedButton(
            onPressed: widget.controller.load,
            child: const Text('Resume duty location'),
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
    if (widget.controller.deliveryPrivacyEnforced &&
        !widget.controller.deliveryLocationAllowed) {
      return const Planext4uStatePanel(
        state: Planext4uViewState.permissionDenied,
        title: 'Duty location paused',
        message:
            'Review your duty-location privacy choice below before sharing location.',
      );
    }
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
    final incident = state.emergencyIncident;
    final onDuty =
        state.duty != null &&
        const {'ACTIVE', 'ONLINE'}.contains(state.duty!.status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Safety centre', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: Planext4uSpacing.x3),
        const Planext4uStatePanel(
          state: Planext4uViewState.empty,
          title: 'Use local emergency services first',
          message:
              'If anyone is in immediate danger, contact the local emergency number. Planext4u responder activation depends on approved regional availability.',
        ),
        const SizedBox(height: Planext4uSpacing.x3),
        if (incident == null && !onDuty)
          const Planext4uStatePanel(
            state: Planext4uViewState.permissionDenied,
            title: 'Start duty to use rider SOS',
            message:
                'Rider emergency incidents require a verified active duty session.',
          )
        else if (incident == null) ...[
          FilledButton.icon(
            key: const ValueKey('create-rider-emergency'),
            onPressed: state.status == OperationsStatus.submitting
                ? null
                : _openEmergencyDialog,
            icon: const Icon(Icons.sos),
            label: const Text('Request emergency assistance'),
          ),
          const SizedBox(height: Planext4uSpacing.x2),
          const Text(
            'A fresh on-duty location and explicit consent are required. Emergency requests are never queued offline.',
            textAlign: TextAlign.center,
          ),
        ] else
          Card(
            key: ValueKey('rider-emergency-${incident.id}'),
            child: Padding(
              padding: const EdgeInsets.all(Planext4uSpacing.x4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.emergency_outlined),
                      const SizedBox(width: Planext4uSpacing.x2),
                      Expanded(
                        child: Text(
                          'Emergency incident active',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Planext4uStatusPill(
                        label: incident.status.replaceAll('_', ' '),
                        tone: incident.status == 'RESOLVED'
                            ? Planext4uStatusTone.neutral
                            : Planext4uStatusTone.danger,
                      ),
                    ],
                  ),
                  const SizedBox(height: Planext4uSpacing.x2),
                  Text('Reference ${incident.id}'),
                  Text(
                    'Escalation level ${incident.escalationLevel} • response target ${TimeOfDay.fromDateTime(incident.slaDeadline.toLocal()).format(context)}',
                  ),
                  Text(
                    incident.assignedResponder.isEmpty
                        ? 'Awaiting an approved responder. Continue to use local emergency services for immediate danger.'
                        : 'A responder has been assigned.',
                  ),
                  const SizedBox(height: Planext4uSpacing.x3),
                  Wrap(
                    spacing: Planext4uSpacing.x2,
                    runSpacing: Planext4uSpacing.x2,
                    children: [
                      OutlinedButton.icon(
                        key: const ValueKey('refresh-rider-emergency'),
                        onPressed: widget.controller.refreshEmergencyIncident,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh status'),
                      ),
                      if (incident.status != 'RESOLVED')
                        OutlinedButton.icon(
                          key: const ValueKey(
                            'toggle-rider-emergency-location',
                          ),
                          onPressed: () =>
                              widget.controller.setEmergencyLocationConsent(
                                !incident.locationConsent,
                              ),
                          icon: Icon(
                            incident.locationConsent
                                ? Icons.location_off_outlined
                                : Icons.my_location,
                          ),
                          label: Text(
                            incident.locationConsent
                                ? 'Stop location sharing'
                                : 'Share current location',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
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

  Future<void> _openEmergencyDialog() async {
    final description = TextEditingController(
      text: 'Rider requested urgent safety assistance while on duty',
    );
    var category = 'SAFETY';
    var consent = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Request emergency assistance?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Use local emergency services first for immediate danger. Planext4u regional responder activation may be unavailable.',
                ),
                const SizedBox(height: Planext4uSpacing.x3),
                DropdownButtonFormField<String>(
                  key: const ValueKey('rider-emergency-category'),
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Incident type'),
                  items: const [
                    DropdownMenuItem(
                      value: 'SAFETY',
                      child: Text('Safety concern'),
                    ),
                    DropdownMenuItem(
                      value: 'ACCIDENT',
                      child: Text('Accident'),
                    ),
                    DropdownMenuItem(value: 'MEDICAL', child: Text('Medical')),
                    DropdownMenuItem(value: 'FIRE', child: Text('Fire')),
                    DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => category = value);
                  },
                ),
                TextField(
                  key: const ValueKey('rider-emergency-description'),
                  controller: description,
                  maxLength: 2000,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'What happened?',
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                CheckboxListTile(
                  key: const ValueKey('rider-emergency-consent'),
                  contentPadding: EdgeInsets.zero,
                  value: consent,
                  onChanged: (value) =>
                      setDialogState(() => consent = value ?? false),
                  title: const Text(
                    'I consent to share my current precise location for this incident.',
                  ),
                  subtitle: const Text('Location sharing can be revoked.'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('confirm-rider-emergency'),
              onPressed: consent && description.text.trim().length >= 5
                  ? () => Navigator.of(context).pop(true)
                  : null,
              child: const Text('Create SOS incident'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      await widget.controller.createEmergencyIncident(
        category: category,
        description: description.text,
        locationConsent: consent,
      );
    }
    description.dispose();
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
        if (widget.identityProfileController != null)
          ListTile(
            key: const ValueKey('rider-edit-identity-profile'),
            leading: const Icon(Icons.manage_accounts_outlined),
            title: const Text('Personal profile'),
            subtitle: const Text(
              'Edit your display name, language and time zone',
            ),
            onTap: () => _openIdentityProfile(
              context,
              widget.identityProfileController!,
            ),
          ),
        ListTile(
          key: const ValueKey('rider-support'),
          leading: const Icon(Icons.support_agent),
          title: const Text('Rider support'),
          subtitle: const Text(
            'Tasks, POD, attendance, safety and payout help',
          ),
          onTap: widget.supportController == null
              ? null
              : () => _openSupport(context, widget.supportController!),
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

Future<void> _openIdentityProfile(
  BuildContext context,
  IdentityProfileController controller,
) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => IdentityProfileScreen(controller: controller),
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

Future<void> _openSupport(BuildContext context, SupportController controller) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SupportScreen(controller: controller),
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
  final RiderSignatureEvidenceUpload? onCaptureSignature;

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
              Wrap(
                spacing: Planext4uSpacing.x2,
                runSpacing: Planext4uSpacing.x2,
                children: [
                  FilledButton(
                    key: ValueKey('accept-${task.id}'),
                    onPressed: remaining > 0
                        ? () => controller.accept(task)
                        : null,
                    child: const Text('Accept delivery'),
                  ),
                  if (task.allowedActions.contains('DECLINE'))
                    OutlinedButton(
                      key: ValueKey('decline-${task.id}'),
                      onPressed: remaining > 0 ? () => _decline(context) : null,
                      child: const Text('Decline'),
                    ),
                ],
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
                      : 'Delivery evidence verified',
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

  Future<void> _decline(BuildContext context) async {
    final note = TextEditingController();
    var reason = RiderOfferDeclineReason.tooFar;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final noteRequired = reason == RiderOfferDeclineReason.other;
          final ready = !noteRequired || note.text.trim().length >= 3;
          return AlertDialog(
            title: const Text('Decline delivery offer?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'This hides the offer for you. Other eligible riders can still accept it.',
                ),
                const SizedBox(height: Planext4uSpacing.x3),
                DropdownButtonFormField<RiderOfferDeclineReason>(
                  key: const ValueKey('offer-decline-reason'),
                  initialValue: reason,
                  decoration: const InputDecoration(labelText: 'Reason'),
                  items: [
                    for (final value in RiderOfferDeclineReason.values)
                      DropdownMenuItem(value: value, child: Text(value.label)),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => reason = value);
                  },
                ),
                const SizedBox(height: Planext4uSpacing.x3),
                TextField(
                  key: const ValueKey('offer-decline-note'),
                  controller: note,
                  maxLength: 240,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: InputDecoration(
                    labelText: noteRequired
                        ? 'Note (required)'
                        : 'Note (optional)',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep offer'),
              ),
              FilledButton(
                key: const ValueKey('confirm-offer-decline'),
                onPressed: ready ? () => Navigator.pop(context, true) : null,
                child: const Text('Decline offer'),
              ),
            ],
          );
        },
      ),
    );
    if (confirmed == true) {
      await controller.decline(task, reason: reason, note: note.text);
    }
    note.dispose();
  }

  Future<void> _complete(BuildContext context) async {
    final otp = TextEditingController();
    final signatureBoundary = GlobalKey();
    final signatureStrokes = <List<Offset>>[];
    String photoAssetId = '';
    String signatureAssetId = '';
    String? captureMessage;
    bool signatureUploading = false;
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
                              try {
                                final value = await onCapturePhoto!(task);
                                if (!context.mounted) return;
                                setDialogState(() {
                                  if (value?.isNotEmpty == true) {
                                    photoAssetId = value!;
                                    captureMessage =
                                        'Privacy-processed photo uploaded.';
                                  } else {
                                    captureMessage = 'Photo capture cancelled.';
                                  }
                                });
                              } catch (_) {
                                if (!context.mounted) return;
                                setDialogState(() {
                                  captureMessage =
                                      'The private photo provider is unavailable.';
                                });
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
                    Semantics(
                      label: 'Recipient signature drawing area',
                      child: RepaintBoundary(
                        key: signatureBoundary,
                        child: Container(
                          key: const ValueKey('pod-signature-pad'),
                          height: 160,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            borderRadius: BorderRadius.circular(
                              Planext4uRadii.control,
                            ),
                          ),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanStart: signatureUploading
                                ? null
                                : (details) => setDialogState(
                                    () => signatureStrokes.add([
                                      details.localPosition,
                                    ]),
                                  ),
                            onPanUpdate: signatureUploading
                                ? null
                                : (details) => setDialogState(
                                    () => signatureStrokes.last.add(
                                      details.localPosition,
                                    ),
                                  ),
                            child: CustomPaint(
                              painter: _PodSignaturePainter(signatureStrokes),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        TextButton(
                          key: const ValueKey('clear-pod-signature'),
                          onPressed:
                              signatureStrokes.isEmpty || signatureUploading
                              ? null
                              : () => setDialogState(() {
                                  signatureStrokes.clear();
                                  signatureAssetId = '';
                                }),
                          child: const Text('Clear'),
                        ),
                        const Spacer(),
                        Text(
                          signatureAssetId.isEmpty
                              ? 'Not uploaded'
                              : 'Signature uploaded',
                        ),
                      ],
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('capture-pod-signature'),
                      onPressed:
                          onCaptureSignature == null ||
                              signatureStrokes.isEmpty ||
                              signatureUploading
                          ? null
                          : () async {
                              setDialogState(() => signatureUploading = true);
                              try {
                                final pngBytes = await _signaturePng(
                                  signatureBoundary,
                                  signatureStrokes,
                                );
                                if (!context.mounted) return;
                                final value = await onCaptureSignature!(
                                  task,
                                  pngBytes,
                                );
                                if (!context.mounted) return;
                                setDialogState(() {
                                  if (value?.isNotEmpty == true) {
                                    signatureAssetId = value!;
                                    captureMessage =
                                        'Recipient signature uploaded.';
                                  } else {
                                    captureMessage =
                                        'Signature upload cancelled.';
                                  }
                                });
                              } catch (error) {
                                assert(() {
                                  debugPrint(
                                    'POD signature encoding failed: $error',
                                  );
                                  return true;
                                }());
                                if (!context.mounted) return;
                                setDialogState(() {
                                  captureMessage =
                                      'The private signature provider is unavailable.';
                                });
                              } finally {
                                if (context.mounted) {
                                  setDialogState(
                                    () => signatureUploading = false,
                                  );
                                }
                              }
                            },
                      icon: signatureUploading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              signatureAssetId.isEmpty
                                  ? Icons.draw_outlined
                                  : Icons.check_circle_outline,
                            ),
                      label: Text(
                        signatureAssetId.isEmpty
                            ? 'Upload recipient signature'
                            : 'Signature captured',
                      ),
                    ),
                    if (onCaptureSignature == null)
                      const Text(
                        'Signature capture becomes available after the evidence provider is configured.',
                      ),
                  ],
                  if (captureMessage != null) ...[
                    const SizedBox(height: Planext4uSpacing.x2),
                    Semantics(liveRegion: true, child: Text(captureMessage!)),
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

  Future<Uint8List> _signaturePng(
    GlobalKey boundaryKey,
    List<List<Offset>> strokes,
  ) async {
    final surface =
        boundaryKey.currentContext?.findRenderObject() as RenderBox?;
    if (surface == null || !surface.hasSize || surface.size.isEmpty) {
      throw StateError('Signature surface is unavailable.');
    }
    const pixelRatio = 2.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(pixelRatio);
    canvas.drawRect(Offset.zero & surface.size, Paint()..color = Colors.white);
    _PodSignaturePainter([
      for (final stroke in strokes) List<Offset>.of(stroke),
    ]).paint(canvas, surface.size);
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (surface.size.width * pixelRatio).ceil(),
      (surface.size.height * pixelRatio).ceil(),
    );
    picture.dispose();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) throw StateError('Signature could not be encoded.');
    return data.buffer.asUint8List();
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

final class _PodSignaturePainter extends CustomPainter {
  const _PodSignaturePainter(this.strokes);

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        canvas.drawCircle(
          stroke.single,
          1.5,
          paint..style = PaintingStyle.fill,
        );
        paint.style = PaintingStyle.stroke;
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_PodSignaturePainter oldDelegate) => true;
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
