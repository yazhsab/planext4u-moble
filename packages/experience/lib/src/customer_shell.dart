import 'package:flutter/material.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';
import 'package:planext4u_identity/planext4u_identity.dart';

import 'account_privacy.dart';
import 'account_privacy_screen.dart';
import 'appearance_preferences.dart';
import 'appearance_preferences_screen.dart';
import 'bootstrap.dart';
import 'catalog.dart';
import 'commerce.dart';
import 'food.dart';
import 'food_screens.dart';
import 'localization.dart';
import 'marketplace.dart';
import 'marketplace_screen.dart';
import 'notification_preferences.dart';
import 'notification_preferences_screen.dart';
import 'phase5.dart';
import 'phase5_screens.dart';
import 'service_booking.dart';
import 'service_booking_screens.dart';
import 'session_management_screen.dart';
import 'social.dart';
import 'social_screens.dart';
import 'transaction_screens.dart';
import 'transactions.dart';

enum CustomerDestination { home, food, explore, activity, profile }

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
    if (segments.length == 2 && segments[1] == 'social') {
      return const CustomerSocialLink();
    }
    if (segments.length == 2 &&
        const {
          'community',
          'homes',
          'classifieds',
          'emergency',
        }.contains(segments[1])) {
      return CustomerCommunityLink(switch (segments[1]) {
        'homes' => 1,
        'classifieds' => 2,
        'emergency' => 3,
        _ => 0,
      });
    }
    if (segments.length == 4 &&
        segments[1] == 'social' &&
        segments[2] == 'posts') {
      final id = Uri.decodeComponent(segments[3]);
      if (_safeIdentifier(id)) return CustomerSocialLink(postId: id);
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

final class CustomerSocialLink extends CustomerDeepLink {
  const CustomerSocialLink({this.postId});
  final String? postId;
}

final class CustomerCommunityLink extends CustomerDeepLink {
  const CustomerCommunityLink(this.tab);
  final int tab;
}

bool _safeIdentifier(String value) =>
    value.isNotEmpty &&
    value.length <= 128 &&
    RegExp(r'^[A-Za-z0-9._:-]+$').hasMatch(value);

const _fallbackTrustBenefits = [
  HomeSectionItemConfig(
    id: 'best-offers',
    title: 'Best offers',
    subtitle: 'On trusted local brands',
    icon: 'offers',
  ),
  HomeSectionItemConfig(
    id: 'secure-shopping',
    title: 'Secure shopping',
    subtitle: 'Protected payments and privacy',
    icon: 'secure',
  ),
  HomeSectionItemConfig(
    id: 'fast-delivery',
    title: 'Fast delivery',
    subtitle: 'Live fulfilment updates',
    icon: 'delivery',
  ),
  HomeSectionItemConfig(
    id: 'easy-support',
    title: 'Easy support',
    subtitle: 'Help throughout your order',
    icon: 'support',
  ),
];

const _fallbackCustomerHomeSections = [
  HomeSectionConfig(
    id: 'fallback-hero',
    kind: 'HERO',
    titleKey: 'home.hero',
    displayTitle: 'Smart shopping, everyday.',
    displaySubtitle:
        'Shop local products and trusted services from one secure place.',
    actionLabel: 'Start shopping',
    actionRoute: '/app/catalog',
    enabled: true,
    priority: 0,
  ),
  HomeSectionConfig(
    id: 'fallback-trust',
    kind: 'TRUST_BENEFITS',
    titleKey: 'home.trust',
    enabled: true,
    priority: 5,
    items: _fallbackTrustBenefits,
  ),
  HomeSectionConfig(
    id: 'fallback-categories',
    kind: 'CATEGORY_GRID',
    titleKey: 'home.categories',
    enabled: true,
    priority: 10,
  ),
  HomeSectionConfig(
    id: 'fallback-featured',
    kind: 'FEATURED_ITEMS',
    titleKey: 'home.featured',
    enabled: true,
    priority: 20,
  ),
];

final class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({
    required this.controller,
    this.initialDestination = CustomerDestination.home,
    this.initialItemId,
    this.marketplaceController,
    this.cartController,
    this.transactionController,
    this.serviceBookingController,
    this.foodController,
    this.socialController,
    this.phase5Controller,
    this.accountPrivacyController,
    this.sessionManagementController,
    this.notificationPreferencesController,
    this.appearancePreferencesController,
    this.openCommunityInitially = false,
    this.initialCommunityTab = 0,
    this.openSocialInitially = false,
    this.initialSocialPostId,
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
  final FoodController? foodController;
  final SocialController? socialController;
  final Phase5Controller? phase5Controller;
  final AccountPrivacyController? accountPrivacyController;
  final IdentitySessionManagementController? sessionManagementController;
  final NotificationPreferencesController? notificationPreferencesController;
  final AppearancePreferencesController? appearancePreferencesController;
  final bool openCommunityInitially;
  final int initialCommunityTab;
  final bool openSocialInitially;
  final String? initialSocialPostId;
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
    if (widget.openSocialInitially && widget.socialController != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openSocial(postId: widget.initialSocialPostId);
      });
    }
    if (widget.openCommunityInitially && widget.phase5Controller != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openCommunity(widget.initialCommunityTab);
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
          CustomerDestination.food => 'Food',
          CustomerDestination.explore => strings.exploreTitle,
          CustomerDestination.activity => strings.activityTitle,
          CustomerDestination.profile => strings.accountTitle,
        }),
        actions: [
          if (widget.socialController != null)
            IconButton(
              key: const ValueKey('open-social'),
              tooltip: 'Open Socio',
              onPressed: _openSocial,
              icon: const Icon(Icons.people_alt_outlined),
            ),
          if (widget.phase5Controller != null)
            IconButton(
              key: const ValueKey('open-community'),
              tooltip: 'Open Homes, Classifieds and Emergency',
              onPressed: () => _openCommunity(0),
              icon: const Icon(Icons.grid_view_rounded),
            ),
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
        height: switch (MediaQuery.textScalerOf(context).scale(1)) {
          >= 1.8 => 112,
          > 1.15 => 96,
          _ => null,
        },
        selectedIndex: _bottomNavigationIndex,
        onDestinationSelected: _selectBottomDestination,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: strings.homeTitle,
          ),
          NavigationDestination(
            icon: const Icon(Icons.people_alt_outlined),
            selectedIcon: const Icon(Icons.people_alt),
            label: strings.socioTitle,
          ),
          NavigationDestination(
            icon: const Icon(Icons.grid_view_outlined),
            selectedIcon: const Icon(Icons.grid_view_rounded),
            label: strings.categories,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: strings.accountTitle,
          ),
          NavigationDestination(
            icon: const Icon(Icons.shopping_cart_outlined),
            selectedIcon: const Icon(Icons.shopping_cart),
            label: strings.cartTitle,
          ),
        ],
      ),
    );
  }

  int get _bottomNavigationIndex => switch (_destination) {
    CustomerDestination.home || CustomerDestination.food => 0,
    CustomerDestination.explore => 2,
    CustomerDestination.activity || CustomerDestination.profile => 3,
  };

  void _selectBottomDestination(int index) {
    switch (index) {
      case 0:
        setState(() => _destination = CustomerDestination.home);
        return;
      case 1:
        if (widget.socialController == null) {
          _showUnavailable('Socio');
        } else {
          _openSocial();
        }
        return;
      case 2:
        setState(() => _destination = CustomerDestination.explore);
        return;
      case 3:
        setState(() => _destination = CustomerDestination.profile);
        return;
      case 4:
        if (widget.cartController == null) {
          _showUnavailable('Cart');
        } else {
          _openCart();
        }
        return;
    }
  }

  void _showUnavailable(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is temporarily unavailable.')),
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

  Future<void> _openAccountPrivacy() async {
    final controller = widget.accountPrivacyController;
    if (controller == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AccountPrivacyScreen(controller: controller),
      ),
    );
  }

  Widget _body(Planext4uLocalizations strings) {
    if (_destination == CustomerDestination.food &&
        widget.foodController != null) {
      return CustomerFoodScreen(controller: widget.foodController!);
    }
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
            if (widget.transactionController != null)
              ListTile(
                key: const ValueKey('open-order-activity'),
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(strings.activityTitle),
                subtitle: const Text(
                  'Orders, tracking, returns and payment recovery',
                ),
                onTap: () =>
                    setState(() => _destination = CustomerDestination.activity),
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
            if (widget.accountPrivacyController != null) ...[
              const Divider(),
              ListTile(
                key: const ValueKey('customer-account-privacy'),
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Account privacy'),
                subtitle: const Text(
                  'Export your data or schedule account deletion',
                ),
                onTap: _openAccountPrivacy,
              ),
            ],
            if (widget.sessionManagementController != null)
              ListTile(
                key: const ValueKey('customer-signed-in-devices'),
                leading: const Icon(Icons.devices_outlined),
                title: const Text('Signed-in devices'),
                subtitle: const Text(
                  'Review account sessions and sign out another device',
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => IdentitySessionManagementScreen(
                      controller: widget.sessionManagementController!,
                    ),
                  ),
                ),
              ),
            if (widget.notificationPreferencesController != null)
              ListTile(
                key: const ValueKey('customer-notification-preferences'),
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('Notification preferences'),
                subtitle: const Text(
                  'Choose channels for orders, security and offers',
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => NotificationPreferencesScreen(
                      controller: widget.notificationPreferencesController!,
                    ),
                  ),
                ),
              ),
            if (widget.appearancePreferencesController != null)
              ListTile(
                key: const ValueKey('customer-appearance-preferences'),
                leading: const Icon(Icons.contrast_outlined),
                title: const Text('Appearance and accessibility'),
                subtitle: const Text(
                  'Language, theme, text size, motion and data usage',
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AppearancePreferencesScreen(
                      controller: widget.appearancePreferencesController!,
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
          SliverToBoxAdapter(child: _homeModuleLauncher()),
          ..._configuredHomeSlivers(
            home,
            strings,
            wideLayout: wideLayout,
            largeText: largeText,
          ),
          if (widget.phase5Controller != null)
            SliverToBoxAdapter(child: _communityLauncher()),
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
    final configured = normalizeCustomerHomeSections(widget.homeSections);
    final sections = configured.isEmpty
        ? _fallbackCustomerHomeSections
        : configured;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return [
      for (final section in sections)
        if (section.kind == 'HERO')
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              Planext4uSpacing.x4,
              Planext4uSpacing.x2,
              Planext4uSpacing.x4,
              Planext4uSpacing.x3,
            ),
            sliver: SliverToBoxAdapter(
              child: Planext4uCampaignHero(
                key: ValueKey('home-section-${section.id}'),
                title: _homeSectionTitle(
                  section,
                  strings,
                  fallback: 'Smart shopping, everyday.',
                ),
                subtitle: section.displaySubtitle.isEmpty
                    ? 'Everything you need from trusted local sellers.'
                    : section.displaySubtitle,
                actionLabel: section.actionLabel.isEmpty
                    ? null
                    : section.actionLabel,
                onAction: _homeRouteAction(section.actionRoute),
              ),
            ),
          )
        else if (section.kind == 'TRUST_BENEFITS')
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              Planext4uSpacing.x4,
              0,
              Planext4uSpacing.x4,
              Planext4uSpacing.x4,
            ),
            sliver: SliverToBoxAdapter(
              child: Planext4uBenefitStrip(
                key: ValueKey('home-section-${section.id}'),
                items: _homeBenefitItems(section),
              ),
            ),
          )
        else if (section.kind == 'CATEGORY_GRID')
          SliverPadding(
            padding: const EdgeInsets.all(Planext4uSpacing.x4),
            sliver: SliverList.list(
              children: [
                Text(
                  _homeSectionTitle(
                    section,
                    strings,
                    fallback: strings.categories,
                  ),
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
        else if (section.kind == 'SERVICE_DISCOVERY')
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              Planext4uSpacing.x4,
              0,
              Planext4uSpacing.x4,
              Planext4uSpacing.x5,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Planext4uSectionHeader(
                    title: _homeSectionTitle(
                      section,
                      strings,
                      fallback: 'Popular services',
                    ),
                    subtitle: section.displaySubtitle.isEmpty
                        ? null
                        : section.displaySubtitle,
                  ),
                  const SizedBox(height: Planext4uSpacing.x2),
                  Planext4uBenefitStrip(items: _homeServiceItems(section)),
                ],
              ),
            ),
          )
        else if (section.kind == 'FEATURED_ITEMS' ||
            section.kind == 'BESTSELLERS') ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              Planext4uSpacing.x4,
              Planext4uSpacing.x2,
              Planext4uSpacing.x4,
              Planext4uSpacing.x3,
            ),
            sliver: SliverToBoxAdapter(
              child: Text(
                _homeSectionTitle(section, strings, fallback: strings.featured),
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
                    ? (textScale >= 1.8 ? 0.48 : (largeText ? 0.60 : 0.68))
                    : (textScale >= 1.8 ? 0.36 : (largeText ? 0.46 : 0.52)),
              ),
              itemCount: home.featuredItems.length,
              itemBuilder: (context, index) {
                final item = home.featuredItems[index];
                return Planext4uProductCard(
                  name: item.name,
                  vendor: item.summary,
                  price: item.price.display(),
                  status: item.available ? 'Available' : 'Unavailable',
                  available: item.available,
                  onAddToCart: _homeCartVariant(item) == null
                      ? null
                      : () => _addHomeItemToCart(item),
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
        ] else if (section.kind == 'RECOMMENDATIONS' &&
            home.recommendations.isNotEmpty)
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
                  Planext4uSectionHeader(
                    title: _homeSectionTitle(
                      section,
                      strings,
                      fallback: 'Recommended for you',
                    ),
                  ),
                  const SizedBox(height: Planext4uSpacing.x2),
                  Planext4uHorizontalRail(
                    semanticLabel: 'Recommended items',
                    height: textScale >= 1.8 ? 480 : (largeText ? 400 : 344),
                    itemWidth: textScale >= 1.8 ? 256 : 224,
                    children: [
                      for (final item in home.recommendations)
                        Planext4uProductCard(
                          name: item.name,
                          vendor: item.sellerName ?? item.summary,
                          price: item.price.display(),
                          status: item.available ? 'Available' : 'Unavailable',
                          available: item.available,
                          onAddToCart: _homeCartVariant(item) == null
                              ? null
                              : () => _addHomeItemToCart(item),
                          onPressed: item.available
                              ? () => _openProduct(item.id)
                              : null,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          )
        else if (section.kind == 'LEADERBOARD' && home.leaderboard.isNotEmpty)
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
                    _homeSectionTitle(
                      section,
                      strings,
                      fallback: 'Top local sellers',
                    ),
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
        else if (section.kind == 'HELP_SHORTCUTS' &&
            home.helpShortcuts.isNotEmpty)
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
                    _homeSectionTitle(section, strings, fallback: 'Quick help'),
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

  String _homeSectionTitle(
    HomeSectionConfig section,
    Planext4uLocalizations strings, {
    required String fallback,
  }) {
    if (section.displayTitle.isNotEmpty) return section.displayTitle;
    return strings.homeSectionTitle(section.titleKey, fallback: fallback);
  }

  List<Planext4uBenefitItem> _homeBenefitItems(HomeSectionConfig section) {
    final items = section.items.isEmpty
        ? _fallbackTrustBenefits
        : section.items;
    return List.unmodifiable([
      for (final item in items)
        Planext4uBenefitItem(
          title: item.title,
          subtitle: item.subtitle,
          icon: _homeBenefitIcon(item.icon),
          onTap: _homeRouteAction(item.actionRoute),
        ),
    ]);
  }

  List<Planext4uBenefitItem> _homeServiceItems(HomeSectionConfig section) {
    final items = section.items.isEmpty
        ? const [
            HomeSectionItemConfig(
              id: 'local-services',
              title: 'Local services',
              subtitle: 'Book trusted help near you',
              icon: 'services',
              actionRoute: '/app/services',
            ),
          ]
        : section.items;
    return List.unmodifiable([
      for (final item in items)
        Planext4uBenefitItem(
          title: item.title,
          subtitle: item.subtitle,
          icon: _homeBenefitIcon(item.icon),
          onTap: _homeRouteAction(item.actionRoute),
        ),
    ]);
  }

  IconData _homeBenefitIcon(String value) => switch (value) {
    'offers' => Icons.local_offer_outlined,
    'secure' => Icons.verified_user_outlined,
    'delivery' => Icons.local_shipping_outlined,
    'support' => Icons.support_agent_outlined,
    'services' => Icons.home_repair_service_outlined,
    'food' => Icons.restaurant_outlined,
    _ => Icons.info_outline,
  };

  VoidCallback? _homeRouteAction(String route) => switch (route) {
    '/app/catalog' when widget.marketplaceController != null => () => setState(
      () => _destination = CustomerDestination.explore,
    ),
    '/app/orders' when widget.transactionController != null => () => setState(
      () => _destination = CustomerDestination.activity,
    ),
    '/app/services'
        when widget.serviceBookingController != null &&
            widget.transactionController != null =>
      _openServices,
    '/app/food' when widget.foodController != null => () => setState(
      () => _destination = CustomerDestination.food,
    ),
    '/app/social' when widget.socialController != null => _openSocial,
    '/app/community' when widget.phase5Controller != null =>
      () => _openCommunity(0),
    '/app/homes' when widget.phase5Controller != null => () => _openCommunity(
      1,
    ),
    '/app/classifieds' when widget.phase5Controller != null =>
      () => _openCommunity(2),
    '/app/emergency' when widget.phase5Controller != null =>
      () => _openCommunity(3),
    _ => null,
  };

  Widget _homeModuleLauncher() {
    final modules =
        <({String key, String label, IconData icon, VoidCallback? onTap})>[
          (
            key: 'shop',
            label: 'Shop',
            icon: Icons.shopping_bag_outlined,
            onTap: widget.marketplaceController == null
                ? null
                : () => setState(
                    () => _destination = CustomerDestination.explore,
                  ),
          ),
          (
            key: 'socio',
            label: 'Socio',
            icon: Icons.people_alt_outlined,
            onTap: widget.socialController == null ? null : _openSocial,
          ),
          (
            key: 'services',
            label: 'Services',
            icon: Icons.home_repair_service_outlined,
            onTap:
                widget.serviceBookingController == null ||
                    widget.transactionController == null
                ? null
                : () => _openServices(),
          ),
          (
            key: 'food',
            label: 'Food',
            icon: Icons.restaurant_outlined,
            onTap: widget.foodController == null
                ? null
                : () => setState(() => _destination = CustomerDestination.food),
          ),
          (
            key: 'homes',
            label: 'Homes',
            icon: Icons.home_work_outlined,
            onTap: widget.phase5Controller == null
                ? null
                : () => _openCommunity(1),
          ),
          (
            key: 'classifieds',
            label: 'Classifieds',
            icon: Icons.sell_outlined,
            onTap: widget.phase5Controller == null
                ? null
                : () => _openCommunity(2),
          ),
          (
            key: 'emergency',
            label: 'Emergency',
            icon: Icons.emergency_outlined,
            onTap: widget.phase5Controller == null
                ? null
                : () => _openCommunity(3),
          ),
        ];
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final largeText = textScale > 1.15;
    return Semantics(
      container: true,
      label: 'Planext4u services',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Planext4uSpacing.x4,
          Planext4uSpacing.x4,
          Planext4uSpacing.x4,
          Planext4uSpacing.x2,
        ),
        child: SizedBox(
          height: textScale >= 1.8 ? 176 : (largeText ? 140 : 108),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: modules.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: Planext4uSpacing.x2),
            itemBuilder: (context, index) {
              final module = modules[index];
              final enabled = module.onTap != null;
              return Semantics(
                button: true,
                enabled: enabled,
                label: module.label,
                child: Opacity(
                  opacity: enabled ? 1 : 0.48,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: ValueKey('home-module-${module.key}'),
                      onTap: module.onTap,
                      child: SizedBox(
                        width: textScale >= 1.8 ? 112 : 88,
                        child: Padding(
                          padding: const EdgeInsets.all(Planext4uSpacing.x2),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(module.icon, size: 30),
                              const SizedBox(height: Planext4uSpacing.x2),
                              Text(
                                module.label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  CatalogVariant? _homeCartVariant(CatalogItem item) {
    if (!item.available || widget.cartController == null) return null;
    for (final variant in item.variants) {
      if (variant.available && variant.stockQuantity > 0) return variant;
    }
    return null;
  }

  Future<void> _addHomeItemToCart(CatalogItem item) async {
    final cart = widget.cartController;
    final variant = _homeCartVariant(item);
    if (cart == null || variant == null) return;
    final currentLine = cart.state.cart?.items
        .where((line) => line.variantId == variant.id)
        .firstOrNull;
    final currentQuantity = currentLine?.quantity ?? 0;
    final maximum = variant.stockQuantity < variant.maxPerOrder
        ? variant.stockQuantity
        : variant.maxPerOrder;
    if (currentQuantity >= maximum) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum available quantity reached.')),
        );
      }
      return;
    }
    final added = await cart.setItem(variant.id, currentQuantity + 1);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added
              ? '${item.name} added to cart.'
              : cart.state.message ?? 'Cart could not be updated safely.',
        ),
        action: added
            ? SnackBarAction(label: 'View cart', onPressed: _openCart)
            : null,
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
                      paymentLauncher: widget.paymentLauncher,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  void _openSocial({String? postId}) {
    final social = widget.socialController;
    if (social == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            CustomerSocialScreen(controller: social, initialPostId: postId),
      ),
    );
  }

  Widget _communityLauncher() => Padding(
    padding: const EdgeInsets.fromLTRB(
      Planext4uSpacing.x4,
      0,
      Planext4uSpacing.x4,
      Planext4uSpacing.x6,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Community', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: Planext4uSpacing.x2),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 2.4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: [
            _module('Socio+', Icons.people_alt_outlined, 0),
            _module('Homes', Icons.home_work_outlined, 1),
            _module('Classifieds', Icons.sell_outlined, 2),
            _module('Emergency', Icons.emergency_outlined, 3),
          ],
        ),
      ],
    ),
  );
  Widget _module(String label, IconData icon, int tab) => Card(
    child: InkWell(
      key: ValueKey('community-$tab'),
      onTap: () => _openCommunity(tab),
      borderRadius: BorderRadius.circular(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ),
  );
  void _openCommunity(int tab) {
    final controller = widget.phase5Controller;
    if (controller == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            CustomerCommunityHubScreen(controller: controller, initialTab: tab),
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
