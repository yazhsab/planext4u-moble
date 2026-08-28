import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_core/planext4u_core.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

void main() {
  test(
    'food flow accepts only server totals and exposes refund state',
    () async {
      final remote = _FoodRemote();
      final controller = FoodController(remote: remote);
      await controller.loadRestaurants();
      await controller.openRestaurant(remote.restaurant);
      final cart = await controller.quote(remote.restaurant, const [
        FoodCartLineRequest(
          menuItemId: 'menu-meals',
          quantity: 2,
          optionIds: ['large'],
        ),
      ]);
      expect(cart?.total.amountMinor, 43450);
      expect(cart?.pricingVersion, 'food-pricing-v1');
      final order = await controller.place();
      expect(order?.paymentStatus, 'CAPTURED');
      remote.refund = true;
      await controller.refreshActiveOrder();
      expect(controller.state.activeOrder?.isRefunded, isTrue);
    },
  );

  test(
    'vendor onboarding resumes and uses revisioned supply operations',
    () async {
      final remote = _VendorRemote();
      final controller = VendorOperationsController(remote);
      await controller.loadAll();
      expect(controller.state.application, isNull);
      await controller.register(
        businessName: 'Local Services',
        businessType: 'Services',
        contactName: 'Owner',
      );
      await controller.submitDocuments();
      await controller.configureZone();
      await controller.configureBank();
      expect(controller.state.application?.revision, 4);
      expect(controller.state.application?.documents, isNotEmpty);
      expect(controller.state.application?.zoneCount, 1);
      expect(controller.state.application?.bankStatus, 'PENDING_VERIFICATION');
      expect(remote.revisions, [1, 2, 3]);
    },
  );

  test('rider queues failed lifecycle command and replays in order', () async {
    final remote = _RiderRemote();
    final store = MemoryRiderCommandStore();
    final controller = RiderOperationsController(remote, commandStore: store);
    await controller.load();
    await controller.refreshTasks();
    final offer = controller.state.offers.single;
    await controller.accept(offer);
    expect(controller.state.status, OperationsStatus.offline);
    expect(controller.state.pendingCommands, 1);
    expect((await store.pending()).single.kind, 'ACCEPT');
    await controller.recoverOffline();
    expect(controller.state.pendingCommands, 0);
    expect(remote.recoveredSequences, [1]);
  });

  test('rider duty owns a bounded location tracking lifecycle', () async {
    final remote = _RiderRemote();
    final tracker = _RiderTracker();
    final controller = RiderOperationsController(
      remote,
      locationTracker: tracker,
    );
    await controller.load();
    await controller.startDuty();
    expect(tracker.started, isTrue);
    await tracker.emit(
      RiderTrackedPosition(
        latitude: 13.0827,
        longitude: 80.2707,
        accuracyMeters: 12,
        capturedAt: DateTime.utc(2026, 8, 28, 12),
      ),
    );
    expect(remote.locations, hasLength(1));
    expect(remote.locations.single.sequence, 1);
    await controller.endDuty();
    expect(tracker.started, isFalse);
    controller.dispose();
  });

  test('settlement fixture reconciles gross less commission and tax', () {
    final entry = _settlement();
    expect(
      entry.gross.amountMinor -
          entry.commission.amountMinor -
          entry.tax.amountMinor,
      entry.net.amountMinor,
    );
    expect(entry.calculationVersion, 'rider-commission-v1');
  });

  test('role push rotates tokens and rejects cross-role deep links', () async {
    final messaging = _RoleMessaging();
    final remote = _RolePushRemote();
    final opened = <Uri>[];
    final registration = RolePushRegistration(
      messaging: messaging,
      remote: remote,
      role: AppRole.rider,
      platform: 'ANDROID',
      onDeepLink: opened.add,
    );
    await registration.start();
    messaging.tokens.add('rider-token-002');
    messaging.opened.add({
      'deep_link': 'https://attacker.example/rider/tasks/task-1',
    });
    messaging.opened.add({
      'deep_link': 'https://planext4u.net/rider/tasks/task-1',
    });
    await Future<void>.delayed(Duration.zero);
    expect(remote.tokens, ['rider-token-001', 'rider-token-002']);
    expect(opened.single.path, '/rider/tasks/task-1');
    expect(
      isSafeRoleDeepLink(
        Uri.parse('https://planext4u.net/vendor/orders/order-1'),
        AppRole.rider,
      ),
      isFalse,
    );
    await registration.dispose(unregister: true);
    expect(remote.unregistered, isTrue);
    await messaging.dispose();
  });
}

