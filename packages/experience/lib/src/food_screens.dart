import 'dart:async';

import 'package:flutter/material.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';

import 'food.dart';

final class CustomerFoodScreen extends StatefulWidget {
  const CustomerFoodScreen({required this.controller, super.key});
  final FoodController controller;

  @override
  State<CustomerFoodScreen> createState() => _CustomerFoodScreenState();
}

class _CustomerFoodScreenState extends State<CustomerFoodScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    if (widget.controller.state.restaurants.isEmpty) {
      unawaited(widget.controller.loadRestaurants());
    }
  }

  @override
  void didUpdateWidget(CustomerFoodScreen oldWidget) {
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
    if (state.status == FoodExperienceStatus.loading &&
        state.restaurants.isEmpty) {
      return const Planext4uStatePanel(
        state: Planext4uViewState.loading,
        title: 'Finding restaurants',
        message: 'Checking verified kitchens that serve your location.',
      );
    }
    if ((state.status == FoodExperienceStatus.failure ||
            state.status == FoodExperienceStatus.offline) &&
        state.restaurants.isEmpty) {
      return Planext4uStatePanel(
        state: state.status == FoodExperienceStatus.offline
            ? Planext4uViewState.offline
            : Planext4uViewState.error,
        title: state.status == FoodExperienceStatus.offline
            ? 'You’re offline'
            : 'Restaurants unavailable',
        message: state.message ?? 'Try again to load nearby restaurants.',
        actionLabel: 'Retry',
        onAction: widget.controller.loadRestaurants,
      );
    }
    return RefreshIndicator(
      onRefresh: widget.controller.loadRestaurants,
      child: ListView(
        key: const ValueKey('food-restaurant-list'),
        padding: const EdgeInsets.all(Planext4uSpacing.x4),
        children: [
          Text(
            'Food, delivered locally',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: Planext4uSpacing.x2),
          Text(
            'Menus, options and totals are confirmed by the server before payment.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (state.message != null)
            Padding(
              padding: const EdgeInsets.only(top: Planext4uSpacing.x3),
              child: MaterialBanner(
                content: Text(state.message!),
                actions: [
                  TextButton(
                    onPressed: widget.controller.loadRestaurants,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: Planext4uSpacing.x4),
          for (final restaurant in state.restaurants)
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(Planext4uSpacing.x3),
                leading: CircleAvatar(
                  child: Icon(
                    restaurant.verified
                        ? Icons.verified_outlined
                        : Icons.restaurant_outlined,
                  ),
                ),
                title: Text(restaurant.name),
                subtitle: Text(
                  '${restaurant.cuisine.join(' • ')}\n'
                  '${restaurant.rating.toStringAsFixed(1)} ★ • '
                  '${restaurant.preparationMinutes} min • '
                  '${restaurant.deliveryFee.display()} delivery',
                ),
                isThreeLine: true,
                trailing: restaurant.open
                    ? const Icon(Icons.chevron_right)
                    : const Chip(label: Text('Closed')),
                onTap: restaurant.open
                    ? () => _openRestaurant(restaurant)
                    : null,
              ),
            ),
          if (state.activeOrder != null)
            Padding(
              padding: const EdgeInsets.only(top: Planext4uSpacing.x4),
              child: OutlinedButton.icon(
                onPressed: () => _openOrder(state.activeOrder!),
                icon: const Icon(Icons.delivery_dining_outlined),
                label: Text('Track order ${state.activeOrder!.id}'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openRestaurant(FoodRestaurant restaurant) async {
    await widget.controller.openRestaurant(restaurant);
    if (!mounted || widget.controller.state.menu.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FoodMenuScreen(
          restaurant: restaurant,
          controller: widget.controller,
        ),
      ),
    );
  }

  void _openOrder(FoodOrder order) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FoodOrderTrackingScreen(
          controller: widget.controller,
          order: order,
        ),
      ),
    );
  }
}

final class FoodMenuScreen extends StatefulWidget {
  const FoodMenuScreen({
    required this.restaurant,
    required this.controller,
    super.key,
  });
  final FoodRestaurant restaurant;
  final FoodController controller;

  @override
  State<FoodMenuScreen> createState() => _FoodMenuScreenState();
}

class _FoodMenuScreenState extends State<FoodMenuScreen> {
  final Map<String, int> _quantity = {};
  final Map<String, Set<String>> _options = {};

  List<FoodCartLineRequest> get _lines => [
    for (final item in widget.controller.state.menu)
      if ((_quantity[item.id] ?? 0) > 0)
        FoodCartLineRequest(
          menuItemId: item.id,
          quantity: _quantity[item.id]!,
          optionIds: _options[item.id]?.toList() ?? const [],
        ),
  ];

  bool get _selectionValid {
    for (final item in widget.controller.state.menu) {
      if ((_quantity[item.id] ?? 0) == 0) continue;
      final selected = _options[item.id] ?? const <String>{};
      for (final group in item.optionGroups) {
        final count = group.options
            .where((option) => selected.contains(option.id))
            .length;
        if (count < group.minimum || count > group.maximum) return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    return Scaffold(
      appBar: AppBar(title: Text(widget.restaurant.name)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Planext4uSpacing.x4),
          children: [
            for (final item in state.menu)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Planext4uSpacing.x4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            item.vegetarian
                                ? Icons.eco_outlined
                                : Icons.restaurant_menu,
                            semanticLabel: item.vegetarian
                                ? 'Vegetarian'
                                : 'Non vegetarian',
                          ),
                          const SizedBox(width: Planext4uSpacing.x2),
                          Expanded(
                            child: Text(
                              item.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Text(item.basePrice.display()),
                        ],
                      ),
                      const SizedBox(height: Planext4uSpacing.x2),
                      Text(item.description),
                      for (final group in item.optionGroups) ...[
                        const SizedBox(height: Planext4uSpacing.x3),
                        Text(
                          '${group.name} (${group.minimum == 0 ? 'optional' : 'choose ${group.minimum}'})',
                        ),
                        for (final option in group.options)
                          CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value:
                                _options[item.id]?.contains(option.id) ?? false,
                            title: Text(option.name),
                            subtitle: option.priceDelta.amountMinor == 0
                                ? null
                                : Text('+${option.priceDelta.display()}'),
                            onChanged: option.available
                                ? (selected) {
                                    setState(() {
                                      final selectedOptions = _options
                                          .putIfAbsent(
                                            item.id,
                                            () => <String>{},
                                          );
                                      if (selected == true &&
                                          selectedOptions.length <
                                              group.maximum) {
                                        selectedOptions.add(option.id);
                                      } else if (selected == false) {
                                        selectedOptions.remove(option.id);
                                      }
                                    });
                                  }
                                : null,
                          ),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            tooltip: 'Remove one ${item.name}',
                            onPressed: (_quantity[item.id] ?? 0) == 0
                                ? null
                                : () => setState(
                                    () => _quantity[item.id] =
                                        (_quantity[item.id] ?? 1) - 1,
                                  ),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Semantics(
                            label: '${item.name} quantity',
                            child: Text('${_quantity[item.id] ?? 0}'),
                          ),
                          IconButton(
                            tooltip: 'Add one ${item.name}',
                            onPressed: item.available
                                ? () => setState(
                                    () => _quantity[item.id] =
                                        (_quantity[item.id] ?? 0) + 1,
                                  )
                                : null,
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(Planext4uSpacing.x4),
        child: FilledButton(
          key: const ValueKey('review-food-cart'),
          onPressed:
              _lines.isEmpty ||
                  !_selectionValid ||
                  state.status == FoodExperienceStatus.submitting
              ? null
              : _review,
          child: state.status == FoodExperienceStatus.submitting
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  'Review ${_lines.length} item${_lines.length == 1 ? '' : 's'}',
                ),
        ),
      ),
    );
  }

  Future<void> _review() async {
    final cart = await widget.controller.quote(widget.restaurant, _lines);
    if (!mounted || cart == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            FoodCheckoutScreen(controller: widget.controller, cart: cart),
      ),
    );
  }
}

final class FoodCheckoutScreen extends StatefulWidget {
  const FoodCheckoutScreen({
    required this.controller,
    required this.cart,
    super.key,
  });
  final FoodController controller;
  final FoodCart cart;

  @override
  State<FoodCheckoutScreen> createState() => _FoodCheckoutScreenState();
}

class _FoodCheckoutScreenState extends State<FoodCheckoutScreen> {
  String _paymentMethod = 'WALLET';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Review food order')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(Planext4uSpacing.x4),
        children: [
          Text(
            widget.cart.restaurant.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: Planext4uSpacing.x4),
          _amount('Subtotal', widget.cart.subtotal.display()),
          _amount('Delivery', widget.cart.deliveryFee.display()),
          _amount('Tax', widget.cart.tax.display()),
          const Divider(),
          _amount('Server-confirmed total', widget.cart.total.display()),
          const SizedBox(height: Planext4uSpacing.x2),
          Text('Pricing ${widget.cart.pricingVersion}'),
          Text('Valid until ${widget.cart.expiresAt.toLocal()}'),
          const SizedBox(height: Planext4uSpacing.x4),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'WALLET', label: Text('Wallet')),
              ButtonSegment(value: 'COD', label: Text('Cash')),
            ],
            selected: {_paymentMethod},
            onSelectionChanged: (value) =>
                setState(() => _paymentMethod = value.single),
          ),
          const SizedBox(height: Planext4uSpacing.x5),
          FilledButton.icon(
            key: const ValueKey('place-food-order'),
            onPressed: _place,
            icon: const Icon(Icons.lock_outline),
            label: Text('Place order • ${widget.cart.total.display()}'),
          ),
        ],
      ),
    ),
  );

  Widget _amount(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Planext4uSpacing.x1),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value),
      ],
    ),
  );

  Future<void> _place() async {
    final order = await widget.controller.place(paymentMethod: _paymentMethod);
    if (!mounted || order == null) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => FoodOrderTrackingScreen(
          controller: widget.controller,
          order: order,
        ),
      ),
    );
  }
}

