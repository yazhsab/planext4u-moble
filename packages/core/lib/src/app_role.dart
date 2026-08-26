/// A store-distributed Planext4u application role.
enum AppRole {
  customer('Customer', 'Discover local products, services, and community'),
  vendor('Vendor', 'Manage business, catalog, orders, and settlements'),
  rider('Rider', 'Manage duty, assignments, proof, and earnings');

  const AppRole(this.label, this.description);

  /// Human-readable role name used by accessible application chrome.
  final String label;

  /// Short role purpose shown by the Phase 2 foundation shell.
  final String description;
}