final class _FoodRemote implements FoodRemote {
  bool refund = false;
  final restaurant = const FoodRestaurant(
    id: 'restaurant-saravana',
    name: 'Saravana Kitchen',
    cuisine: ['South Indian'],
    rating: 4.7,
    verified: true,
    open: true,
    preparationMinutes: 20,
    deliveryFee: CatalogMoney(amountMinor: 2500, currency: 'INR'),
    minimumOrder: CatalogMoney(amountMinor: 10000, currency: 'INR'),
  );
  late final item = const FoodMenuItem(
    id: 'menu-meals',
    restaurantId: 'restaurant-saravana',
    name: 'South Indian meals',
    description: 'Fresh local lunch',
    category: 'Meals',
    vegetarian: true,
    basePrice: CatalogMoney(amountMinor: 19500, currency: 'INR'),
    available: true,
    optionGroups: [
      FoodOptionGroup(
        id: 'size',
        name: 'Size',
        minimum: 1,
        maximum: 1,
        options: [
          FoodOption(
            id: 'large',
            name: 'Large',
            priceDelta: CatalogMoney(amountMinor: 3000, currency: 'INR'),
            available: true,
          ),
        ],
      ),
    ],
  );

  FoodOrder get orderValue => FoodOrder(
    id: 'food-order-001',
    revision: refund ? 2 : 1,
    restaurantId: restaurant.id,
    status: refund ? 'REJECTED' : 'PENDING_RESTAURANT',
    total: const CatalogMoney(amountMinor: 43450, currency: 'INR'),
    paymentStatus: refund ? 'REFUNDED' : 'CAPTURED',
    refundState: refund ? 'REFUNDED' : '',
    pricingVersion: 'food-pricing-v1',
    acceptBy: DateTime.now().toUtc().add(const Duration(minutes: 3)),
    allowedActions: const {},
    timeline: const [],
  );

  @override
  Future<List<FoodRestaurant>> restaurants(String postalCode) async => [
    restaurant,
  ];
  @override
  Future<List<FoodMenuItem>> menu(String restaurantId) async => [item];
  @override
  Future<FoodCart> priceCart({
    required String restaurantId,
    required String postalCode,
    required List<FoodCartLineRequest> lines,
  }) async => FoodCart(
    id: 'food-cart-001',
    revision: 1,
    restaurant: restaurant,
    lines: const [
      {'menu_item_id': 'menu-meals', 'quantity': 2},
    ],
    subtotal: const CatalogMoney(amountMinor: 39000, currency: 'INR'),
    deliveryFee: const CatalogMoney(amountMinor: 2500, currency: 'INR'),
    tax: const CatalogMoney(amountMinor: 1950, currency: 'INR'),
    total: const CatalogMoney(amountMinor: 43450, currency: 'INR'),
    pricingVersion: 'food-pricing-v1',
    expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
  );
  @override
  Future<FoodOrder> placeOrder(String cartId, String paymentMethod) async =>
      orderValue;
  @override
  Future<FoodOrder> order(String id) async => orderValue;
  @override
  Future<List<FoodOrder>> orders() async => [orderValue];
}

final class _VendorRemote implements VendorOperationsRemote {
  VendorApplication? value;
  final List<int> revisions = [];

  VendorApplication _next({
    required String status,
    List<Object?> documents = const [],
    int zones = 0,
    String bank = 'NOT_CONFIGURED',
  }) => VendorApplication(
    id: 'vendor-application-001',
    revision: (value?.revision ?? 0) + 1,
    status: status,
    businessName: 'Local Services',
    documents: documents,
    zoneCount: zones,
    bankStatus: bank,
    verified: status == 'APPROVED',
    allowedActions: const {'SUBMIT_DOCUMENTS', 'SCHEDULE_FIELD_VISIT'},
  );

  @override
  Future<VendorApplication> application() async =>
      value ?? (throw StateError('not registered'));
  @override
  Future<VendorApplication> register({
    required String businessName,
    required String businessType,
    required String contactName,
  }) async => value = _next(status: 'REGISTERED');
  @override
  Future<VendorApplication> submitDocuments(
    int revision,
    List<Map<String, Object?>> documents,
  ) async {
    revisions.add(revision);
    return value = _next(status: 'DOCUMENTS_SUBMITTED', documents: documents);
  }

  @override
  Future<VendorApplication> setZones(
    int revision,
    List<Map<String, Object?>> zones,
  ) async {
    revisions.add(revision);
    return value = _next(
      status: value!.status,
      documents: value!.documents,
      zones: zones.length,
    );
  }

