import 'package:flutter/material.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';

import 'catalog.dart';
import 'bootstrap.dart';
import 'commerce.dart';
import 'localization.dart';
import 'marketplace.dart';
import 'marketplace_screen.dart';
import 'service_booking.dart';
import 'service_booking_screens.dart';
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
    this.serviceBookingController,
    this.paymentLauncher = const UnavailablePaymentProviderLauncher(),
    this.onItemSelected,
    this.profileDisplayName,
    this.onSignOut,
    this.homeSections = const [],
    super.key,
  });

  final CatalogController controller;
  final CustomerDestination initialDestination;
  final String? initialItemId;
  final MarketplaceController? marketplaceController;
  final CartController? cartController;
  final TransactionController? transactionController;
  final ServiceBookingController? serviceBookingController;
  final PaymentProviderLauncher paymentLauncher;
  final ValueChanged<CatalogItem>? onItemSelected;
  final String? profileDisplayName;
  final Future<void> Function()? onSignOut;
  final List<HomeSectionConfig> homeSections;

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  late CustomerDestination _destination = widget.initialDestination;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    widget.transactionController?.addListener(_changed);
    widget.transactionController?.recoverPayment();
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
    if (oldWidget.transactionController != widget.transactionController) {
      oldWidget.transactionController?.removeListener(_changed);
      widget.transactionController?.addListener(_changed);
      widget.transactionController?.recoverPayment();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    widget.transactionController?.removeListener(_changed);
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
      body: SafeArea(
        child: Column(
          children: [
            if (widget.transactionController?.state.payment?.pending == true)
              MaterialBanner(
                content: Text(
                  widget.transactionController!.state.payment!.status ==
                          'FAILED_RETRYABLE'
                      ? 'Your previous payment needs attention.'
                      : 'Your previous payment is still being confirmed.',
                ),
                actions: [
                  if (widget
                      .transactionController!
                      .state
                      .payment!
                      .allowedActions
                      .contains('RETRY'))
                    TextButton(
                      onPressed: _retryRecoveredPayment,
                      child: const Text('Retry payment'),
                    ),
                  TextButton(
                    onPressed: widget.transactionController!.recoverPayment,
                    child: const Text('Check status'),
                  ),
                ],
              ),
            Expanded(child: _body(strings)),
          ],
        ),
      ),
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

  Future<void> _retryRecoveredPayment() async {
    final controller = widget.transactionController;
    if (controller == null) return;
    final payment = await controller.retryPayment();
    if (payment == null) return;
    try {
      await widget.paymentLauncher.launch(payment);
    } catch (_) {
      // The encrypted payment identifier remains available for another retry.
    }
    await controller.recoverPayment();
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
      return CustomerActivityScreen(
        controller: widget.transactionController!,
        paymentLauncher: widget.paymentLauncher,
      );
    }
    if (_destination != CustomerDestination.home) {
      if (_destination == CustomerDestination.profile) {
        return ListView(
          padding: const EdgeInsets.all(Planext4uSpacing.x4),
          children: [
            CircleAvatar(
              radius: 36,
              child: Text(
                (widget.profileDisplayName?.trim().isNotEmpty ?? false)
                    ? widget.profileDisplayName!.trim()[0].toUpperCase()
                    : 'P',
              ),
            ),
            const SizedBox(height: Planext4uSpacing.x3),
            Text(
              widget.profileDisplayName?.trim().isNotEmpty ?? false
                  ? widget.profileDisplayName!.trim()
                  : 'Planext4u customer',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: Planext4uSpacing.x5),
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('Saved addresses'),
              subtitle: const Text('Manage serviceable delivery locations'),
              onTap: widget.transactionController == null
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CustomerAddressesScreen(
                          controller: widget.transactionController!,
                        ),
                      ),
                    ),
            ),
            if (widget.serviceBookingController != null)
              ListTile(
                leading: const Icon(Icons.home_repair_service_outlined),
                title: const Text('Local service bookings'),
                subtitle: const Text(
                  'Appointments, start code and completion evidence',
                ),
                onTap: _openServices,
              ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Help and support'),
              subtitle: const Text('Orders, payments, returns and safety'),
              onTap: () => showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                builder: (context) => const SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(Planext4uSpacing.x5),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Planext4u support'),
                        SizedBox(height: Planext4uSpacing.x2),
                        Text(
                          'Open an order from Activity for order-specific help, cancellation or return actions.',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Planext4uSpacing.x4),
            OutlinedButton.icon(
              onPressed: widget.onSignOut == null
                  ? null
                  : () async => widget.onSignOut!(),
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
        );
      }
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
          ..._configuredHomeSlivers(
            home,
            strings,
            wideLayout: wideLayout,
            largeText: largeText,
          ),
        ],
      ),
    );
  }

  List<Widget> _configuredHomeSlivers(
    CustomerHomeProjection home,
    Planext4uLocalizations strings, {
    required bool wideLayout,
    required bool largeText,
  }) {
    final configured = widget.homeSections
        .where((value) => value.enabled)
        .toList(growable: false);
    final kinds = configured.isEmpty
        ? const ['CATEGORY_GRID', 'FEATURED_ITEMS']
        : configured.map((value) => value.kind).toList(growable: false);
    return [
      for (final kind in kinds)
        if (kind == 'CATEGORY_GRID')
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
                    itemCount:
                        home.categories.length +
                        (widget.serviceBookingController == null ? 0 : 1),
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: Planext4uSpacing.x2),
                    itemBuilder: (context, index) {
                      if (widget.serviceBookingController != null &&
                          index == 0) {
                        return ActionChip(
                          key: const ValueKey('local-services'),
                          avatar: const Icon(
                            Icons.home_repair_service_outlined,
                            size: 18,
                          ),
                          label: const Text('Local services'),
                          onPressed: _openServices,
                        );
                      }
                      final categoryIndex =
                          index -
                          (widget.serviceBookingController == null ? 0 : 1);
                      return ActionChip(
                        avatar: const Icon(Icons.category_outlined, size: 18),
                        label: Text(home.categories[categoryIndex].name),
                        onPressed: () => setState(
                          () => _destination = CustomerDestination.explore,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          )
        else if (kind == 'FEATURED_ITEMS') ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              Planext4uSpacing.x4,
              Planext4uSpacing.x2,
              Planext4uSpacing.x4,
              Planext4uSpacing.x3,
            ),
            sliver: SliverToBoxAdapter(
              child: Text(
                strings.featured,
                style: Theme.of(context).textTheme.titleLarge,
              ),
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
        ] else if (kind == 'RECOMMENDATIONS' && home.recommendations.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Planext4uSpacing.x4,
                0,
                Planext4uSpacing.x4,
                Planext4uSpacing.x5,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recommended for you',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: Planext4uSpacing.x2),
                  for (final item in home.recommendations)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.auto_awesome_outlined),
                        title: Text(item.name),
                        subtitle: Text(item.sellerName ?? item.summary),
                        trailing: Text(item.price.display()),
                        enabled: item.available,
                        onTap: item.available
                            ? () => _openProduct(item.id)
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          )
        else if (kind == 'LEADERBOARD' && home.leaderboard.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Planext4uSpacing.x4,
                0,
                Planext4uSpacing.x4,
                Planext4uSpacing.x5,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Top local sellers',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: Planext4uSpacing.x2),
                  for (var index = 0; index < home.leaderboard.length; index++)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(child: Text('${index + 1}')),
                      title: Text(home.leaderboard[index].sellerName),
                      subtitle: Text(
                        '${home.leaderboard[index].ratingAverage.toStringAsFixed(1)} ★ • '
                        '${home.leaderboard[index].reviewCount} reviews',
                      ),
                      trailing: home.leaderboard[index].verified
                          ? const Icon(
                              Icons.verified,
                              semanticLabel: 'Verified',
                            )
                          : null,
                    ),
                ],
              ),
            ),
          )
        else if (kind == 'HELP_SHORTCUTS' && home.helpShortcuts.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Planext4uSpacing.x4,
                0,
                Planext4uSpacing.x4,
                Planext4uSpacing.x6,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick help',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: Planext4uSpacing.x2),
                  Wrap(
                    spacing: Planext4uSpacing.x2,
                    runSpacing: Planext4uSpacing.x2,
                    children: [
                      for (final shortcut in home.helpShortcuts)
                        ActionChip(
                          avatar: const Icon(Icons.help_outline, size: 18),
                          label: Text(shortcut.title),
                          onPressed: () => setState(
                            () =>
                                _destination = shortcut.route == '/app/catalog'
                                ? CustomerDestination.explore
                                : CustomerDestination.activity,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    ];
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
                      paymentLauncher: widget.paymentLauncher,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _openServices() async {
    final bookings = widget.serviceBookingController;
    final transactions = widget.transactionController;
    if (bookings == null || transactions == null) return;
    if (transactions.state.addresses.isEmpty) {
      await transactions.loadCheckout();
    }
    if (!mounted) return;
    final addresses = transactions.state.addresses
        .where((value) => value.serviceable)
        .toList(growable: false);
    if (addresses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a serviceable address before booking a service.'),
        ),
      );
      return;
    }
    final address = addresses.firstWhere(
      (value) => value.isDefault,
      orElse: () => addresses.first,
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ServiceBookingScreen(
          controller: bookings,
          postalCode: address.postalCode,
          paymentLauncher: widget.paymentLauncher,
        ),
      ),
    );
  }
}
