import 'package:flutter/material.dart';
import 'package:planext4u_core/planext4u_core.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';

import 'localization.dart';

enum RoleCapability {
  vendorOverview,
  vendorOrders,
  vendorBookings,
  vendorCatalog,
  vendorPromotions,
  vendorEarnings,
  riderDuty,
  riderAssignments,
  riderEarnings,
  riderEmergency,
  profile,
}

final class RoleDestination {
  const RoleDestination({
    required this.id,
    required this.label,
    required this.icon,
    required this.capability,
    this.featureFlag,
  });

  final String id;
  final String label;
  final IconData icon;
  final RoleCapability capability;
  final String? featureFlag;
}

typedef RoleDestinationBuilder =
    Widget Function(BuildContext context, RoleDestination destination);

abstract final class RoleNavigationPolicy {
  static List<RoleDestination> destinations({
    required AppRole applicationRole,
    required Set<AppRole> grantedRoles,
    required Set<RoleCapability> capabilities,
    required Map<String, bool> featureFlags,
  }) {
    if (!grantedRoles.contains(applicationRole)) return const [];
    final candidates = switch (applicationRole) {
      AppRole.vendor => _vendorDestinations,
      AppRole.rider => _riderDestinations,
      AppRole.customer => const <RoleDestination>[],
    };
    return List.unmodifiable(
      candidates.where(
        (destination) =>
            capabilities.contains(destination.capability) &&
            (destination.featureFlag == null ||
                featureFlags[destination.featureFlag] == true),
      ),
    );
  }
}

const _vendorDestinations = <RoleDestination>[
  RoleDestination(
    id: 'overview',
    label: 'Overview',
    icon: Icons.dashboard_outlined,
    capability: RoleCapability.vendorOverview,
  ),
  RoleDestination(
    id: 'orders',
    label: 'Orders',
    icon: Icons.receipt_long_outlined,
    capability: RoleCapability.vendorOrders,
    featureFlag: 'vendor_orders',
  ),
  RoleDestination(
    id: 'catalog',
    label: 'Catalog',
    icon: Icons.inventory_2_outlined,
    capability: RoleCapability.vendorCatalog,
    featureFlag: 'vendor_catalog',
  ),
  RoleDestination(
    id: 'bookings',
    label: 'Bookings',
    icon: Icons.event_available_outlined,
    capability: RoleCapability.vendorBookings,
    featureFlag: 'vendor_bookings',
  ),
  RoleDestination(
    id: 'promotions',
    label: 'Promotions',
    icon: Icons.campaign_outlined,
    capability: RoleCapability.vendorPromotions,
    featureFlag: 'vendor_promotions',
  ),
  RoleDestination(
    id: 'earnings',
    label: 'Earnings',
    icon: Icons.account_balance_wallet_outlined,
    capability: RoleCapability.vendorEarnings,
    featureFlag: 'vendor_earnings',
  ),
  RoleDestination(
    id: 'profile',
    label: 'Profile',
    icon: Icons.store_outlined,
    capability: RoleCapability.profile,
  ),
];

const _riderDestinations = <RoleDestination>[
  RoleDestination(
    id: 'duty',
    label: 'Duty',
    icon: Icons.toggle_on_outlined,
    capability: RoleCapability.riderDuty,
  ),
  RoleDestination(
    id: 'assignments',
    label: 'Tasks',
    icon: Icons.route_outlined,
    capability: RoleCapability.riderAssignments,
    featureFlag: 'rider_assignments',
  ),
  RoleDestination(
    id: 'earnings',
    label: 'Earnings',
    icon: Icons.account_balance_wallet_outlined,
    capability: RoleCapability.riderEarnings,
    featureFlag: 'rider_earnings',
  ),
  RoleDestination(
    id: 'emergency',
    label: 'Emergency',
    icon: Icons.emergency_outlined,
    capability: RoleCapability.riderEmergency,
    featureFlag: 'rider_emergency',
  ),
  RoleDestination(
    id: 'profile',
    label: 'Profile',
    icon: Icons.person_outline,
    capability: RoleCapability.profile,
  ),
];

final class AuthenticatedRoleShell extends StatefulWidget {
  const AuthenticatedRoleShell({
    required this.applicationRole,
    required this.grantedRoles,
    required this.capabilities,
    required this.featureFlags,
    required this.environmentLabel,
    this.destinationBuilder,
    this.onSignOut,
    super.key,
  });

  final AppRole applicationRole;
  final Set<AppRole> grantedRoles;
  final Set<RoleCapability> capabilities;
  final Map<String, bool> featureFlags;
  final String environmentLabel;
  final RoleDestinationBuilder? destinationBuilder;
  final Future<void> Function()? onSignOut;

