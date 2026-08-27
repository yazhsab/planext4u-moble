import 'package:flutter/material.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';

import 'catalog.dart';
import 'commerce.dart';
import 'marketplace.dart';

final class MarketplaceExploreScreen extends StatefulWidget {
  const MarketplaceExploreScreen({
    required this.controller,
    required this.onItemSelected,
    super.key,
  });

  final MarketplaceController controller;
  final ValueChanged<String> onItemSelected;

  @override
  State<MarketplaceExploreScreen> createState() =>
      _MarketplaceExploreScreenState();
}

final class _MarketplaceExploreScreenState
    extends State<MarketplaceExploreScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    if (widget.controller.state.status == MarketplaceStatus.idle) {
      widget.controller.discover();
    }
  }

  @override
  void didUpdateWidget(MarketplaceExploreScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _search.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(Planext4uSpacing.x4),
          child: SearchBar(
            controller: _search,
            hintText: 'Search local products and services',
            leading: const Icon(Icons.search),
            trailing: [
              IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  _search.clear();
                  widget.controller.discover();
                },
                icon: const Icon(Icons.close),
              ),
            ],
            onSubmitted: widget.controller.discover,
          ),
        ),
        Expanded(child: _results(state)),
      ],
    );
  }

  Widget _results(MarketplaceState state) {
    if (state.status == MarketplaceStatus.loading && state.results.isEmpty) {
      return const Planext4uStatePanel(
        state: Planext4uViewState.loading,
        title: 'Finding nearby products',
        message: 'Checking local availability and current prices.',
      );
    }
    if (state.status == MarketplaceStatus.failure && state.results.isEmpty) {
      return Planext4uStatePanel(
        state: Planext4uViewState.error,
        title: 'Search is unavailable',
        message: 'Try again without losing your query.',
        actionLabel: 'Try again',
        onAction: () => widget.controller.discover(_search.text),
      );
    }
    if (state.status == MarketplaceStatus.empty) {
      return Planext4uStatePanel(
        state: Planext4uViewState.empty,
        title: 'No matching products',
        message: 'Check the spelling or browse all nearby products.',
        actionLabel: 'Browse all',
        onAction: () {
          _search.clear();
          widget.controller.discover();
        },
      );
    }
    return RefreshIndicator(
      onRefresh: () => widget.controller.discover(state.query),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          Planext4uSpacing.x4,
          0,
          Planext4uSpacing.x4,
          Planext4uSpacing.x6,
        ),
        itemCount: state.results.length,
        separatorBuilder: (_, _) => const SizedBox(height: Planext4uSpacing.x3),
        itemBuilder: (context, index) {
          final item = state.results[index];
          return Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              minVerticalPadding: Planext4uSpacing.x3,
              leading: const SizedBox.square(
                dimension: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Color(0xFFE3F4F1)),
                  child: Icon(Icons.shopping_bag_outlined),
                ),
              ),
              title: Text(item.name),
              subtitle: Text(
                '${item.sellerName ?? item.summary}\n${item.price.display()}',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              enabled: item.available,
              onTap: item.available
                  ? () => widget.onItemSelected(item.id)
                  : null,
            ),
          );
        },
      ),
    );
  }
}

final class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    required this.itemId,
    required this.marketplace,
    required this.cart,
    required this.onViewCart,
    super.key,
  });

  final String itemId;
  final MarketplaceController marketplace;
  final CartController cart;
  final VoidCallback onViewCart;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

final class _ProductDetailScreenState extends State<ProductDetailScreen> {
  String? _variantId;

