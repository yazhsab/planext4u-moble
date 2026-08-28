import 'package:flutter/material.dart';
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
    widget.controller.loadCheckout();
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
      _addressId = state.addresses.first.id;
      _slotId = state.slots.first.id;
      WidgetsBinding.instance.addPostFrameCallback((_) => _quote());
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
                      title: Text(address.label),
                      subtitle: Text(
                        '${address.locality} • ${address.postalCode}',
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
                    : _place,
                icon: state.status == TransactionStatus.placing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_outline),
                label: Text(
                  state.status == TransactionStatus.paymentPending
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

final class CustomerActivityScreen extends StatefulWidget {
  const CustomerActivityScreen({required this.controller, super.key});
  final TransactionController controller;
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
    final reason = await _textDialog('Request return', 'What went wrong?');
    if (reason == null) return;
    final value = await widget.controller.requestReturn(_order, const [
      {'variant_id': 'selected-item', 'quantity': 1},
    ], reason);
    if (value != null && mounted) setState(() => _order = value);
  }

  Future<void> _rate() async {
    final value = await widget.controller.rate(
      _order,
      5,
      'Excellent local delivery',
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

String _time(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  return '$hour:${local.minute.toString().padLeft(2, '0')} ${local.hour < 12 ? 'AM' : 'PM'}';
}