  @override
  Future<VendorApplication> setBank(
    int revision,
    Map<String, Object?> bank,
  ) async {
    revisions.add(revision);
    return value = _next(
      status: 'BANK_REVIEW',
      documents: value!.documents,
      zones: value!.zoneCount,
      bank: 'PENDING_VERIFICATION',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      switch (invocation.memberName) {
        #dashboard => Future<Map<String, Object?>>.value(const {}),
        #catalog => Future<List<VendorCatalogItem>>.value(const []),
        #work => Future<List<VendorWorkItem>>.value(const []),
        _ => super.noSuchMethod(invocation),
      };
}

final class _RiderRemote implements RiderOperationsRemote {
  bool failAccept = true;
  final List<int> recoveredSequences = [];
  final List<RiderLocationCommand> locations = [];
  RiderDuty? activeDuty;
  final profileValue = const RiderProfile(
    id: 'rider-profile-001',
    revision: 2,
    status: 'APPROVED',
    fullName: 'Synthetic Rider',
    vehicleNumber: 'TN01AB1234',
    bankStatus: 'VERIFIED',
    zones: ['600001'],
    maxConcurrent: 2,
    allowedActions: {'START_DUTY', 'VIEW_EARNINGS'},
  );
  late final taskValue = RiderTask(
    id: 'delivery-001',
    revision: 3,
    orderId: 'food-order-001',
    orderType: 'FOOD',
    status: 'OFFERED',
    pickupLabel: 'Kitchen',
    dropoffLabel: 'Customer',
    distanceMeters: 4800,
    earning: const CatalogMoney(amountMinor: 8000, currency: 'INR'),
    offerExpiresAt: DateTime.now().toUtc().add(const Duration(minutes: 1)),
    allowedActions: const {'ACCEPT'},
    podAssetId: '',
  );

  @override
  Future<RiderProfile> profile() async => profileValue;
  @override
  Future<RiderDuty> duty() async => throw StateError('off duty');
  @override
  Future<RiderDuty> startDuty(String zoneId) async => activeDuty = RiderDuty(
    id: 'duty-001',
    revision: 1,
    status: 'ONLINE',
    zoneId: zoneId,
    activeTasks: 0,
    lastSeenAt: DateTime.now().toUtc(),
  );
  @override
  Future<RiderDuty> endDuty(int revision) async => activeDuty = RiderDuty(
    id: 'duty-001',
    revision: revision + 1,
    status: 'OFFLINE',
    zoneId: '600001',
    activeTasks: 0,
    lastSeenAt: DateTime.now().toUtc(),
  );
  @override
  Future<List<RiderTask>> offers() async => [taskValue];
  @override
  Future<List<RiderTask>> tasks() async => const [];
  @override
  Future<RiderTask> accept(RiderTask task) async {
    if (failAccept) {
      failAccept = false;
      throw const ApiTransportFailure(correlationId: 'offline-test');
    }
    return task;
  }

  @override
  Future<List<Map<String, Object?>>> recover(
    List<RiderOfflineCommand> commands,
  ) async {
    recoveredSequences.addAll(commands.map((value) => value.deviceSequence));
    return [
      for (final command in commands)
        {'command_id': command.commandId, 'status': 'APPLIED'},
    ];
  }

  @override
  Future<void> updateLocation(RiderLocationCommand command) async {
    locations.add(command);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _RiderTracker implements RiderLocationTracker {
  Future<void> Function(RiderTrackedPosition)? _onPosition;
  bool get started => _onPosition != null;

  @override
  Future<void> start(
    Future<void> Function(RiderTrackedPosition position) onPosition,
  ) async {
    _onPosition = onPosition;
  }

  Future<void> emit(RiderTrackedPosition position) async {
    await _onPosition!(position);
  }

  @override
  Future<void> stop() async {
    _onPosition = null;
  }
}

final class _RoleMessaging implements RolePushMessaging {
  final tokens = StreamController<String>.broadcast();
  final opened = StreamController<Map<String, String>>.broadcast();

  @override
  Future<bool> authorize() async => true;
  @override
  Future<String?> token() async => 'rider-token-001';
  @override
  Stream<String> get tokenRefreshes => tokens.stream;
  @override
  Future<Map<String, String>?> initialInteraction() async => null;
  @override
  Stream<Map<String, String>> get interactions => opened.stream;

  Future<void> dispose() async {
    await tokens.close();
    await opened.close();
  }
}

final class _RolePushRemote implements RolePushDeviceRemote {
  final tokens = <String>[];
  bool unregistered = false;

  @override
  Future<void> register({
    required String token,
    required String platform,
    required String locale,
  }) async {
    tokens.add(token);
  }

  @override
  Future<void> unregister() async {
    unregistered = true;
  }
}

SettlementEntry _settlement() => SettlementEntry(
  id: 'ledger-001',
  kind: 'DELIVERY_EARNING',
  referenceId: 'delivery-001',
  gross: const CatalogMoney(amountMinor: 8000, currency: 'INR'),
  commission: const CatalogMoney(amountMinor: 800, currency: 'INR'),
  tax: const CatalogMoney(amountMinor: 144, currency: 'INR'),
  net: const CatalogMoney(amountMinor: 7056, currency: 'INR'),
  calculationVersion: 'rider-commission-v1',
  availableAt: DateTime.utc(2026, 8, 30),
);
