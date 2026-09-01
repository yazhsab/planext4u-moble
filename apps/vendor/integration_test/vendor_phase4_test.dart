import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:planext4u_config/planext4u_config.dart';
import 'package:planext4u_experience/planext4u_experience.dart';
import 'package:planext4u_vendor/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'MOB-E2E-006 vendor onboarding approval catalog and first settlement',
    (tester) async {
      final remote = _VendorJourneyRemote();
      final controller = VendorOperationsController(remote);
      await controller.loadAll();
      await controller.register(
        businessName: 'Synthetic Home Services',
        businessType: 'Home services',
        contactName: 'Synthetic Vendor',
      );
      await controller.submitDocuments(const [
        {
          'kind': 'BUSINESS_REGISTRATION',
          'asset_id': 'asset-business-registration-e2e-006',
        },
        {'kind': 'OWNER_IDENTITY', 'asset_id': 'asset-owner-identity-e2e-006'},
      ]);
      await controller.scheduleFieldVisit();
      remote.fieldVisitPassed();
      await controller.configureZones(const [
        {
          'id': 'zone-chennai-core',
          'postal_codes': ['600001'],
          'latitude': 13.0827,
          'longitude': 80.2707,
          'radius_km': 25,
          'policy_version': 'zone-policy-v1',
        },
      ]);
      await controller.configureBank(const {
        'reference': 'bank-reference-tokenized-e2e-006',
        'holder_name': 'Synthetic Vendor',
        'last4': '1234',
        'ifsc': 'HDFC0001234',
      });
      remote.approve();
      await controller.loadAll();
      await controller.createCatalog(
        kind: 'SERVICE',
        name: 'Deep cleaning',
        amountMinor: 20000,
      );
      await controller.setInventory(controller.state.catalog.single, 4);
      await controller.setSchedule(controller.state.catalog.single);
      await controller.loadSettlements();

      await tester.pumpWidget(
        VendorApp(
          config: AppConfig.parse(
            rawEnvironment: 'development',
            rawApiBaseUrl: 'http://10.0.2.2:8080',
          ),
          controller: controller,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Synthetic Home Services'), findsOneWidget);
      expect(find.text('APPROVED'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Catalog'));
      await tester.pumpAndSettle();
      expect(find.text('Deep cleaning'), findsOneWidget);
      expect(find.textContaining('Stock 4'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Earnings'));
      await tester.pumpAndSettle();
      expect(find.text('₹88.20'), findsWidgets);
      expect(find.textContaining('settlement-v1'), findsOneWidget);
      expect(
        remote.evidence,
        containsAllInOrder([
          'registration',
          'private_documents',
          'field_visit_scheduled',
          'field_visit_passed',
          'zones',
          'bank_pending',
          'admin_approval',
          'catalog',
          'inventory_revision',
          'schedule_revision',
          'ledger',
          'payouts',
        ]),
      );
    },
  );
}

final class _VendorJourneyRemote implements VendorOperationsRemote {
  final evidence = <String>[];
  VendorApplication? _application;
  VendorCatalogItem? _catalog;

  VendorApplication _applicationValue({
    required String status,
    List<Object?>? documents,
    int? zones,
    String? bank,
  }) => VendorApplication(
    id: 'vendor-application-e2e-006',
    revision: (_application?.revision ?? 0) + 1,
    status: status,
    businessName: 'Synthetic Home Services',
    documents: documents ?? _application?.documents ?? const [],
    zoneCount: zones ?? _application?.zoneCount ?? 0,
    bankStatus: bank ?? _application?.bankStatus ?? 'NOT_CONFIGURED',
    verified: status == 'APPROVED',
    allowedActions: const {'SCHEDULE_FIELD_VISIT'},
  );

  void fieldVisitPassed() {
    evidence.add('field_visit_passed');
    _application = _applicationValue(status: 'FIELD_VISIT_PASSED');
  }

  void approve() {
    evidence.add('admin_approval');
    _application = _applicationValue(status: 'APPROVED', bank: 'VERIFIED');
  }

  @override
  Future<VendorApplication> application() async =>
      _application ?? (throw StateError('new vendor'));
  @override
  Future<VendorApplication> register({
    required String businessName,
    required String businessType,
    required String contactName,
  }) async {
    evidence.add('registration');
    return _application = _applicationValue(status: 'REGISTERED');
  }

  @override
  Future<VendorApplication> submitDocuments(
    int revision,
    List<Map<String, Object?>> documents,
  ) async {
    evidence.add('private_documents');
    return _application = _applicationValue(
      status: 'DOCUMENTS_SUBMITTED',
      documents: documents,
    );
  }

  @override
  Future<VendorApplication> scheduleVisit(
    int revision,
    DateTime scheduledAt,
  ) async {
    evidence.add('field_visit_scheduled');
    return _application = _applicationValue(status: 'FIELD_VISIT_SCHEDULED');
  }

  @override
  Future<VendorApplication> setZones(
    int revision,
    List<Map<String, Object?>> zones,
  ) async {
    evidence.add('zones');
    return _application = _applicationValue(
      status: _application!.status,
      zones: zones.length,
    );
  }

  @override
  Future<VendorApplication> setBank(
    int revision,
    Map<String, Object?> bank,
  ) async {
    evidence.add('bank_pending');
    return _application = _applicationValue(
      status: 'BANK_REVIEW',
      bank: 'PENDING_VERIFICATION',
    );
  }

  @override
  Future<Map<String, Object?>> dashboard() async => const {
    'catalog_items': 1,
    'low_stock_items': 1,
    'open_work_items': 0,
    'points': 0,
  };
  @override
  Future<List<VendorCatalogItem>> catalog() async => [?_catalog];
  @override
  Future<VendorCatalogItem> createCatalog(Map<String, Object?> value) async {
    evidence.add('catalog');
    return _catalog = const VendorCatalogItem(
      id: 'catalog-e2e-006',
      revision: 1,
      kind: 'SERVICE',
      name: 'Deep cleaning',
      sku: 'CLEAN-001',
      price: CatalogMoney(amountMinor: 20000, currency: 'INR'),
      stock: 0,
      approvalStatus: 'APPROVED',
      active: true,
      schedules: [],
      allowedActions: {'SET_INVENTORY', 'SET_SCHEDULE'},
    );
  }

  @override
  Future<VendorCatalogItem> setInventory(
    VendorCatalogItem item,
    int stock,
  ) async {
    evidence.add('inventory_revision');
    return _catalog = VendorCatalogItem(
      id: item.id,
      revision: item.revision + 1,
      kind: item.kind,
      name: item.name,
      sku: item.sku,
      price: item.price,
      stock: stock,
      approvalStatus: item.approvalStatus,
      active: item.active,
      schedules: item.schedules,
      allowedActions: item.allowedActions,
    );
  }

  @override
  Future<VendorCatalogItem> setSchedule(
    VendorCatalogItem item,
    List<Map<String, Object?>> schedules,
  ) async {
    evidence.add('schedule_revision');
    return _catalog = VendorCatalogItem(
      id: item.id,
      revision: item.revision + 1,
      kind: item.kind,
      name: item.name,
      sku: item.sku,
      price: item.price,
      stock: item.stock,
      approvalStatus: item.approvalStatus,
      active: item.active,
      schedules: schedules,
      allowedActions: item.allowedActions,
    );
  }

  @override
  Future<List<VendorWorkItem>> work() async => const [];
  @override
  Future<List<SettlementEntry>> ledger() async {
    evidence.add('ledger');
    return [
      SettlementEntry(
        id: 'settlement-e2e-006',
        kind: 'SERVICE_EARNING',
        referenceId: 'booking-e2e-004',
        gross: const CatalogMoney(amountMinor: 10000, currency: 'INR'),
        commission: const CatalogMoney(amountMinor: 1000, currency: 'INR'),
        tax: const CatalogMoney(amountMinor: 180, currency: 'INR'),
        net: const CatalogMoney(amountMinor: 8820, currency: 'INR'),
        calculationVersion: 'settlement-v1',
        availableAt: DateTime.utc(2026, 8, 27),
      ),
    ];
  }

  @override
  Future<List<PayoutRecord>> payouts() async {
    evidence.add('payouts');
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