  @override
  void initState() {
    super.initState();
    widget.marketplace.addListener(_changed);
    widget.cart.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.marketplace.openItem(widget.itemId);
    });
  }

  @override
  void dispose() {
    widget.marketplace.removeListener(_changed);
    widget.cart.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  CatalogVariant? _selected(CatalogItem item) {
    if (item.variants.isEmpty) return null;
    return item.variants.firstWhere(
      (variant) => variant.id == _variantId,
      orElse: () => item.variants.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.marketplace.state;
    final item = state.selectedItem?.id == widget.itemId
        ? state.selectedItem
        : null;
    final selected = item == null ? null : _selected(item);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product details'),
        backgroundColor: Planext4uColors.navy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Add to favourites',
            onPressed: () {},
            icon: const Icon(Icons.favorite_border),
          ),
        ],
      ),
      body: item == null ? _productState(state) : _product(item, selected),
      bottomNavigationBar: item == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(Planext4uSpacing.x4),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: selected?.available == true
                          ? () => _add(selected!)
                          : null,
                      child: const Text('Add to cart'),
                    ),
                  ),
                  const SizedBox(width: Planext4uSpacing.x3),
                  Expanded(
                    child: FilledButton(
                      onPressed: selected?.available == true
                          ? () async {
                              if (await _add(selected!)) widget.onViewCart();
                            }
                          : null,
                      child: const Text('Buy now'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _productState(MarketplaceState state) {
    if (state.status == MarketplaceStatus.failure) {
      return Planext4uStatePanel(
        state: Planext4uViewState.error,
        title: 'Product unavailable',
        message: 'Refresh to check this product again.',
        actionLabel: 'Try again',
        onAction: () => widget.marketplace.openItem(widget.itemId),
      );
    }
    return const Planext4uStatePanel(
      state: Planext4uViewState.loading,
      title: 'Loading product',
      message: 'Checking current variants, price and availability.',
    );
  }

  Widget _product(CatalogItem item, CatalogVariant? selected) {
    final price = selected?.price ?? item.price;
    final compare = selected?.compareAtPrice;
    return DefaultTabController(
      length: 4,
      child: ListView(
        padding: const EdgeInsets.only(bottom: Planext4uSpacing.x6),
        children: [
          Container(
            height: 260,
            margin: const EdgeInsets.all(Planext4uSpacing.x4),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F4F1),
              borderRadius: BorderRadius.circular(Planext4uRadii.card),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.shopping_bag_outlined, size: 88),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Planext4uSpacing.x4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.verifiedLocalSeller)
                  const Planext4uStatusPill(
                    label: 'Verified local seller',
                    tone: Planext4uStatusTone.success,
                  ),
                const SizedBox(height: Planext4uSpacing.x3),
                Text(
                  item.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: Planext4uSpacing.x2),
                Row(
                  children: [
                    const Icon(Icons.star, color: Color(0xFFF59E0B), size: 20),
                    const SizedBox(width: Planext4uSpacing.x1),
                    Text(
                      '${item.ratingAverage?.toStringAsFixed(1) ?? 'New'} (${item.reviewCount} reviews)',
                    ),
                  ],
                ),
                const SizedBox(height: Planext4uSpacing.x3),
                Wrap(
                  spacing: Planext4uSpacing.x2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      price.display(),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (compare != null)
                      Text(
                        compare.display(),
                        style: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    if (compare != null)
                      Text(
                        '${(((compare.amountMinor - price.amountMinor) * 100) / compare.amountMinor).round()}% off',
                        style: const TextStyle(
                          color: Planext4uColors.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                if (item.variants.isNotEmpty) ...[
                  const SizedBox(height: Planext4uSpacing.x4),
                  Text('Size', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: Planext4uSpacing.x2),
                  Wrap(
                    spacing: Planext4uSpacing.x2,
                    children: [
                      for (final variant in item.variants)
                        ChoiceChip(
                          label: Text(variant.label),
                          selected: selected?.id == variant.id,
                          onSelected: variant.available
                              ? (_) => setState(() => _variantId = variant.id)
                              : null,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: Planext4uSpacing.x4),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.local_shipping_outlined),
                    title: const Text('Delivery to Coimbatore'),
                    subtitle: Text(
                      selected?.available == false
                          ? 'Currently unavailable'
                          : 'In stock • Delivery tomorrow',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
                const SizedBox(height: Planext4uSpacing.x4),
              ],
            ),
          ),
          const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Description'),
              Tab(text: 'Specs'),
              Tab(text: 'Reviews'),
              Tab(text: 'Q&A'),
            ],
          ),
          SizedBox(
            height: 220,
            child: TabBarView(
              children: [
                _TabCopy(item.description ?? item.summary),
                _Specifications(item.specifications),
                _TabCopy('${item.reviewCount} verified customer reviews'),
                const _TabCopy('Ask the local seller about this product.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _add(CatalogVariant variant) async {
    final added = await widget.cart.setItem(variant.id, 1);
    if (!mounted) return added;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added
              ? '${variant.label} added with the latest server price.'
              : widget.cart.state.message ?? 'Couldn’t update the cart.',
        ),
        action: added
            ? SnackBarAction(label: 'View cart', onPressed: widget.onViewCart)
            : null,
      ),
    );
    return added;
  }
}

final class _TabCopy extends StatelessWidget {
  const _TabCopy(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(Planext4uSpacing.x4),
    child: Text(value),
  );
}

final class _Specifications extends StatelessWidget {
  const _Specifications(this.values);
  final Map<String, String> values;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(Planext4uSpacing.x4),
    children: values.isEmpty
        ? const [Text('Specifications will be provided by the seller.')]
        : [
            for (final entry in values.entries)
              ListTile(
                dense: true,
                title: Text(entry.key),
                trailing: Text(entry.value),
              ),
          ],
  );
}

final class CustomerCartScreen extends StatefulWidget {
  const CustomerCartScreen({required this.controller, super.key});
  final CartController controller;

  @override
  State<CustomerCartScreen> createState() => _CustomerCartScreenState();
}

final class _CustomerCartScreenState extends State<CustomerCartScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    if (widget.controller.state.cart == null) widget.controller.load();
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
    final cart = state.cart;
    return Scaffold(
      appBar: AppBar(title: const Text('Your cart')),
      body: cart == null
          ? Planext4uStatePanel(
              state: state.status == CartStatus.failure
                  ? Planext4uViewState.error
                  : Planext4uViewState.loading,
              title: state.status == CartStatus.failure
                  ? 'Couldn’t load cart'
                  : 'Loading cart',
              message: 'Checking current prices and availability.',
              actionLabel: state.status == CartStatus.failure
                  ? 'Try again'
                  : null,
              onAction: state.status == CartStatus.failure
                  ? widget.controller.load
                  : null,
            )
          : _cart(cart, state),
      bottomNavigationBar: cart == null || cart.items.isEmpty
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(Planext4uSpacing.x4),
              child: FilledButton(
                onPressed: cart.canCheckout ? () {} : null,
                child: Text('Checkout • ${cart.total.display()}'),
              ),
            ),
    );
  }

  Widget _cart(CustomerCart cart, CartState state) {
    if (cart.items.isEmpty) {
      return const Planext4uStatePanel(
        state: Planext4uViewState.empty,
        title: 'Your cart is empty',
        message: 'Browse nearby products to start an order.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(Planext4uSpacing.x4),
      children: [
        if (state.message != null ||
            cart.pricingStatus == CartPricingStatus.repriced)
          MaterialBanner(
            content: Text(
              state.message ?? 'Prices changed. Review the refreshed totals.',
            ),
            actions: [
              TextButton(
                onPressed: widget.controller.load,
                child: const Text('Refresh'),
              ),
            ],
          ),
        for (final line in cart.items)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Planext4uSpacing.x3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.itemName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text('${line.variantName} • ${line.unitPrice.display()}'),
                  const SizedBox(height: Planext4uSpacing.x2),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Decrease ${line.itemName}',
                        onPressed: state.status == CartStatus.updating
                            ? null
                            : () => line.quantity == 1
                                  ? widget.controller.removeItem(line.variantId)
                                  : widget.controller.setItem(
                                      line.variantId,
                                      line.quantity - 1,
                                    ),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Semantics(
                        label: 'Quantity ${line.quantity}',
                        child: Text('${line.quantity}'),
                      ),
                      IconButton(
                        tooltip: 'Increase ${line.itemName}',
                        onPressed: state.status == CartStatus.updating
                            ? null
                            : () => widget.controller.setItem(
                                line.variantId,
                                line.quantity + 1,
                              ),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                      const Spacer(),
                      Text(
                        line.lineTotal.display(),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const Divider(),
        _TotalRow(label: 'Subtotal', value: cart.subtotal.display()),
        _TotalRow(label: 'Discount', value: cart.discount.display()),
        _TotalRow(label: 'Tax', value: cart.tax.display()),
        _TotalRow(label: 'Fees', value: cart.fees.display()),
        _TotalRow(label: 'Total', value: cart.total.display(), strong: true),
      ],
    );
  }
}

final class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.strong = false,
  });
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
          style: strong ? const TextStyle(fontWeight: FontWeight.w800) : null,
        ),
      ],
    ),
  );
}