  @override
  State<AuthenticatedRoleShell> createState() => _AuthenticatedRoleShellState();
}

class _AuthenticatedRoleShellState extends State<AuthenticatedRoleShell> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final strings = Planext4uLocalizations.of(context);
    final destinations = RoleNavigationPolicy.destinations(
      applicationRole: widget.applicationRole,
      grantedRoles: widget.grantedRoles,
      capabilities: widget.capabilities,
      featureFlags: widget.featureFlags,
    );
    if (!widget.grantedRoles.contains(widget.applicationRole)) {
      return const Scaffold(
        body: SafeArea(
          child: Center(
            child: Planext4uStatePanel(
              state: Planext4uViewState.permissionDenied,
              title: 'This account can’t use this app',
              message: 'Sign in with an account that has the required role.',
            ),
          ),
        ),
      );
    }
    if (destinations.isEmpty) {
      return const Scaffold(
        body: SafeArea(
          child: Center(
            child: Planext4uStatePanel(
              state: Planext4uViewState.permissionDenied,
              title: 'No permissions assigned',
              message: 'Ask an administrator to grant access for this app.',
            ),
          ),
        ),
      );
    }
    if (_selected >= destinations.length) _selected = 0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final destination = destinations[_selected];
        final destinationLabel = strings.destinationLabel(destination.id);
        final roleLabel = strings.roleLabel(widget.applicationRole.name);
        final useNavigationRail = constraints.maxWidth >= 840;
        final useNavigationDrawer =
            !useNavigationRail && destinations.length > 5;
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final content = Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child:
                widget.destinationBuilder?.call(context, destination) ??
                Planext4uStatePanel(
                  state: Planext4uViewState.empty,
                  title: destinationLabel,
                  message:
                      '$roleLabel ${destinationLabel.toLowerCase()} '
                      'is permission-verified and ready for its domain workflow.',
                ),
          ),
        );
        return Scaffold(
          appBar: AppBar(
            title: Text(
              useNavigationDrawer
                  ? textScale >= 1.8
                        ? destinationLabel
                        : '$roleLabel • $destinationLabel'
                  : 'Planext4u $roleLabel',
            ),
            actions: [
              if (constraints.maxWidth >= 480)
                Semantics(
                  label: 'Build environment: ${widget.environmentLabel}',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Planext4uSpacing.x4,
                    ),
                    child: Center(
                      child: Text(
                        widget.environmentLabel.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
                ),
              if (widget.onSignOut != null)
                IconButton(
                  tooltip: strings.signOut,
                  onPressed: () => widget.onSignOut!(),
                  icon: const Icon(Icons.logout),
                ),
            ],
          ),
          drawer: useNavigationDrawer
              ? Drawer(
                  child: SafeArea(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        vertical: Planext4uSpacing.x3,
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            Planext4uSpacing.x6,
                            Planext4uSpacing.x3,
                            Planext4uSpacing.x4,
                            Planext4uSpacing.x3,
                          ),
                          child: Text(
                            strings.workspace,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        for (
                          var index = 0;
                          index < destinations.length;
                          index++
                        )
                          ListTile(
                            selected: index == _selected,
                            leading: Icon(destinations[index].icon),
                            title: Text(
                              strings.destinationLabel(destinations[index].id),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              setState(() => _selected = index);
                              Navigator.of(context).pop();
                            },
                          ),
                      ],
                    ),
                  ),
                )
              : null,
          body: SafeArea(
            child: Row(
              children: [
                if (useNavigationRail)
                  NavigationRail(
                    extended: constraints.maxWidth >= 1100,
                    selectedIndex: _selected,
                    onDestinationSelected: (index) =>
                        setState(() => _selected = index),
                    destinations: [
                      for (final item in destinations)
                        NavigationRailDestination(
                          icon: Icon(item.icon),
                          label: Text(strings.destinationLabel(item.id)),
                        ),
                    ],
                  ),
                Expanded(child: content),
              ],
            ),
          ),
          bottomNavigationBar: useNavigationRail || useNavigationDrawer
              ? null
              : NavigationBar(
                  height: textScale >= 1.8
                      ? 112
                      : (textScale > 1.15 ? 96 : null),
                  labelBehavior: textScale >= 1.8
                      ? NavigationDestinationLabelBehavior.onlyShowSelected
                      : NavigationDestinationLabelBehavior.alwaysShow,
                  selectedIndex: _selected,
                  onDestinationSelected: (index) =>
                      setState(() => _selected = index),
                  destinations: [
                    for (final item in destinations)
                      NavigationDestination(
                        icon: Icon(item.icon),
                        label: strings.destinationLabel(item.id),
                      ),
                  ],
                ),
        );
      },
    );
  }
}