final class FoodOrderTrackingScreen extends StatefulWidget {
  const FoodOrderTrackingScreen({
    required this.controller,
    required this.order,
    super.key,
  });
  final FoodController controller;
  final FoodOrder order;

  @override
  State<FoodOrderTrackingScreen> createState() =>
      _FoodOrderTrackingScreenState();
}

class _FoodOrderTrackingScreenState extends State<FoodOrderTrackingScreen> {
  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    final order = widget.controller.state.activeOrder ?? widget.order;
    return Scaffold(
      appBar: AppBar(title: const Text('Food order tracking')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: widget.controller.refreshActiveOrder,
          child: ListView(
            padding: const EdgeInsets.all(Planext4uSpacing.x4),
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  order.status.replaceAll('_', ' '),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: Planext4uSpacing.x2),
              Text('Order ${order.id}'),
              Text('${order.total.display()} • ${order.paymentStatus}'),
              if (order.isRefunded)
                const ListTile(
                  leading: Icon(Icons.currency_exchange),
                  title: Text('Refund completed'),
                  subtitle: Text(
                    'The captured amount was returned after the restaurant could not accept the order.',
                  ),
                ),
              const SizedBox(height: Planext4uSpacing.x4),
              for (final event in order.timeline)
                if (event is Map<String, Object?>)
                  ListTile(
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text(
                      (event['status'] as String? ?? 'UPDATE').replaceAll(
                        '_',
                        ' ',
                      ),
                    ),
                    subtitle: Text(event['created_at'] as String? ?? ''),
                  ),
              OutlinedButton.icon(
                onPressed: widget.controller.refreshActiveOrder,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh order'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
