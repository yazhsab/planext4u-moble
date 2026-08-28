import 'package:flutter/material.dart';
import 'package:planext4u_core/planext4u_core.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';

enum RoleCapability {
  vendorOverview,
  vendorOrders,
  vendorCatalog,
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
    final destination = destinations[_selected];
    return Scaffold(
      appBar: AppBar(
        title: Text('Planext4u ${widget.applicationRole.label}'),
        actions: [
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
              tooltip: 'Sign out',
              onPressed: () => widget.onSignOut!(),
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child:
                widget.destinationBuilder?.call(context, destination) ??
                Planext4uStatePanel(
                  state: Planext4uViewState.empty,
                  title: destination.label,
                  message:
                      '${widget.applicationRole.label} ${destination.label.toLowerCase()} '
                      'is permission-verified and ready for its domain workflow.',
                ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selected,
        onDestinationSelected: (index) => setState(() => _selected = index),
        destinations: [
          for (final item in destinations)
            NavigationDestination(icon: Icon(item.icon), label: item.label),
        ],
      ),
    );
  }
}
