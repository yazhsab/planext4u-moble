import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';

import 'commerce.dart';
import 'localization.dart';
import 'transactions.dart';

abstract interface class PaymentProviderLauncher {
  Future<void> launch(CustomerPayment payment);
}

final class PaymentHandoffUnavailable implements Exception {
  const PaymentHandoffUnavailable();
}

final class UnavailablePaymentProviderLauncher
    implements PaymentProviderLauncher {
  const UnavailablePaymentProviderLauncher();

  @override
  Future<void> launch(CustomerPayment payment) async {
    throw const PaymentHandoffUnavailable();
  }
}

final class CheckoutReviewScreen extends StatefulWidget {
  const CheckoutReviewScreen({
    required this.cart,
    required this.controller,
    this.paymentLauncher = const UnavailablePaymentProviderLauncher(),
    super.key,
  });
  final CustomerCart cart;
  final TransactionController controller;
  final PaymentProviderLauncher paymentLauncher;
  @override
  State<CheckoutReviewScreen> createState() => _CheckoutReviewScreenState();
}

final class _CheckoutReviewScreenState extends State<CheckoutReviewScreen> {
  final _promotion = TextEditingController();
  String? _addressId;
  String? _slotId;
  int _walletPoints = 0;
  CustomerPaymentMethod? _method;
  bool _initialQuoteStarted = false;
  String? _providerMessage;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.controller.loadCheckout());
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _promotion.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    final state = widget.controller.state;
    if (!_initialQuoteStarted &&
        state.addresses.isNotEmpty &&
        state.slots.isNotEmpty) {
      _initialQuoteStarted = true;
      final serviceable = state.addresses.where((value) => value.serviceable);
      _addressId = serviceable.isEmpty ? null : serviceable.first.id;
      _slotId = state.slots.first.id;
      if (_addressId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _quote());
      }
    }
    setState(() {});
  }

  Future<void> _quote() async {
    if (_addressId == null || _slotId == null) return;
    final ok = await widget.controller.createQuote(
      cartRevision: widget.cart.revision,
      addressId: _addressId!,
      slotId: _slotId!,
      promotionCode: _promotion.text,
      walletPoints: _walletPoints,
    );
    if (ok && mounted) {
      setState(
        () => _method = widget.controller.state.quote!.paymentMethods.first,
      );
    }
  }

  Future<void> _place() async {
    final method = _method;
    if (method == null) return;
    final result = await widget.controller.place(method);
    if (!mounted || result == null) return;
    if (result.payment.pending && method != CustomerPaymentMethod.cod) {
      try {
        await widget.paymentLauncher.launch(result.payment);
      } catch (_) {
        if (mounted) {
          setState(() {
            _providerMessage =
                'Payment setup is temporarily unavailable. Your order is '
                'safe; check its payment status to continue.';
          });
        }
      }
      await widget.controller.recoverPayment();
    }
  }

  Future<void> _retryPayment() async {
    final payment = await widget.controller.retryPayment();
    if (!mounted || payment == null) return;
    try {
      await widget.paymentLauncher.launch(payment);
    } catch (_) {
      if (mounted) {
        setState(() {
          _providerMessage =
              'The payment window did not complete. Your order remains safe; '
              'you can retry or check status.';
        });
      }
    }
    await widget.controller.recoverPayment();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    final quote = state.quote;
    final strings = Planext4uLocalizations.of(context);
    if (state.status == TransactionStatus.loading && state.addresses.isEmpty) {
      return const Scaffold(
        appBar: _CheckoutAppBar(),
        body: Planext4uStatePanel(
          state: Planext4uViewState.loading,
          title: 'Preparing checkout',
          message: 'Loading your addresses, delivery times and points.',
        ),
      );
    }
    if (state.status == TransactionStatus.failure && state.addresses.isEmpty) {
      return Scaffold(
        appBar: const _CheckoutAppBar(),
        body: Planext4uStatePanel(
          state: Planext4uViewState.error,
          title: 'Checkout is unavailable',
          message: state.message ?? 'Try again.',
          actionLabel: 'Try again',
          onAction: widget.controller.loadCheckout,
        ),
      );
    }
    return Scaffold(
      appBar: const _CheckoutAppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Planext4uSpacing.x4),
          children: [
            if (_providerMessage != null)
              MaterialBanner(
                content: Text(_providerMessage!),
                actions: [
                  TextButton(
                    onPressed: widget.controller.recoverPayment,
                    child: const Text('Check payment status'),
                  ),
                ],
              ),
            if (state.message != null)
              MaterialBanner(
                content: Text(state.message!),
                actions: [
                  TextButton(onPressed: _quote, child: const Text('Refresh')),
                ],
              ),
            Text(
              strings.deliveryAddress,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            RadioGroup<String>(
              groupValue: _addressId,
              onChanged: (value) {
                setState(() => _addressId = value);
                _quote();
              },
              child: Column(
                children: [
                  for (final address in state.addresses)
                    RadioListTile<String>(
                      value: address.id,
                      enabled: address.serviceable,
                      title: Text(address.label),
                      subtitle: Text(
                        '${address.locality} • ${address.postalCode}'
                        '${address.serviceable ? '' : ' • Not serviceable'}',
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Planext4uSpacing.x3),
            Text(
              'Delivery time',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            RadioGroup<String>(
              groupValue: _slotId,
              onChanged: (value) {
                setState(() => _slotId = value);
                _quote();
              },
              child: Column(
                children: [
                  for (final slot in state.slots)
                    RadioListTile<String>(
                      value: slot.id,
                      title: Text(
                        '${_time(slot.windowStart)} – ${_time(slot.windowEnd)}',
                      ),
                      subtitle: Text('Delivery ${slot.fee.display()}'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Planext4uSpacing.x3),
            TextField(
              controller: _promotion,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Promotion code',
                suffixIcon: IconButton(
                  tooltip: 'Apply promotion',
                  onPressed: _quote,
                  icon: const Icon(Icons.arrow_forward),
                ),
              ),
              onSubmitted: (_) => _quote(),
            ),
            if (state.wallet != null && state.wallet!.balance > 0) ...[
              const SizedBox(height: Planext4uSpacing.x3),
              Semantics(
                label: 'Use Planext points',
                value: '$_walletPoints points',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Use Planext points',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text('Available: ${state.wallet!.balance} points'),
                    Slider(
                      value: _walletPoints.toDouble(),
                      max: state.wallet!.balance.toDouble(),
                      divisions: state.wallet!.balance.clamp(1, 100),
                      label: '$_walletPoints',
                      onChanged: (value) =>
                          setState(() => _walletPoints = value.round()),
                      onChangeEnd: (_) => _quote(),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: Planext4uSpacing.x4),
            if (quote == null)
              const Planext4uStatePanel(
                state: Planext4uViewState.loading,
                title: 'Calculating total',
                message: 'Prices, tax and fees come directly from Planext4u.',
              )
            else ...[
              Text(
                strings.orderReview,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              for (final item in quote.items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.itemName),
                  subtitle: Text('${item.variantName} × ${item.quantity}'),
                  trailing: Text(item.lineTotal.display()),
                ),
              const Divider(),
              _AmountRow('Subtotal', quote.subtotal.display()),
              _AmountRow('Promotion', '- ${quote.discount.display()}'),
              _AmountRow('Tax', quote.tax.display()),
              _AmountRow('Delivery & fees', quote.fees.display()),
              _AmountRow('Points', '- ${quote.walletApplied.display()}'),
              _AmountRow(strings.total, quote.total.display(), strong: true),
              const SizedBox(height: Planext4uSpacing.x4),
              Text(
                strings.payment,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Wrap(
                spacing: Planext4uSpacing.x2,
                children: [
                  for (final method in quote.paymentMethods)
                    ChoiceChip(
                      label: Text(
                        method == CustomerPaymentMethod.cod
                            ? strings.cashOnDelivery
                            : method.label,
                      ),
                      selected: _method == method,
                      onSelected: (_) => setState(() => _method = method),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: quote == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(Planext4uSpacing.x4),
              child: FilledButton.icon(
                onPressed:
                    state.status == TransactionStatus.placing ||
                        state.status == TransactionStatus.quoting
                    ? null
                    : state.payment?.allowedActions.contains('RETRY') == true
                    ? _retryPayment
                    : state.status == TransactionStatus.paymentPending
                    ? widget.controller.recoverPayment
                    : _place,
                icon: state.status == TransactionStatus.placing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_outline),
                label: Text(
                  state.payment?.allowedActions.contains('RETRY') == true
                      ? 'Retry payment • ${quote.total.display()}'
                      : state.status == TransactionStatus.paymentPending
                      ? 'Check payment status'
                      : 'Place order • ${quote.total.display()}',
                ),
              ),
            ),
    );
  }
}

final class _CheckoutAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _CheckoutAppBar();
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  @override
  Widget build(BuildContext context) =>
      AppBar(title: Text(Planext4uLocalizations.of(context).secureCheckout));
}

final class _AmountRow extends StatelessWidget {
  const _AmountRow(this.label, this.value, {this.strong = false});
  final String label;
  final String value;
  final bool strong;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Planext4uSpacing.x1),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          value,
          style: strong
              ? Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)
              : null,
        ),
      ],
    ),
  );
}

final class CustomerAddressesScreen extends StatefulWidget {
  const CustomerAddressesScreen({required this.controller, super.key});
  final TransactionController controller;

  @override
  State<CustomerAddressesScreen> createState() =>
      _CustomerAddressesScreenState();
}

final class _CustomerAddressesScreenState
    extends State<CustomerAddressesScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    if (widget.controller.state.addresses.isEmpty) {
      widget.controller.loadCheckout();
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

  Future<void> _edit([CustomerAddress? current]) async {
    final draft = await Navigator.of(context).push<CustomerAddressDraft>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _AddressEditor(current: current),
      ),
    );
    if (draft == null) return;
    final saved = await widget.controller.saveAddress(
      current: current,
      draft: draft,
    );
    if (!saved || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(current == null ? 'Address added' : 'Address updated'),
      ),
    );
  }

  Future<void> _delete(CustomerAddress value) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove address?'),
        content: Text(
          '${value.label} will no longer be available at checkout.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.controller.deleteAddress(value);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    return Scaffold(
      appBar: AppBar(title: const Text('Saved addresses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _edit,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add address'),
      ),
      body: SafeArea(
        child:
            state.status == TransactionStatus.loading && state.addresses.isEmpty
            ? const Planext4uStatePanel(
                state: Planext4uViewState.loading,
                title: 'Loading addresses',
                message: 'Checking saved delivery locations.',
              )
            : state.addresses.isEmpty
            ? Planext4uStatePanel(
                state: state.status == TransactionStatus.failure
                    ? Planext4uViewState.error
                    : Planext4uViewState.empty,
                title: state.status == TransactionStatus.failure
                    ? 'Couldn’t load addresses'
                    : 'No saved addresses',
                message:
                    state.message ?? 'Add a serviceable address for checkout.',
                actionLabel: 'Try again',
                onAction: widget.controller.loadCheckout,
              )
            : RefreshIndicator(
                onRefresh: widget.controller.loadCheckout,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    Planext4uSpacing.x4,
                    Planext4uSpacing.x4,
                    Planext4uSpacing.x4,
                    96,
                  ),
                  itemCount: state.addresses.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: Planext4uSpacing.x2),
                  itemBuilder: (context, index) {
                    final address = state.addresses[index];
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          address.serviceable
                              ? Icons.location_on_outlined
                              : Icons.location_off_outlined,
                        ),
                        title: Row(
                          children: [
                            Expanded(child: Text(address.label)),
                            if (address.isDefault)
                              const Chip(label: Text('Default')),
                          ],
                        ),
                        subtitle: Text(
                          [
                            if (address.line1.isNotEmpty) address.line1,
                            address.locality,
                            address.postalCode,
                            address.serviceable
                                ? 'Serviceable'
                                : 'Outside current service area',
                          ].join(' • '),
                        ),
                        isThreeLine: true,
                        onTap: () => _edit(address),
                        trailing: IconButton(
                          tooltip: 'Remove ${address.label}',
                          onPressed: state.addresses.length == 1
                              ? null
                              : () => _delete(address),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

final class _AddressEditor extends StatefulWidget {
  const _AddressEditor({this.current});
  final CustomerAddress? current;
  @override
  State<_AddressEditor> createState() => _AddressEditorState();
}

final class _AddressEditorState extends State<_AddressEditor> {
  final _form = GlobalKey<FormState>();
  late final _label = TextEditingController(text: widget.current?.label);
  late final _line1 = TextEditingController(text: widget.current?.line1);
  late final _line2 = TextEditingController(text: widget.current?.line2);
  late final _locality = TextEditingController(text: widget.current?.locality);
  late final _postal = TextEditingController(text: widget.current?.postalCode);
  late bool _default = widget.current?.isDefault ?? false;

  @override
  void dispose() {
    _label.dispose();
    _line1.dispose();
    _line2.dispose();
    _locality.dispose();
    _postal.dispose();
    super.dispose();
  }

  String? _required(String? value, String label, {int minimum = 2}) {
    final normalized = value?.trim() ?? '';
    if (normalized.length < minimum) return '$label is required.';
    return null;
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(
      context,
      CustomerAddressDraft(
        label: _label.text,
        line1: _line1.text,
        line2: _line2.text,
        locality: _locality.text,
        postalCode: _postal.text,
        latitude: widget.current?.latitude,
        longitude: widget.current?.longitude,
        isDefault: _default,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.current == null ? 'Add address' : 'Edit address'),
      actions: [TextButton(onPressed: _submit, child: const Text('Save'))],
    ),
    body: SafeArea(
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(Planext4uSpacing.x4),
          children: [
            TextFormField(
              controller: _label,
              textInputAction: TextInputAction.next,
              maxLength: 60,
              decoration: const InputDecoration(labelText: 'Label'),
              validator: (value) => _required(value, 'Label', minimum: 1),
            ),
            TextFormField(
              controller: _line1,
              textInputAction: TextInputAction.next,
              maxLength: 240,
              autofillHints: const [AutofillHints.streetAddressLine1],
              decoration: const InputDecoration(labelText: 'Address line 1'),
              validator: (value) =>
                  _required(value, 'Address line 1', minimum: 3),
            ),
            TextFormField(
              controller: _line2,
              textInputAction: TextInputAction.next,
              maxLength: 240,
              autofillHints: const [AutofillHints.streetAddressLine2],
              decoration: const InputDecoration(
                labelText: 'Address line 2 (optional)',
              ),
            ),
            TextFormField(
              controller: _locality,
              textInputAction: TextInputAction.next,
              maxLength: 100,
              autofillHints: const [AutofillHints.addressCity],
              decoration: const InputDecoration(labelText: 'Locality or city'),
              validator: (value) => _required(value, 'Locality'),
            ),
            TextFormField(
              controller: _postal,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              maxLength: 12,
              autofillHints: const [AutofillHints.postalCode],
              decoration: const InputDecoration(
                labelText: 'Postal or PIN code',
              ),
              validator: (value) => _required(value, 'Postal code', minimum: 3),
              onFieldSubmitted: (_) => _submit(),
            ),
            SwitchListTile(
              value: _default,
              onChanged: (value) => setState(() => _default = value),
              title: const Text('Use as default address'),
            ),
            const SizedBox(height: Planext4uSpacing.x4),
            FilledButton(onPressed: _submit, child: const Text('Save address')),
          ],
        ),
      ),
    ),
  );
}

final class CustomerActivityScreen extends StatefulWidget {
  const CustomerActivityScreen({
    required this.controller,
    this.paymentLauncher = const UnavailablePaymentProviderLauncher(),
    super.key,
  });
  final TransactionController controller;
  final PaymentProviderLauncher paymentLauncher;
  @override
  State<CustomerActivityScreen> createState() => _CustomerActivityScreenState();
}

final class _CustomerActivityScreenState extends State<CustomerActivityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    widget.controller.loadActivity();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _tabs.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _copyReferral(ReferralProfile referral) async {
    final value = referral.shareUrl.isEmpty ? referral.code : referral.shareUrl;
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Referral link copied.')));
    }
  }

  Future<void> _applyReferral() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Use referral code'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Referral code'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null) return;
    final applied = await widget.controller.applyReferral(code);
    if (applied && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Referral saved. Rewards unlock after your first paid order.',
          ),
        ),
      );
    }
  }

  Future<void> _refill(WalletRefillOffer offer) async {
    final method = offer.paymentMethods.isEmpty
        ? null
        : offer.paymentMethods.first;
    if (method == null) return;
    final payment = await widget.controller.createWalletRefill(offer, method);
    if (payment == null) return;
    try {
      await widget.paymentLauncher.launch(payment);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The payment window did not complete. You can check or retry it safely.',
            ),
          ),
        );
      }
    }
    await widget.controller.recoverPayment();
    await widget.controller.loadActivity();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    final strings = Planext4uLocalizations.of(context);
    return Column(
      children: [
        TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: strings.orders),
            Tab(text: strings.points),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [_orders(state), _wallet(state, strings)],
          ),
        ),
      ],
    );
  }

  Widget _orders(TransactionState state) {
    if (state.status == TransactionStatus.loading && state.orders.isEmpty) {
      return const Planext4uStatePanel(
        state: Planext4uViewState.loading,
        title: 'Loading orders',
        message: 'Checking your latest activity.',
      );
    }
    if (state.orders.isEmpty) {
      return Planext4uStatePanel(
        state: state.status == TransactionStatus.failure
            ? Planext4uViewState.error
            : Planext4uViewState.empty,
        title: state.status == TransactionStatus.failure
            ? 'Couldn’t load orders'
            : 'No orders yet',
        message: state.message ?? 'Your marketplace orders will appear here.',
        actionLabel: 'Refresh',
        onAction: widget.controller.loadActivity,
      );
    }
    return RefreshIndicator(
      onRefresh: widget.controller.loadActivity,
      child: ListView.builder(
        padding: const EdgeInsets.all(Planext4uSpacing.x4),
        itemCount: state.orders.length,
        itemBuilder: (context, index) {
          final order = state.orders[index];
          return Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.local_shipping_outlined),
              ),
              title: Text(order.status.replaceAll('_', ' ')),
              subtitle: Text('${order.id}\n${order.paymentMethod.label}'),
              isThreeLine: true,
              trailing: Text(order.total.display()),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => OrderDetailScreen(
                    order: order,
                    controller: widget.controller,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _wallet(TransactionState state, Planext4uLocalizations strings) {
    final wallet = state.wallet;
    final experience = widget.controller.walletExperience;
    if (wallet == null) {
      return const Planext4uStatePanel(
        state: Planext4uViewState.loading,
        title: 'Loading points',
        message: 'Reconciling your points ledger.',
      );
    }
    return RefreshIndicator(
      onRefresh: widget.controller.loadActivity,
      child: ListView(
        padding: const EdgeInsets.all(Planext4uSpacing.x4),
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(Planext4uSpacing.x5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(strings.availablePoints(wallet.balance)),
                  Text(
                    '${wallet.balance}',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text(
                    'Earn through purchases, referrals and eligible rewards.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Planext4uSpacing.x3),
          if (experience != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Planext4uSpacing.x4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invite and earn',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: Planext4uSpacing.x1),
                    Text(
                      'You earn ${experience.referral.senderPoints} points and your friend earns ${experience.referral.recipientPoints} after their first paid order.',
                    ),
                    const SizedBox(height: Planext4uSpacing.x2),
                    SelectableText(
                      experience.referral.code,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Wrap(
                      spacing: Planext4uSpacing.x2,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _copyReferral(experience.referral),
                          icon: const Icon(Icons.copy_outlined),
                          label: const Text('Copy invite'),
                        ),
                        if (experience.referral.pendingCode.isEmpty &&
                            !experience.referral.rewarded)
                          TextButton(
                            onPressed: _applyReferral,
                            child: const Text('I have a referral code'),
                          ),
                      ],
                    ),
                    if (experience.referral.pendingCode.isNotEmpty)
                      Text(
                        'Pending reward: ${experience.referral.pendingCode}',
                      ),
                  ],
                ),
              ),
            ),
            if (experience.refills.isNotEmpty) ...[
              const SizedBox(height: Planext4uSpacing.x3),
              Text(
                'Refill points',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: Planext4uSpacing.x2),
              for (final offer in experience.refills)
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.add_card_outlined),
                    ),
                    title: Text('${offer.totalPoints} points'),
                    subtitle: Text(
                      offer.bonusPoints == 0
                          ? offer.price.display()
                          : '${offer.price.display()} • includes ${offer.bonusPoints} bonus points',
                    ),
                    trailing: FilledButton(
                      onPressed: () => _refill(offer),
                      child: const Text('Refill'),
                    ),
                  ),
                ),
            ],
            if (experience.campaigns.isNotEmpty) ...[
              const SizedBox(height: Planext4uSpacing.x3),
              Text(
                'Ways to earn',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              for (final campaign in experience.campaigns)
                ListTile(
                  leading: const Icon(Icons.stars_outlined),
                  title: Text(campaign.title),
                  subtitle: Text(campaign.description),
                  trailing: Text('+${campaign.points}'),
                ),
            ],
            const SizedBox(height: Planext4uSpacing.x3),
            Text(
              'Points history',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
          for (final entry in wallet.entries.reversed)
            ListTile(
              leading: Icon(
                entry.deltaPoints >= 0
                    ? Icons.add_circle_outline
                    : Icons.remove_circle_outline,
              ),
              title: Text(entry.category.replaceAll('_', ' ')),
              subtitle: Text(
                entry.originalExpiryAt == null
                    ? entry.sourceReference
                    : '${entry.sourceReference} • expires ${entry.originalExpiryAt!.toLocal().toString().split(' ').first}',
              ),
              trailing: Text(
                '${entry.deltaPoints >= 0 ? '+' : ''}${entry.deltaPoints}',
                style: TextStyle(
                  color: entry.deltaPoints >= 0
                      ? Colors.green.shade700
                      : Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

final class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    required this.order,
    required this.controller,
    super.key,
  });
  final CustomerOrder order;
  final TransactionController controller;
  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

final class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late CustomerOrder _order = widget.order;
  Future<void> _cancel() async {
    final reason = await _textDialog('Request cancellation', 'Reason');
    if (reason == null) return;
    final value = await widget.controller.cancel(_order, reason);
    if (value != null && mounted) setState(() => _order = value);
  }

  Future<void> _return() async {
    final request = await showDialog<_ReturnRequest>(
      context: context,
      builder: (_) => _ReturnRequestDialog(lines: _order.lines),
    );
    if (request == null) return;
    final value = await widget.controller.requestReturn(
      _order,
      request.lines,
      request.reason,
    );
    if (value != null && mounted) setState(() => _order = value);
  }

  Future<void> _rate() async {
    final rating = await showDialog<_RatingRequest>(
      context: context,
      builder: (_) => const _RatingDialog(),
    );
    if (rating == null) return;
    final value = await widget.controller.rate(
      _order,
      rating.score,
      rating.comment,
    );
    if (value != null && mounted) setState(() => _order = value);
  }

  Future<String?> _textDialog(String title, String label) async {
    final input = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: input,
          decoration: InputDecoration(labelText: label),
          maxLength: 500,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () {
              final value = input.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    input.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(Planext4uLocalizations.of(context).orderTracking),
    ),
    body: ListView(
      padding: const EdgeInsets.all(Planext4uSpacing.x4),
      children: [
        Text(
          _order.status.replaceAll('_', ' '),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text('${_order.id} • ${_order.total.display()}'),
        Text(
          'Delivery ${_order.deliveryWindowStart.toLocal()} – '
          '${_order.deliveryWindowEnd.toLocal()}',
        ),
        const SizedBox(height: Planext4uSpacing.x4),
        Text('Items', style: Theme.of(context).textTheme.titleLarge),
        for (final line in _order.lines)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(line.itemName),
            subtitle: Text('${line.variantName} × ${line.quantity}'),
            trailing: Text(line.lineTotal.display()),
          ),
        if (_order.proof != null) ...[
          const SizedBox(height: Planext4uSpacing.x3),
          Card(
            child: ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: const Text('Proof of delivery verified'),
              subtitle: Text(
                _order.proof!.otpVerified
                    ? 'Recipient OTP verified'
                    : _order.proof!.recipientName?.isNotEmpty == true
                    ? 'Received by ${_order.proof!.recipientName}'
                    : 'Delivery evidence recorded',
              ),
            ),
          ),
        ],
        const SizedBox(height: Planext4uSpacing.x4),
        Text('Timeline', style: Theme.of(context).textTheme.titleLarge),
        for (final event in _order.timeline)
          ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: Text(event.status.replaceAll('_', ' ')),
            subtitle: Text(
              '${event.actor} • ${event.createdAt.toLocal()}${event.reason.isEmpty ? '' : '\n${event.reason}'}',
            ),
          ),
        const SizedBox(height: Planext4uSpacing.x4),
        Wrap(
          spacing: Planext4uSpacing.x2,
          runSpacing: Planext4uSpacing.x2,
          children: [
            if (_order.allowedActions.contains('REQUEST_CANCELLATION'))
              OutlinedButton(
                onPressed: _cancel,
                child: const Text('Cancel order'),
              ),
            if (_order.allowedActions.contains('CONFIRM_DELIVERY'))
              FilledButton(
                onPressed: () async {
                  final value = await widget.controller.confirmDelivery(_order);
                  if (value != null && mounted) setState(() => _order = value);
                },
                child: const Text('Confirm delivery'),
              ),
            if (_order.allowedActions.contains('REQUEST_RETURN'))
              OutlinedButton(
                onPressed: _return,
                child: const Text('Request return'),
              ),
            if (_order.allowedActions.contains('RATE_ORDER'))
              FilledButton(onPressed: _rate, child: const Text('Rate order')),
          ],
        ),
      ],
    ),
  );
}

final class _ReturnRequest {
  const _ReturnRequest(this.lines, this.reason);
  final List<Map<String, Object?>> lines;
  final String reason;
}

final class _ReturnRequestDialog extends StatefulWidget {
  const _ReturnRequestDialog({required this.lines});
  final List<CustomerOrderLine> lines;
  @override
  State<_ReturnRequestDialog> createState() => _ReturnRequestDialogState();
}

final class _ReturnRequestDialogState extends State<_ReturnRequestDialog> {
  final _reason = TextEditingController();
  late final Map<String, int> _quantities = {
    for (final line in widget.lines) line.variantId: 0,
  };

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reason.text.trim();
    final lines = <Map<String, Object?>>[
      for (final line in widget.lines)
        if ((_quantities[line.variantId] ?? 0) > 0)
          {
            'variant_id': line.variantId,
            'quantity': _quantities[line.variantId],
          },
    ];
    if (reason.isEmpty || lines.isEmpty) return;
    Navigator.pop(context, _ReturnRequest(lines, reason));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Request return'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final line in widget.lines)
            DropdownButtonFormField<int>(
              initialValue: _quantities[line.variantId],
              decoration: InputDecoration(
                labelText: '${line.itemName} • ${line.variantName}',
              ),
              items: [
                for (var quantity = 0; quantity <= line.quantity; quantity++)
                  DropdownMenuItem(
                    value: quantity,
                    child: Text(quantity == 0 ? 'Do not return' : '$quantity'),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => _quantities[line.variantId] = value ?? 0),
            ),
          TextField(
            controller: _reason,
            decoration: const InputDecoration(labelText: 'What went wrong?'),
            maxLength: 500,
            minLines: 2,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Back'),
      ),
      FilledButton(
        onPressed:
            _reason.text.trim().isNotEmpty &&
                _quantities.values.any((value) => value > 0)
            ? _submit
            : null,
        child: const Text('Submit return'),
      ),
    ],
  );
}

final class _RatingRequest {
  const _RatingRequest(this.score, this.comment);
  final int score;
  final String comment;
}

final class _RatingDialog extends StatefulWidget {
  const _RatingDialog();
  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

final class _RatingDialogState extends State<_RatingDialog> {
  final _comment = TextEditingController();
  int _score = 5;
  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Rate order'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: 'Rating',
          value: '$_score out of 5',
          child: Slider(
            value: _score.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            label: '$_score',
            onChanged: (value) => setState(() => _score = value.round()),
          ),
        ),
        TextField(
          controller: _comment,
          maxLength: 1000,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Comment (optional)'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Back'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          _RatingRequest(_score, _comment.text.trim()),
        ),
        child: const Text('Submit rating'),
      ),
    ],
  );
}

String _time(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  return '$hour:${local.minute.toString().padLeft(2, '0')} ${local.hour < 12 ? 'AM' : 'PM'}';
}
