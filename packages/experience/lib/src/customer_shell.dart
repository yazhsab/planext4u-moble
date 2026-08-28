import 'package:flutter/material.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';

import 'catalog.dart';
import 'commerce.dart';
import 'localization.dart';
import 'marketplace.dart';
import 'marketplace_screen.dart';
import 'transaction_screens.dart';
import 'transactions.dart';

enum CustomerDestination { home, explore, activity, profile }

sealed class CustomerDeepLink {
  const CustomerDeepLink();

  static CustomerDeepLink? parse(Uri uri) {
    final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    if (segments.isEmpty || segments.first != 'app') return null;
    if (segments.length == 1 ||
        (segments.length == 2 && segments[1] == 'home')) {
      return const CustomerHomeLink();
    }
    if (segments.length == 2 && segments[1] == 'catalog') {
      return const CustomerCatalogLink();
    }
    if (segments.length == 4 &&
        segments[1] == 'catalog' &&
        segments[2] == 'items') {
      final id = Uri.decodeComponent(segments[3]);
      if (_safeIdentifier(id)) return CustomerItemLink(id);
    }
    if (segments.length == 3 && segments[1] == 'orders') {
      final id = Uri.decodeComponent(segments[2]);
      if (_safeIdentifier(id)) return CustomerOrderLink(id);
    }
    return null;
  }
}

final class CustomerHomeLink extends CustomerDeepLink {
  const CustomerHomeLink();
}

final class CustomerCatalogLink extends CustomerDeepLink {
  const CustomerCatalogLink();
}

final class CustomerItemLink extends CustomerDeepLink {
  const CustomerItemLink(this.itemId);
  final String itemId;
}

final class CustomerOrderLink extends CustomerDeepLink {
  const CustomerOrderLink(this.orderId);
  final String orderId;
}

bool _safeIdentifier(String value) =>
    value.isNotEmpty &&
    value.length <= 128 &&
    RegExp(r'^[A-Za-z0-9._:-]+$').hasMatch(value);

final class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({
    required this.controller,
    this.initialDestination = CustomerDestination.home,
    this.initialItemId,
    this.marketplaceController,
    this.cartController,
    this.transactionController,
    this.onItemSelected,
    super.key,
  });

  final CatalogController controller;
  final CustomerDestination initialDestination;
  final String? initialItemId;
  final MarketplaceController? marketplaceController;
  final CartController? cartController;
  final TransactionController? transactionController;
  final ValueChanged<CatalogItem>? onItemSelected;

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  late CustomerDestination _destination = widget.initialDestination;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    if (widget.controller.state.home == null) widget.controller.loadHome();
    if (widget.initialItemId != null &&
        widget.marketplaceController != null &&
        widget.cartController != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openProduct(widget.initialItemId!);
      });
    }
  }

  @override
  void didUpdateWidget(CustomerHomeScreen oldWidget) {
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
    final strings = Planext4uLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (_destination) {
          CustomerDestination.home => strings.homeTitle,
          CustomerDestination.explore => strings.exploreTitle,
          CustomerDestination.activity => strings.activityTitle,
          CustomerDestination.profile => strings.profileTitle,
        }),
        actions: [
          if (widget.cartController != null)
            IconButton(
              tooltip: 'Open cart',
              onPressed: _openCart,
              icon: const Icon(Icons.shopping_cart_outlined),
            ),
        ],
      ),
      body: SafeArea(child: _body(strings)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _destination.index,
        onDestinationSelected: (index) =>
            setState(() => _destination = CustomerDestination.values[index]),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: strings.homeTitle,
          ),
          NavigationDestination(
            icon: const Icon(Icons.search),
            label: strings.exploreTitle,
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            label: strings.activityTitle,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            label: strings.profileTitle,
          ),
        ],
      ),
    );
  }

  Widget _body(Planext4uLocalizations strings) {
    if (_destination == CustomerDestination.explore &&
        widget.marketplaceController != null) {
      return MarketplaceExploreScreen(
        controller: widget.marketplaceController!,
        onItemSelected: _openProduct,
      );
    }
    if (_destination == CustomerDestination.activity &&
        widget.transactionController != null) {
      return CustomerActivityScreen(controller: widget.transactionController!);
    }
    if (_destination != CustomerDestination.home) {
      return Planext4uStatePanel(
        state: Planext4uViewState.empty,
        title:
            '${_destination.name[0].toUpperCase()}${_destination.name.substring(1)}',
        message:
            'This destination is enabled as its Phase 2 contract becomes available.',
      );
    }
    final state = widget.controller.state;
    if (state.status == CatalogStatus.loading && state.home == null) {
      return const Center(
        child: Planext4uStatePanel(
          state: Planext4uViewState.loading,
          title: 'Loading your neighbourhood',
          message: 'Finding available categories and services.',
        ),
      );
    }
    if (state.status == CatalogStatus.failure && state.home == null) {
      return Center(
        child: Planext4uStatePanel(
          state: Planext4uViewState.error,
          title: 'Couldn’t load home',
          message: 'Try again to load nearby products and services.',
          actionLabel: strings.retry,
          onAction: widget.controller.loadHome,
        ),
      );
    }
    if (state.status == CatalogStatus.empty || state.home == null) {
      return Center(
        child: Planext4uStatePanel(
          state: Planext4uViewState.empty,
          title: 'Nothing nearby yet',
          message: 'Try a different serviceable location.',
          actionLabel: strings.retry,
          onAction: widget.controller.loadHome,
        ),
      );
    }
    final home = state.home!;
    final wideLayout = MediaQuery.sizeOf(context).width >= 720;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.15;
    return RefreshIndicator(
      onRefresh: widget.controller.loadHome,
      child: CustomScrollView(
        slivers: [
          if (state.status == CatalogStatus.offline ||
              home.projectionStatus != ProjectionStatus.fresh)
            SliverToBoxAdapter(
              child: MaterialBanner(
                content: Text(
                  state.status == CatalogStatus.offline
                      ? strings.offlineData
                      : home.projectionStatus == ProjectionStatus.stale
                      ? 'Some availability may be out of date.'
                      : 'Some services are temporarily unavailable.',
                ),
                actions: [
                  TextButton(
                    onPressed: widget.controller.loadHome,
                    child: Text(strings.retry),
                  ),
                ],
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.all(Planext4uSpacing.x4),
            sliver: SliverList.list(
              children: [
                Text(
                  strings.categories,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: Planext4uSpacing.x3),
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: home.categories.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: Planext4uSpacing.x2),
                    itemBuilder: (context, index) => ActionChip(
                      avatar: const Icon(Icons.category_outlined, size: 18),
                      label: Text(home.categories[index].name),
                      onPressed: () => setState(
                        () => _destination = CustomerDestination.explore,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Planext4uSpacing.x5),
                Text(
                  strings.featured,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: Planext4uSpacing.x3),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              Planext4uSpacing.x4,
              0,
              Planext4uSpacing.x4,
              Planext4uSpacing.x6,
            ),
            sliver: SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: wideLayout ? 3 : 2,
                crossAxisSpacing: Planext4uSpacing.x3,
                mainAxisSpacing: Planext4uSpacing.x3,
                childAspectRatio: wideLayout
                    ? (largeText ? 0.60 : 0.68)
                    : (largeText ? 0.46 : 0.52),
              ),
              itemCount: home.featuredItems.length,
              itemBuilder: (context, index) {
                final item = home.featuredItems[index];
                return Planext4uProductCard(
                  name: item.name,
                  vendor: item.summary,
                  price: item.price.display(),
                  status: item.available ? 'Available' : 'Unavailable',
                  onPressed: item.available
                      ? () {
                          if (widget.onItemSelected != null) {
                            widget.onItemSelected!(item);
                          } else {
                            _openProduct(item.id);
                          }
                        }
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openProduct(String itemId) {
    final marketplace = widget.marketplaceController;
    final cart = widget.cartController;
    if (marketplace == null || cart == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductDetailScreen(
          itemId: itemId,
          marketplace: marketplace,
          cart: cart,
          onViewCart: _openCart,
        ),
      ),
    );
  }

  void _openCart() {
    final cart = widget.cartController;
    if (cart == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CustomerCartScreen(
          controller: cart,
          onCheckout: widget.transactionController == null
              ? null
              : (value) => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CheckoutReviewScreen(
                      cart: value,
                      controller: widget.transactionController!,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
