import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_core/planext4u_core.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

void main() {
  test('rider navigation uses only server-supplied valid coordinates', () {
    final task = RiderTask.fromJson({
      'id': 'delivery-navigation-001',
      'revision': 1,
      'order_id': 'order-navigation-001',
      'order_type': 'PRODUCT',
      'status': 'ASSIGNED',
      'pickup': {
        'label': 'Verified pickup',
        'point': {'latitude': 13.0827, 'longitude': 80.2707},
      },
      'dropoff': {
        'label': 'Protected drop-off',
        'point': {'latitude': 13.0674, 'longitude': 80.2376},
      },
      'distance_meters': 4800,
      'earning': {'amount_minor': 8000, 'currency': 'INR'},
      'allowed_actions': ['NAVIGATE_PICKUP'],
    });
    expect(task.navigationDestination?.latitude, 13.0827);
    expect(task.navigationDestination?.longitude, 80.2707);
    expect(
      () => RiderTask.fromJson({
        'id': 'delivery-navigation-002',
        'revision': 1,
        'order_id': 'order-navigation-002',
        'order_type': 'PRODUCT',
        'status': 'ASSIGNED',
        'pickup': {
          'label': 'Invalid pickup',
          'point': {'latitude': 130, 'longitude': 80.2707},
        },
        'dropoff': {'label': 'Protected drop-off'},
        'distance_meters': 4800,
        'earning': {'amount_minor': 8000, 'currency': 'INR'},
        'allowed_actions': ['NAVIGATE_PICKUP'],
      }),
      throwsFormatException,
    );
  });

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
      await controller.submitDocuments(const [
        {
          'kind': 'BUSINESS_REGISTRATION',
          'asset_id': 'asset-business-registration-001',
        },
        {'kind': 'OWNER_IDENTITY', 'asset_id': 'asset-owner-identity-001'},
      ]);
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
        'reference': 'bank-reference-tokenized-001',
        'holder_name': 'Synthetic Vendor',
        'last4': '1234',
        'ifsc': 'HDFC0001234',
      });
      expect(controller.state.application?.revision, 4);
      expect(controller.state.application?.documents, isNotEmpty);
      expect(controller.state.application?.zoneCount, 1);
      expect(controller.state.application?.bankStatus, 'PENDING_VERIFICATION');
      expect(remote.revisions, [1, 2, 3]);
    },
  );

  test('vendor catalog and schedule drafts expose sync and conflict', () async {
    final remote = _VendorRemote();
    final controller = VendorOperationsController(remote);
    controller.saveCatalogDraft(
      kind: 'service',
      name: 'Deep cleaning',
      amountMinor: 20000,
    );
    expect(controller.state.catalogDraftStatus, VendorDraftSyncStatus.draft);
    await controller.publishCatalogDraft();
    expect(controller.state.catalog, hasLength(1));
    expect(controller.state.catalogDraftStatus, VendorDraftSyncStatus.synced);

    controller.saveScheduleDraft(controller.state.catalog.single);
    remote.scheduleConflict = true;
    await controller.publishScheduleDraft();
    expect(
      controller.state.scheduleDraftStatus,
      VendorDraftSyncStatus.conflict,
    );
    expect(controller.state.scheduleDraft, isNotNull);
  });

  test('vendor contracts decode operational business details safely', () {
    final application = VendorApplication.fromJson({
      'id': 'vendor-application-contract-001',
      'vendor_id': 'vendor-contract-001',
      'revision': 7,
      'status': 'FIELD_VISIT_SCHEDULED',
      'business_name': 'Contract Services',
      'business_type': 'HOME_SERVICES',
      'contact_name': 'Contract Owner',
      'documents': [
        {
          'kind': 'BUSINESS_REGISTRATION',
          'asset_id': 'asset-private-contract-001',
          'ocr_status': 'PASSED',
          'extracted_fields': {'registration_number': 'sensitive'},
        },
      ],
      'service_zones': [
        {
          'id': 'zone-contract-001',
          'postal_codes': ['600001'],
          'latitude': 13.0827,
          'longitude': 80.2707,
          'radius_km': 12,
          'policy_version': 'zone-policy-v1',
        },
      ],
      'bank_account': {
        'reference': 'bank-private-contract-001',
        'holder_name': 'Contract Services',
        'last4': '4321',
        'ifsc': 'HDFC0001234',
        'status': 'PENDING_VERIFICATION',
      },
      'field_visit': {
        'id': 'visit-contract-001',
        'scheduled_at': '2026-09-04T04:30:00Z',
        'latitude': 13.0827,
        'longitude': 80.2707,
        'allowed_radius_m': 200,
      },
      'verified': false,
      'timeline': [
        {
          'status': 'FIELD_VISIT_SCHEDULED',
          'actor': 'vendor-contract-001',
          'created_at': '2026-09-03T04:30:00Z',
        },
      ],
      'created_at': '2026-09-01T04:30:00Z',
      'updated_at': '2026-09-03T04:30:00Z',
      'allowed_actions': ['SCHEDULE_FIELD_VISIT'],
    });

    expect(application.businessType, 'HOME_SERVICES');
    expect(application.contactName, 'Contract Owner');
    expect(application.documentSummaries.single.ocrStatus, 'PASSED');
    expect(application.documents.single, isNot(contains('asset_id')));
    expect(application.documents.single, isNot(contains('extracted_fields')));
    expect(application.serviceZones.single.postalCodes, ['600001']);
    expect(application.bank?.last4, '4321');
    expect(
      application.fieldVisit?.scheduledAt,
      DateTime.utc(2026, 9, 4, 4, 30),
    );
    expect(application.timeline.single.status, 'FIELD_VISIT_SCHEDULED');
  });

  test(
    'vendor catalog edits, stock and schedules retain server revisions',
    () async {
      final remote = _VendorRemote();
      final controller = VendorOperationsController(remote);
      controller.saveCatalogDraft(
        kind: 'service',
        name: 'Deep cleaning',
        description: 'Verified two-person cleaning',
        sku: 'CLEAN-DEEP-001',
        amountMinor: 20000,
      );
      await controller.publishCatalogDraft();

      await controller.updateCatalog(
        item: controller.state.catalog.single,
        kind: 'SERVICE',
        name: 'Premium deep cleaning',
        description: 'Verified three-person cleaning',
        sku: 'CLEAN-DEEP-002',
        amountMinor: 30000,
      );
      await controller.setInventory(controller.state.catalog.single, 17);
      controller.saveScheduleDraft(
        controller.state.catalog.single,
        schedules: const [
          {
            'weekday': 2,
            'starts_minute': 600,
            'ends_minute': 1080,
            'time_zone': 'Asia/Kolkata',
            'capacity': 6,
            'buffer_minutes': 20,
          },
        ],
      );
      await controller.publishScheduleDraft();

      expect(remote.updatedCatalogPayload?['sku'], 'CLEAN-DEEP-002');
      expect(remote.inventoryValues, [17]);
      expect(remote.scheduleValues.single.single['weekday'], 2);
      expect(controller.state.catalog.single.revision, 4);
      expect(controller.state.catalog.single.stock, 17);
      expect(
        controller.state.catalog.single.schedules.single,
        containsPair('capacity', 6),
      );
    },
  );

  test(
    'vendor inventory and availability reject unsafe local values',
    () async {
      final remote = _VendorRemote();
      final controller = VendorOperationsController(remote);
      controller.saveCatalogDraft(
        kind: 'service',
        name: 'Deep cleaning',
        amountMinor: 20000,
      );
      await controller.publishCatalogDraft();
      final item = controller.state.catalog.single;

      expect(() => controller.setInventory(item, -1), throwsFormatException);
      expect(
        () => controller.saveScheduleDraft(
          item,
          schedules: const [
            {
              'weekday': 1,
              'starts_minute': 600,
              'ends_minute': 900,
              'time_zone': 'Asia/Kolkata',
              'capacity': 1,
              'buffer_minutes': 0,
            },
            {
              'weekday': 1,
              'starts_minute': 800,
              'ends_minute': 1000,
              'time_zone': 'Asia/Kolkata',
              'capacity': 1,
              'buffer_minutes': 0,
            },
          ],
        ),
        throwsFormatException,
      );
    },
  );

  testWidgets('vendor catalog accepts an exact stock quantity', (tester) async {
    final remote = _VendorRemote()
      ..value = const VendorApplication(
        id: 'vendor-stock-ui',
        revision: 5,
        status: 'APPROVED',
        businessName: 'Stock UI Services',
        documents: [],
        zoneCount: 1,
        bankStatus: 'VERIFIED',
        verified: true,
        allowedActions: {},
      )
      ..catalogItem = const VendorCatalogItem(
        id: 'catalog-stock-ui',
        revision: 2,
        kind: 'PRODUCT',
        name: 'Cleaning kit',
        description: 'Professional cleaning kit',
        sku: 'KIT-001',
        price: CatalogMoney(amountMinor: 12000, currency: 'INR'),
        stock: 3,
        approvalStatus: 'APPROVED',
        active: true,
        schedules: [],
        allowedActions: {'EDIT', 'SET_INVENTORY', 'SET_SCHEDULE'},
      );
    final controller = VendorOperationsController(remote);
    await controller.loadAll();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VendorOperationsView(
            controller: controller,
            destination: const RoleDestination(
              id: 'catalog',
              label: 'Catalog',
              icon: Icons.inventory_2_outlined,
              capability: RoleCapability.vendorCatalog,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final setStockButton = find.byKey(
      const ValueKey('vendor-set-stock-catalog-stock-ui'),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(setStockButton);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('vendor-stock-input')),
      '17',
    );
    await tester.tap(find.byKey(const ValueKey('vendor-save-stock')));
    await tester.pumpAndSettle();

    expect(remote.inventoryValues, [17]);
    expect(find.textContaining('Stock 17'), findsOneWidget);
  });

  test('vendor onboarding rejects incomplete or raw provider payloads', () {
    final controller = VendorOperationsController(_VendorRemote());
    expect(
      () => controller.submitDocuments(const [
        {
          'kind': 'BUSINESS_REGISTRATION',
          'asset_id': 'asset-business-registration-only',
        },
      ]),
      throwsFormatException,
    );
    expect(
      () => controller.configureBank(const {
        'account_number': '1234567890123456',
        'holder_name': 'Raw Bank Account',
        'last4': '3456',
        'ifsc': 'HDFC0001234',
      }),
      throwsFormatException,
    );
  });

  test('rider registration accepts only verified-provider references', () {
    final payload = const RiderRegistrationDraft(
      fullName: 'Synthetic Rider',
      vehicleType: 'MOTORBIKE',
      vehicleNumber: 'TN01AB1234',
      documents: [
        RiderDocumentDraft(
          kind: 'IDENTITY',
          assetId: 'asset-rider-identity-001',
        ),
        RiderDocumentDraft(
          kind: 'DRIVER_LICENSE',
          assetId: 'asset-rider-license-001',
        ),
        RiderDocumentDraft(
          kind: 'VEHICLE_REGISTRATION',
          assetId: 'asset-rider-vehicle-001',
        ),
        RiderDocumentDraft(
          kind: 'INSURANCE',
          assetId: 'asset-rider-insurance-001',
        ),
      ],
      bankReference: 'bank-reference-rider-token-001',
      zones: ['600001'],
      dutyLocationConsent: true,
    ).toJson();
    expect(payload['phone_masked'], isNull);
    expect(payload['bank_reference'], 'bank-reference-rider-token-001');
    expect(payload['documents'], hasLength(4));

    expect(
      () => const RiderRegistrationDraft(
        fullName: 'Synthetic Rider',
        vehicleType: 'BICYCLE',
        vehicleNumber: 'BIKE-001',
        documents: [
          RiderDocumentDraft(
            kind: 'IDENTITY',
            assetId: 'asset-rider-identity-001',
          ),
        ],
        bankReference: 'bank-reference-rider-token-001',
        zones: ['600001'],
        dutyLocationConsent: false,
      ).toJson(),
      throwsFormatException,
    );

    expect(
      () => const RiderRegistrationDraft(
        fullName: 'Synthetic Rider',
        vehicleType: 'MOTORBIKE',
        vehicleNumber: 'TN01AB1234',
        documents: [
          RiderDocumentDraft(
            kind: 'IDENTITY',
            assetId: 'asset-rider-identity-001',
          ),
        ],
        bankReference: 'bank-reference-rider-token-001',
        zones: ['600001'],
        dutyLocationConsent: true,
      ).toJson(),
      throwsFormatException,
    );
  });

  test('rider queues failed lifecycle command and replays in order', () async {
    final remote = _RiderRemote();
    final store = MemoryRiderCommandStore();
    final controller = RiderOperationsController(remote, commandStore: store);
    await controller.load();
    await controller.refreshTasks();
    final offer = controller.state.offers.single;
    await controller.pickup(offer);
    expect(controller.state.status, OperationsStatus.offline);
    expect(controller.state.pendingCommands, 1);
    expect((await store.pending()).single.kind, 'PICKUP');
    await controller.recoverOffline();
    expect(controller.state.pendingCommands, 0);
    expect(remote.recoveredSequences, [1]);
  });

  test('rider command sequence resumes after an application restart', () async {
    final store = MemoryRiderCommandStore();
    await store.enqueue(
      const RiderOfflineCommand(
        deviceSequence: 41,
        commandId: 'mobile-persisted-00000041',
        kind: 'PICKUP',
        taskId: 'task-001',
        revision: 1,
      ),
    );
    final remote = _RiderRemote();
    final old = remote.profileValue;
    remote.profileValue = RiderProfile(
      id: old.id,
      revision: old.revision,
      status: old.status,
      fullName: old.fullName,
      vehicleNumber: old.vehicleNumber,
      bankStatus: old.bankStatus,
      zones: old.zones,
      maxConcurrent: old.maxConcurrent,
      allowedActions: old.allowedActions,
      lastCommandSequence: 40,
    );
    final controller = RiderOperationsController(remote, commandStore: store);
    await controller.load();
    await controller.refreshTasks();
    await controller.pickup(controller.state.offers.single);
    final pending = await store.pending();
    expect(pending.map((value) => value.deviceSequence), [41, 42]);
  });

  test('empty ACK queue restart continues from the server sequence', () async {
    final remote = _RiderRemote();
    final store = MemoryRiderCommandStore();
    var controller = RiderOperationsController(remote, commandStore: store);
    await controller.load();
    await controller.refreshTasks();
    await controller.pickup(controller.state.offers.single);
    await controller.recoverOffline();
    expect(await store.pending(), isEmpty);
    controller.dispose();
    remote.failAccept = true;
    controller = RiderOperationsController(remote, commandStore: store);
    await controller.load();
    await controller.refreshTasks();
    await controller.pickup(controller.state.offers.single);
    expect((await store.pending()).single.deviceSequence, 2);
    controller.dispose();
  });

  test('unsupported offline acceptance is visible and never queued', () async {
    final remote = _RiderRemote();
    final store = MemoryRiderCommandStore();
    final controller = RiderOperationsController(remote, commandStore: store);
    await controller.load();
    await controller.refreshTasks();
    await controller.accept(controller.state.offers.single);
    expect(await store.pending(), isEmpty);
    expect(controller.state.message, contains('needs a connection'));
    controller.dispose();
  });

  test('rider offline queue rejects invalid and unbounded commands', () async {
    final store = MemoryRiderCommandStore();
    await expectLater(
      store.enqueue(
        const RiderOfflineCommand(
          deviceSequence: 0,
          commandId: 'short',
          kind: 'UNKNOWN',
          taskId: '',
          revision: -1,
        ),
      ),
      throwsFormatException,
    );
    final commands = [
      for (
        var index = 1;
        index <= RiderCommandQueuePolicy.maxCommands + 1;
        index++
      )
        RiderOfflineCommand(
          deviceSequence: index,
          commandId: 'mobile-bounded-${index.toString().padLeft(8, '0')}',
          kind: 'ACCEPT',
          taskId: 'task-001',
          revision: 1,
        ),
    ];
    await expectLater(store.replace(commands), throwsStateError);
  });

  test(
    'delivery withdrawal stops duty GPS and drops queued callbacks and manual locations',
    () async {
      final consentRemote = _DeliveryConsents()..hold = Completer<void>();
      final consent = ConsentController(consentRemote);
      final remote = _RiderRemote()..locationGate = Completer<void>();
      final tracker = _RiderTracker();
      final controller = RiderOperationsController(
        remote,
        locationTracker: tracker,
        deliveryPolicyLoader: () async => _deliveryPolicy,
      );
      controller.bindDeliveryConsents(consent);
      await controller.load();
      await controller.startDuty();
      expect(tracker.started, true);
      final point = RiderTrackedPosition(
        latitude: 13.0827,
        longitude: 80.2707,
        accuracyMeters: 8,
        capturedAt: DateTime.now().toUtc(),
      );
      final first = tracker.emit(point);
      await Future<void>.delayed(Duration.zero);
      final queued = tracker.emit(point);
      final pending = consent.setConsent(
        purpose: ConsentPurpose.locationDelivery,
        granted: false,
        policyVersion: 'delivery-v1',
      );
      expect(tracker.started, false);
      await controller.updateLocation(
        latitude: 13.0827,
        longitude: 80.2707,
        accuracyMeters: 8,
      );
      remote.locationGate!.complete();
      await Future.wait([first, queued]);
      expect(
        remote.locations,
        hasLength(1),
      ); // Only the call already sent before withdrawal.
      consentRemote.hold!.complete();
      await pending;
      controller.dispose();
      consent.dispose();
    },
  );

  test(
    'current published delivery policy and explicit grant are required before native duty',
    () async {
      final consentRemote = _DeliveryConsents()..version = 'delivery-old';
      final consents = ConsentController(consentRemote);
      final tracker = _RiderTracker();
      final remote = _RiderRemote();
      final controller = RiderOperationsController(
        remote,
        locationTracker: tracker,
        deliveryPolicyLoader: () async => _deliveryPolicy,
      );
      controller.bindDeliveryConsents(consents);
      await controller.load();
      await controller.startDuty();
      expect(tracker.started, false);
      expect(controller.deliveryLocationAllowed, false);
      await controller.allowDeliveryLocation();
      expect(controller.deliveryLocationAllowed, true);
      await controller.startDuty();
      expect(tracker.started, true);
      expect(consentRemote.version, 'delivery-v1');
      controller.dispose();
      consents.dispose();
    },
  );

  test(
    'missing published delivery policy fails closed without preventing profile inspection',
    () async {
      final consents = ConsentController(_DeliveryConsents());
      final tracker = _RiderTracker();
      final controller = RiderOperationsController(
        _RiderRemote(),
        locationTracker: tracker,
        deliveryPolicyLoader: () async => null,
      );
      controller.bindDeliveryConsents(consents);
      await controller.load();
      expect(controller.state.profile, isNotNull);
      await controller.startDuty();
      expect(tracker.started, false);
      expect(controller.deliveryPolicyAvailable, false);
      controller.dispose();
      consents.dispose();
    },
  );

  test(
    'withdrawal during device permission completion cannot start late tracking',
    () async {
      final consents = ConsentController(_DeliveryConsents());
      final tracker = _RiderTracker()..startGate = Completer<void>();
      final controller = RiderOperationsController(
        _RiderRemote(),
        locationTracker: tracker,
        deliveryPolicyLoader: () async => _deliveryPolicy,
      );
      controller.bindDeliveryConsents(consents);
      await controller.load();
      final start = controller.startDuty();
      await Future<void>.delayed(Duration.zero);
      await consents.setConsent(
        purpose: ConsentPurpose.locationDelivery,
        granted: false,
        policyVersion: 'delivery-v1',
      );
      tracker.startGate!.complete();
      await start;
      expect(tracker.started, false);
      expect(controller.deliveryLocationAllowed, false);
      controller.dispose();
      consents.dispose();
    },
  );

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
        capturedAt: DateTime.now().toUtc(),
      ),
    );
    expect(remote.locations, hasLength(1));
    expect(remote.locations.single.sequence, 1);
    await controller.endDuty();
    expect(tracker.started, isFalse);
    controller.dispose();
  });

  test(
    'active duty restart restores location sequence and surfaces stale tracking',
    () async {
      final remote = _RiderRemote();
      final old = remote.profileValue;
      remote.profileValue = RiderProfile(
        id: old.id,
        revision: old.revision,
        status: old.status,
        fullName: old.fullName,
        vehicleNumber: old.vehicleNumber,
        bankStatus: old.bankStatus,
        zones: old.zones,
        maxConcurrent: old.maxConcurrent,
        allowedActions: old.allowedActions,
        lastLocationSequence: 76,
      );
      remote.activeDuty = RiderDuty(
        id: 'active-duty',
        revision: 1,
        status: 'ACTIVE',
        zoneId: '600001',
        activeTasks: 0,
        lastSeenAt: DateTime.now().toUtc(),
      );
      final tracker = _RiderTracker();
      final controller = RiderOperationsController(
        remote,
        locationTracker: tracker,
      );
      await controller.load();
      expect(tracker.started, isTrue);
      await tracker.emit(
        RiderTrackedPosition(
          latitude: 13.08,
          longitude: 80.27,
          accuracyMeters: 8,
          capturedAt: DateTime.now().toUtc(),
        ),
      );
      expect(remote.locations.single.sequence, 77);
      await tracker.emit(
        RiderTrackedPosition(
          latitude: 13.08,
          longitude: 80.27,
          accuracyMeters: 8,
          capturedAt: DateTime.now().toUtc().subtract(
            const Duration(minutes: 20),
          ),
        ),
      );
      expect(controller.state.locationStatus, RiderLocationStatus.unavailable);
      expect(controller.state.message, contains('could not be shared'));
      expect(remote.locations, hasLength(1));
      controller.dispose();
    },
  );

  test('tracking failure is visible and resumes after reconnect', () async {
    final remote = _RiderRemote();
    final tracker = _RiderTracker();
    final controller = RiderOperationsController(
      remote,
      locationTracker: tracker,
    );
    await controller.load();
    await controller.startDuty();
    remote.failLocation = true;
    await tracker.emit(
      RiderTrackedPosition(
        latitude: 13.08,
        longitude: 80.27,
        accuracyMeters: 8,
        capturedAt: DateTime.now().toUtc(),
      ),
    );
    expect(controller.state.status, OperationsStatus.offline);
    expect(controller.state.locationStatus, RiderLocationStatus.unavailable);
    expect(controller.state.message, contains('could not be shared'));
    remote.failLocation = false;
    await controller.recoverOffline();
    await tracker.emit(
      RiderTrackedPosition(
        latitude: 13.08,
        longitude: 80.27,
        accuracyMeters: 8,
        capturedAt: DateTime.now().toUtc(),
      ),
    );
    expect(controller.state.locationStatus, RiderLocationStatus.tracking);
    expect(remote.locations.single.sequence, 2);
    controller.dispose();
  });

  test('rider location denial remains actionable and opens settings', () async {
    final tracker = _RiderTracker(
      startError: const RiderLocationException(
        RiderLocationIssue.permissionPermanentlyDenied,
        'Location permission is blocked.',
      ),
    );
    final controller = RiderOperationsController(
      _RiderRemote(),
      locationTracker: tracker,
    );
    await controller.load();
    await controller.startDuty();
    expect(
      controller.state.locationStatus,
      RiderLocationStatus.permissionPermanentlyDenied,
    );
    await controller.openLocationSettings();
    expect(tracker.appSettingsOpened, isTrue);
  });

  test('rider POD validates every server-required evidence type', () {
    final remote = _RiderRemote();
    final controller = RiderOperationsController(remote);
    final task = RiderTask(
      id: remote.taskValue.id,
      revision: remote.taskValue.revision,
      orderId: remote.taskValue.orderId,
      orderType: remote.taskValue.orderType,
      status: 'PICKED_UP',
      pickupLabel: remote.taskValue.pickupLabel,
      dropoffLabel: remote.taskValue.dropoffLabel,
      distanceMeters: remote.taskValue.distanceMeters,
      earning: remote.taskValue.earning,
      offerExpiresAt: null,
      allowedActions: const {'COMPLETE'},
      podAssetId: '',
      requiredEvidence: const {'OTP', 'PHOTO', 'SIGNATURE'},
    );

    expect(
      () => controller.complete(task, otp: '123456'),
      throwsFormatException,
    );
    expect(
      () => controller.complete(
        task,
        otp: '123456',
        blurredPhotoAssetId: 'asset-photo',
      ),
      throwsFormatException,
    );
    expect(
      () => controller.complete(
        task,
        otp: 'abc',
        blurredPhotoAssetId: 'asset-photo',
        signatureAssetId: 'asset-signature',
      ),
      throwsFormatException,
    );
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

  testWidgets('vendor and rider priority views fit at 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final vendorRemote = _VendorRemote()
      ..value = const VendorApplication(
        id: 'vendor-a11y',
        revision: 4,
        status: 'APPROVED',
        businessName: 'Accessible Local Services',
        documents: [],
        zoneCount: 1,
        bankStatus: 'VERIFIED',
        verified: true,
        allowedActions: {},
      );
    final vendor = VendorOperationsController(vendorRemote);
    await vendor.loadAll();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VendorOperationsView(
            controller: vendor,
            destination: const RoleDestination(
              id: 'catalog',
              label: 'Catalog',
              icon: Icons.inventory_2_outlined,
              capability: RoleCapability.vendorCatalog,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Catalog editor'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final rider = RiderOperationsController(
      _RiderRemote(),
      locationTracker: _RiderTracker(),
    );
    await rider.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RiderOperationsView(
            controller: rider,
            destination: const RoleDestination(
              id: 'duty',
              label: 'Duty',
              icon: Icons.toggle_on_outlined,
              capability: RoleCapability.riderDuty,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Location ready'), findsOneWidget);
    expect(tester.takeException(), isNull);
    vendor.dispose();
    rider.dispose();
  });

  testWidgets(
    'vendor onboarding UI completes private documents visit zones and bank',
    (tester) async {
      final remote = _VendorRemote();
      final controller = VendorOperationsController(remote);
      final provider = _VendorOnboardingProvider();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VendorOperationsView(
              controller: controller,
              onboardingProvider: provider,
              destination: const RoleDestination(
                id: 'profile',
                label: 'Profile',
                icon: Icons.person_outline,
                capability: RoleCapability.profile,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('vendor-business-name')),
        'Planext4u Local Services',
      );
      await tester.enterText(
        find.byKey(const ValueKey('vendor-business-type')),
        'Local services',
      );
      await tester.enterText(
        find.byKey(const ValueKey('vendor-contact-name')),
        'Business owner',
      );
      await tester.tap(find.byKey(const ValueKey('vendor-register')));
      await tester.pumpAndSettle();
      final verify = find.widgetWithText(TextButton, 'Verify');
      await tester.ensureVisible(verify);
      await tester.tap(verify);
      await tester.pumpAndSettle();

      final schedule = find.widgetWithText(TextButton, 'Schedule');
      await tester.ensureVisible(schedule);
      await tester.tap(schedule);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('vendor-visit-latitude')),
        '13.0827',
      );
      await tester.enterText(
        find.byKey(const ValueKey('vendor-visit-longitude')),
        '80.2707',
      );
      await tester.tap(find.byKey(const ValueKey('vendor-schedule-visit')));
      await tester.pumpAndSettle();

      final addZone = find.widgetWithText(TextButton, 'Add zone');
      await tester.ensureVisible(addZone);
      await tester.tap(addZone);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('vendor-zone-id')),
        'chennai-core',
      );
      await tester.enterText(
        find.byKey(const ValueKey('vendor-zone-postal-codes')),
        '600001, 600002',
      );
      await tester.enterText(
        find.byKey(const ValueKey('vendor-zone-latitude')),
        '13.0827',
      );
      await tester.enterText(
        find.byKey(const ValueKey('vendor-zone-longitude')),
        '80.2707',
      );
      await tester.tap(find.byKey(const ValueKey('vendor-save-zone')));
      await tester.pumpAndSettle();

      final addBank = find.widgetWithText(TextButton, 'Add bank');
      await tester.ensureVisible(addBank);
      await tester.tap(addBank);
      await tester.pumpAndSettle();

      expect(provider.documentCalls, 1);
      expect(provider.bankCalls, 1);
      expect(remote.lastVisit?.latitude, 13.0827);
      expect(controller.state.application?.documents, isNotEmpty);
      expect(controller.state.application?.zoneCount, 1);
      expect(controller.state.application?.bankStatus, 'PENDING_VERIFICATION');
    },
  );

  testWidgets('vendor onboarding supports full application correction', (
    tester,
  ) async {
    final remote = _VendorRemote()
      ..value = const VendorApplication(
        id: 'vendor-resubmit-001',
        revision: 4,
        status: 'REJECTED',
        businessName: 'Resubmit Services',
        businessType: 'Home services',
        contactName: 'Original owner',
        documents: [
          {'kind': 'OWNER_IDENTITY', 'ocr_status': 'REJECTED'},
        ],
        zoneCount: 0,
        bankStatus: 'NOT_CONFIGURED',
        verified: false,
        allowedActions: {'RESUBMIT_DOCUMENTS'},
      );
    final controller = VendorOperationsController(remote);
    final provider = _VendorOnboardingProvider();
    await controller.loadAll();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VendorOperationsView(
            controller: controller,
            onboardingProvider: provider,
            destination: const RoleDestination(
              id: 'profile',
              label: 'Profile',
              icon: Icons.person_outline,
              capability: RoleCapability.profile,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('vendor-rework-contact-name')),
      'Corrected owner',
    );
    final collect = find.byKey(
      const ValueKey('vendor-rework-collect-documents'),
    );
    await tester.ensureVisible(collect);
    await tester.tap(collect);
    await tester.pumpAndSettle();
    final resubmit = find.byKey(const ValueKey('vendor-rework-submit'));
    await tester.ensureVisible(resubmit);
    await tester.tap(resubmit);
    await tester.pumpAndSettle();
    expect(provider.documentCalls, 1);
    expect(controller.state.application?.status, 'DOCUMENTS_SUBMITTED');
    expect(controller.state.application?.contactName, 'Corrected owner');
  });

  testWidgets('onboarding provider absence is explicit and fail closed', (
    tester,
  ) async {
    final vendorRemote = _VendorRemote()
      ..value = const VendorApplication(
        id: 'vendor-provider-missing',
        revision: 1,
        status: 'REGISTERED',
        businessName: 'Provider Pending',
        documents: [],
        zoneCount: 0,
        bankStatus: 'NOT_CONFIGURED',
        verified: false,
        allowedActions: {'SUBMIT_DOCUMENTS'},
      );
    final vendor = VendorOperationsController(vendorRemote);
    await vendor.loadAll();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VendorOperationsView(
            controller: vendor,
            destination: const RoleDestination(
              id: 'profile',
              label: 'Profile',
              icon: Icons.person_outline,
              capability: RoleCapability.profile,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('vendor-document-provider-unavailable')),
      findsOneWidget,
    );

    final riderRemote = _RiderRemote()..firstTime = true;
    final rider = RiderOperationsController(riderRemote);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RiderOperationsView(
            controller: rider,
            destination: const RoleDestination(
              id: 'duty',
              label: 'Duty',
              icon: Icons.toggle_on_outlined,
              capability: RoleCapability.riderDuty,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('rider-register-provider-unavailable')),
      findsOneWidget,
    );
    final submit = tester.widget<FilledButton>(
      find.byKey(const ValueKey('rider-submit-registration')),
    );
    expect(submit.onPressed, isNull);
  });

  testWidgets(
    'rider document step works at large text while an unavailable bank blocks submission',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = RiderOperationsController(
        _RiderRemote()..firstTime = true,
      );
      final provider = _StagedRiderProvider();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: RiderOperationsView(
              controller: controller,
              onboardingProvider: provider,
              destination: const RoleDestination(
                id: 'duty',
                label: 'Duty',
                icon: Icons.toggle_on_outlined,
                capability: RoleCapability.riderDuty,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final collect = find.byKey(const ValueKey('rider-collect-documents'));
      await tester.ensureVisible(collect);
      await tester.pumpAndSettle();
      await tester.tap(collect);
      await tester.pumpAndSettle();
      expect(provider.collections, 1);
      expect(find.textContaining('4 private documents ready'), findsOneWidget);
      final submit = tester.widget<FilledButton>(
        find.byKey(const ValueKey('rider-submit-registration')),
      );
      expect(submit.onPressed, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(provider.discarded, hasLength(4));
      controller.dispose();
    },
  );

  testWidgets(
    'native duty privacy explains its current choice before enabling duty at large text',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final consents = ConsentController(_DeliveryConsents()..granted = false);
      final controller = RiderOperationsController(
        _RiderRemote(),
        deliveryPolicyLoader: () async => _deliveryPolicy,
      );
      controller.bindDeliveryConsents(consents);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: RiderOperationsView(
              controller: controller,
              destination: const RoleDestination(
                id: 'duty',
                label: 'Duty',
                icon: Icons.toggle_on_outlined,
                capability: RoleCapability.riderDuty,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('rider-duty-toggle')),
            )
            .onPressed,
        isNull,
      );
      final allow = find.text('Allow duty location');
      await tester.ensureVisible(allow);
      await tester.pumpAndSettle();
      await tester.tap(allow);
      await tester.pumpAndSettle();
      expect(controller.deliveryLocationAllowed, isTrue);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('rider-duty-toggle')),
            )
            .onPressed,
        isNotNull,
      );
      expect(find.text('Share live location while on task'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      consents.dispose();
    },
  );

  testWidgets(
    'normal rider form restores without restoring document or consent authority',
    (tester) async {
      final progress = _ProgressStore();
      Future<RiderOperationsController> open() async {
        final controller = RiderOperationsController(
          _RiderRemote()..firstTime = true,
        )..onboardingProgress = progress;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RiderOperationsView(
                key: UniqueKey(),
                controller: controller,
                onboardingProvider: _StagedRiderProvider(),
                destination: const RoleDestination(
                  id: 'duty',
                  label: 'Duty',
                  icon: Icons.toggle_on_outlined,
                  capability: RoleCapability.riderDuty,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return controller;
      }

      final first = await open();
      await tester.enterText(
        find.byKey(const ValueKey('rider-registration-name')),
        'Saved Rider',
      );
      await tester.enterText(
        find.byKey(const ValueKey('rider-registration-vehicle-number')),
        'TN01AB1234',
      );
      await tester.enterText(
        find.byKey(const ValueKey('rider-registration-zones')),
        '600001',
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      first.dispose();
      final second = await open();
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('rider-registration-name')),
            )
            .controller
            ?.text,
        'Saved Rider',
      );
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('rider-duty-location-consent')),
            )
            .value,
        isFalse,
      );
      expect(find.textContaining('saved form is restored'), findsOneWidget);
      final discard = find.byKey(
        const ValueKey('rider-discard-onboarding-progress'),
      );
      await tester.ensureVisible(discard);
      await tester.tap(discard);
      await tester.pumpAndSettle();
      expect(progress.value, isNull);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('rider-registration-name')),
            )
            .controller
            ?.text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      second.dispose();
    },
  );

  testWidgets('rider onboarding submits provider references and duty consent', (
    tester,
  ) async {
    final remote = _RiderRemote()..firstTime = true;
    final controller = RiderOperationsController(remote);
    final provider = _RiderOnboardingProvider();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RiderOperationsView(
            controller: controller,
            onboardingProvider: provider,
            destination: const RoleDestination(
              id: 'duty',
              label: 'Duty',
              icon: Icons.toggle_on_outlined,
              capability: RoleCapability.riderDuty,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('rider-registration-name')),
      'Verified Rider',
    );
    await tester.enterText(
      find.byKey(const ValueKey('rider-registration-vehicle-number')),
      'TN01AB1234',
    );
    await tester.enterText(
      find.byKey(const ValueKey('rider-registration-zones')),
      '600001,600002',
    );
    await tester.tap(find.byKey(const ValueKey('rider-duty-location-consent')));
    await tester.tap(find.byKey(const ValueKey('rider-submit-registration')));
    await tester.pumpAndSettle();

    expect(provider.calls, 1);
    expect(remote.registrationPayload?['full_name'], 'Verified Rider');
    expect(remote.registrationPayload?['bank_reference'], startsWith('bank-'));
    expect(remote.registrationPayload, isNot(contains('account_number')));
    expect(find.text('Verification in progress'), findsOneWidget);
  });

  for (final cleanupFails in [false, true]) {
    testWidgets(
      cleanupFails
          ? 'cleanup outage preserves acknowledged rider registration'
          : 'document progress cleanup follows replacement of the registration form',
      (tester) async {
        final remote = _RiderRemote()..firstTime = true;
        final controller = RiderOperationsController(remote);
        final provider = _RiderOnboardingProvider(
          retainsDocumentProgress: true,
          failCleanup: cleanupFails,
        );
        remote.onRegister = () {
          expect(provider.preparationCalls, 1);
          expect(provider.preparedIds, hasLength(4));
        };
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RiderOperationsView(
                controller: controller,
                onboardingProvider: provider,
                destination: const RoleDestination(
                  id: 'duty',
                  label: 'Duty',
                  icon: Icons.toggle_on_outlined,
                  capability: RoleCapability.riderDuty,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('rider-registration-name')),
          'Verified Rider',
        );
        await tester.enterText(
          find.byKey(const ValueKey('rider-registration-vehicle-number')),
          'TN01AB1234',
        );
        await tester.enterText(
          find.byKey(const ValueKey('rider-registration-zones')),
          '600001',
        );
        await tester.tap(
          find.byKey(const ValueKey('rider-duty-location-consent')),
        );
        await tester.tap(
          find.byKey(const ValueKey('rider-submit-registration')),
        );
        await tester.pumpAndSettle();
        expect(remote.registrationPayload, isNotNull);
        expect(provider.forgetCalls, 1);
        expect(provider.preparedIds, cleanupFails ? isNotEmpty : isEmpty);
        expect(find.text('Verification in progress'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('rider-submit-registration')),
          findsNothing,
        );
      },
    );
  }

  testWidgets(
    'late vendor documents cannot be submitted through a replacement account controller',
    (tester) async {
      VendorApplication application(String name) => VendorApplication(
        id: 'vendor-$name',
        revision: 1,
        status: 'REGISTERED',
        businessName: name,
        documents: const [],
        zoneCount: 0,
        bankStatus: 'NOT_CONFIGURED',
        verified: false,
        allowedActions: const {'SUBMIT_DOCUMENTS'},
      );
      final firstRemote = _VendorRemote()..value = application('First account');
      final secondRemote = _VendorRemote()
        ..value = application('Second account');
      final first = VendorOperationsController(firstRemote),
          second = VendorOperationsController(secondRemote);
      await first.loadAll();
      await second.loadAll();
      final provider = _VendorOnboardingProvider()
        ..documentGate = Completer<List<VendorOnboardingDocument>>();
      Widget view(VendorOperationsController controller) => MaterialApp(
        home: Scaffold(
          body: VendorOperationsView(
            controller: controller,
            onboardingProvider: provider,
            destination: const RoleDestination(
              id: 'profile',
              label: 'Profile',
              icon: Icons.person_outline,
              capability: RoleCapability.profile,
            ),
          ),
        ),
      );
      await tester.pumpWidget(view(first));
      await tester.pumpAndSettle();
      final verify = find.widgetWithText(TextButton, 'Verify');
      await tester.ensureVisible(verify);
      await tester.tap(verify);
      await tester.pump();
      expect(provider.documentCalls, 1);
      await tester.pumpWidget(view(second));
      await tester.pumpAndSettle();
      provider.documentGate!.complete(const [
        VendorOnboardingDocument(
          kind: 'OWNER_IDENTITY',
          assetId: 'asset-first-owner',
        ),
        VendorOnboardingDocument(
          kind: 'BUSINESS_REGISTRATION',
          assetId: 'asset-first-business',
        ),
      ]);
      await tester.pumpAndSettle();
      expect(firstRemote.revisions, isEmpty);
      expect(secondRemote.revisions, isEmpty);
      expect(second.state.application?.status, 'REGISTERED');
      expect(provider.discarded.map((value) => value.assetId), [
        'asset-first-owner',
        'asset-first-business',
      ]);
    },
  );

  testWidgets('rider assignments separate active work from history', (
    tester,
  ) async {
    final remote = _RiderRemote()
      ..taskValues = [
        RiderTask(
          id: 'delivery-history-001',
          revision: 5,
          orderId: 'order-history-001',
          orderType: 'FOOD',
          status: 'DELIVERED',
          pickupLabel: 'Local kitchen',
          dropoffLabel: 'Completed customer stop',
          distanceMeters: 3200,
          earning: const CatalogMoney(amountMinor: 6500, currency: 'INR'),
          offerExpiresAt: null,
          allowedActions: const {},
          podAssetId: 'asset-blurred-history-001',
        ),
      ];
    final controller = RiderOperationsController(remote);
    await controller.load();
    await controller.refreshTasks();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RiderOperationsView(
            controller: controller,
            destination: const RoleDestination(
              id: 'assignments',
              label: 'Tasks',
              icon: Icons.route_outlined,
              capability: RoleCapability.riderAssignments,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Delivery completed'), findsOneWidget);
    expect(find.textContaining('Completed customer stop'), findsOneWidget);
    expect(find.text('Safe chat'), findsNothing);
    controller.dispose();
  });

  testWidgets('rider route renders a privacy-safe in-app overview', (
    tester,
  ) async {
    final remote = _RiderRemote();
    final task = RiderTask(
      id: remote.taskValue.id,
      revision: remote.taskValue.revision,
      orderId: remote.taskValue.orderId,
      orderType: remote.taskValue.orderType,
      status: 'ACCEPTED',
      pickupLabel: remote.taskValue.pickupLabel,
      dropoffLabel: remote.taskValue.dropoffLabel,
      distanceMeters: remote.taskValue.distanceMeters,
      earning: remote.taskValue.earning,
      offerExpiresAt: null,
      allowedActions: const {'NAVIGATE_PICKUP'},
      podAssetId: '',
    );
    await tester.pumpWidget(MaterialApp(home: RiderNavigationView(task: task)));
    await tester.pumpAndSettle();

    expect(find.text('Route overview'), findsOneWidget);
    expect(find.text('Pickup'), findsOneWidget);
    expect(find.text('Drop-off'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Privacy-safe route map placeholder'), findsNothing);
  });

  testWidgets('rider emergency surface requires an active duty session', (
    tester,
  ) async {
    final controller = RiderOperationsController(_RiderRemote());
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RiderOperationsView(
            controller: controller,
            destination: const RoleDestination(
              id: 'emergency',
              label: 'Emergency',
              icon: Icons.emergency_outlined,
              capability: RoleCapability.riderEmergency,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Use local emergency services first'), findsOneWidget);
    expect(find.text('Start duty to use rider SOS'), findsOneWidget);
    expect(find.byKey(const ValueKey('create-rider-emergency')), findsNothing);
    controller.dispose();
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
      allowedHost: 'staging.planext4u.net',
      allowedScheme: 'planext4u-rider-staging',
      onDeepLink: opened.add,
    );
    await registration.start();
    messaging.tokens.add('rider-token-002');
    messaging.opened.add({
      'deep_link': 'https://attacker.example/rider/tasks/task-1',
    });
    messaging.opened.add({
      'deep_link': 'https://evilplanext4u.net/rider/tasks/task-1',
    });
    messaging.opened.add({
      'deep_link': 'planext4u-rider-staging-evil://open/rider/tasks/task-1',
    });
    messaging.opened.add({
      'deep_link': 'https://staging.planext4u.net/rider/tasks/task-1',
    });
    messaging.opened.add({
      'deep_link': 'planext4u-rider-staging://open/rider/tasks/task-2',
    });
    await Future<void>.delayed(Duration.zero);
    expect(remote.tokens, ['rider-token-001', 'rider-token-002']);
    expect(opened, hasLength(2));
    expect(opened.first.path, '/rider/tasks/task-1');
    expect(opened.last.path, '/rider/tasks/task-2');
    expect(registration.status, RolePushRegistrationStatus.registered);
    expect(
      isSafeRoleDeepLink(
        Uri.parse('https://planext4u.net/vendor/orders/order-1'),
        AppRole.rider,
      ),
      isFalse,
    );
    expect(
      isSafeRoleDeepLink(
        Uri.parse('planext4u-rider-staging://open/rider/tasks/task-1'),
        AppRole.rider,
        allowedHost: 'staging.planext4u.net',
        allowedScheme: 'planext4u-rider-staging',
      ),
      isTrue,
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

final class _VendorOnboardingProvider
    implements VendorOnboardingProvider, VendorDocumentCleanup {
  int documentCalls = 0;
  int bankCalls = 0;
  final discarded = <VendorOnboardingDocument>[];
  Completer<List<VendorOnboardingDocument>>? documentGate;

  @override
  Future<List<VendorOnboardingDocument>> collectDocuments() async {
    documentCalls += 1;
    if (documentGate != null) {
      return documentGate!.future;
    }
    return const [
      VendorOnboardingDocument(
        kind: 'BUSINESS_REGISTRATION',
        assetId: 'asset-vendor-business-provider-001',
      ),
      VendorOnboardingDocument(
        kind: 'OWNER_IDENTITY',
        assetId: 'asset-vendor-owner-provider-001',
      ),
    ];
  }

  @override
  Future<VendorOnboardingBankAccount> tokenizeBankAccount() async {
    bankCalls += 1;
    return const VendorOnboardingBankAccount(
      reference: 'bank-vendor-provider-token-001',
      holderName: 'Verified Vendor',
      last4: '1234',
      ifsc: 'HDFC0001234',
    );
  }

  @override
  Future<void> discardUnsubmittedDocuments(
    List<VendorOnboardingDocument> documents,
  ) async => discarded.addAll(documents);
}

final class _ProgressStore implements RiderOnboardingProgressStore {
  RiderOnboardingProgress? value;
  @override
  Future<RiderOnboardingProgress?> read() async => value;
  @override
  Future<void> save(RiderOnboardingProgress progress) async {
    value = progress;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

final class _StagedRiderProvider implements RiderDocumentOnboardingProvider {
  int collections = 0;
  final discarded = <RiderDocumentDraft>[];
  @override
  bool get canCollectDocuments => true;
  @override
  bool get canTokenizeBankAccount => false;
  @override
  Future<List<RiderDocumentDraft>> collectDocuments({
    required String vehicleType,
  }) async {
    ++collections;
    return [
      for (final kind in [
        'IDENTITY',
        'DRIVER_LICENSE',
        'VEHICLE_REGISTRATION',
        'INSURANCE',
      ])
        RiderDocumentDraft(kind: kind, assetId: 'asset-$kind'),
    ];
  }

  @override
  Future<void> discardUnsubmittedDocuments(
    List<RiderDocumentDraft> documents,
  ) async => discarded.addAll(documents);
  @override
  Future<String> tokenizeBankAccount() async => throw StateError('Unavailable');
  @override
  Future<RiderOnboardingEvidence> collectEvidence({
    required String vehicleType,
  }) async => throw StateError('Use staged documents');
}

final class _RiderOnboardingProvider
    implements RiderOnboardingProvider, RecoverableOnboardingDocuments {
  _RiderOnboardingProvider({
    this.retainsDocumentProgress = false,
    this.failCleanup = false,
  });
  int calls = 0;
  @override
  final bool retainsDocumentProgress;
  final bool failCleanup;
  int preparationCalls = 0, forgetCalls = 0;
  Set<String> preparedIds = {};
  @override
  Future<void> prepareDocumentSubmission(Set<String> assetIds) async {
    preparationCalls++;
    preparedIds = Set.unmodifiable(assetIds);
  }

  @override
  Future<void> forgetSubmittedDocuments(Set<String> assetIds) async {
    forgetCalls++;
    if (failCleanup) {
      throw StateError('Synthetic progress cleanup outage');
    }
    preparedIds = {};
  }

  @override
  Future<void> discardSavedDocuments() async {
    preparedIds = {};
  }

  @override
  Future<RiderOnboardingEvidence> collectEvidence({
    required String vehicleType,
  }) async {
    calls += 1;
    return const RiderOnboardingEvidence(
      documents: [
        RiderDocumentDraft(
          kind: 'IDENTITY',
          assetId: 'asset-rider-identity-provider-001',
        ),
        RiderDocumentDraft(
          kind: 'DRIVER_LICENSE',
          assetId: 'asset-rider-license-provider-001',
        ),
        RiderDocumentDraft(
          kind: 'VEHICLE_REGISTRATION',
          assetId: 'asset-rider-vehicle-provider-001',
        ),
        RiderDocumentDraft(
          kind: 'INSURANCE',
          assetId: 'asset-rider-insurance-provider-001',
        ),
      ],
      bankReference: 'bank-rider-provider-token-001',
    );
  }
}

final class _VendorRemote
    implements VendorOperationsRemote, VendorReworkRemote {
  VendorApplication? value;
  VendorFieldVisitDraft? lastVisit;
  final List<int> revisions = [];
  bool scheduleConflict = false;
  VendorCatalogItem? catalogItem;
  Map<String, Object?>? updatedCatalogPayload;
  final List<int> inventoryValues = [];
  final List<List<Map<String, Object?>>> scheduleValues = [];

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
    allowedActions: switch (status) {
      'REGISTERED' => const {'SUBMIT_DOCUMENTS'},
      'DOCUMENTS_SUBMITTED' => const {'SCHEDULE_FIELD_VISIT'},
      'FIELD_VISIT_PASSED' ||
      'BANK_REVIEW' => const {'SET_ZONES', 'SUBMIT_BANK'},
      _ => const <String>{},
    },
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
  Future<VendorApplication> resubmitApplication(
    int revision, {
    required String businessName,
    required String businessType,
    required String contactName,
    required List<Map<String, Object?>> documents,
  }) async {
    revisions.add(revision);
    return value = VendorApplication(
      id: value!.id,
      revision: revision + 1,
      status: 'DOCUMENTS_SUBMITTED',
      businessName: businessName,
      businessType: businessType,
      contactName: contactName,
      documents: documents,
      zoneCount: 0,
      bankStatus: 'NOT_CONFIGURED',
      verified: false,
      allowedActions: const {'SCHEDULE_FIELD_VISIT'},
    );
  }

  @override
  Future<VendorApplication> scheduleVisit(
    int revision,
    VendorFieldVisitDraft visit,
  ) async {
    revisions.add(revision);
    lastVisit = visit;
    return value = _next(
      status: 'FIELD_VISIT_PASSED',
      documents: value!.documents,
      zones: value!.zoneCount,
      bank: value!.bankStatus,
    );
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
  Future<VendorCatalogItem> createCatalog(Map<String, Object?> value) async =>
      catalogItem = VendorCatalogItem(
        id: 'catalog-draft-001',
        revision: 1,
        kind: value['kind']! as String,
        name: value['name']! as String,
        sku: 'S-001',
        price: CatalogMoney.fromJson(value['price']),
        stock: 0,
        approvalStatus: 'PENDING',
        active: false,
        schedules: const [],
        allowedActions: const {'EDIT', 'SET_INVENTORY', 'SET_SCHEDULE'},
      );

  @override
  Future<VendorCatalogItem> updateCatalog(
    VendorCatalogItem item,
    Map<String, Object?> value,
  ) async {
    updatedCatalogPayload = value;
    return catalogItem = _copyCatalog(
      item,
      revision: item.revision + 1,
      kind: value['kind']! as String,
      name: value['name']! as String,
      description: value['description']! as String,
      sku: value['sku']! as String,
      price: CatalogMoney.fromJson(value['price']),
    );
  }

  @override
  Future<VendorCatalogItem> setInventory(
    VendorCatalogItem item,
    int stock,
  ) async {
    inventoryValues.add(stock);
    return catalogItem = _copyCatalog(
      item,
      revision: item.revision + 1,
      stock: stock,
    );
  }

  @override
  Future<VendorCatalogItem> setSchedule(
    VendorCatalogItem item,
    List<Map<String, Object?>> schedules,
  ) async {
    if (scheduleConflict) {
      throw const ApiConflictFailure(
        code: 'REVISION_CONFLICT',
        message: 'Changed elsewhere.',
        correlationId: 'vendor-draft-conflict',
        retryable: false,
        statusCode: 409,
      );
    }
    scheduleValues.add(schedules);
    return catalogItem = _copyCatalog(
      item,
      revision: item.revision + 1,
      schedules: schedules,
    );
  }

  VendorCatalogItem _copyCatalog(
    VendorCatalogItem item, {
    required int revision,
    String? kind,
    String? name,
    String? description,
    String? sku,
    CatalogMoney? price,
    int? stock,
    List<Object?>? schedules,
  }) => VendorCatalogItem(
    id: item.id,
    revision: revision,
    kind: kind ?? item.kind,
    name: name ?? item.name,
    description: description ?? item.description,
    sku: sku ?? item.sku,
    price: price ?? item.price,
    stock: stock ?? item.stock,
    approvalStatus: item.approvalStatus,
    active: item.active,
    schedules: schedules ?? item.schedules,
    allowedActions: item.allowedActions,
    updatedAt: item.updatedAt,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      switch (invocation.memberName) {
        #dashboard => Future<Map<String, Object?>>.value(const {}),
        #catalog => Future<List<VendorCatalogItem>>.value([?catalogItem]),
        #work => Future<List<VendorWorkItem>>.value(const []),
        _ => super.noSuchMethod(invocation),
      };
}

final class _RiderRemote implements RiderOperationsRemote {
  VoidCallback? onRegister;
  bool failAccept = true;
  bool failLocation = false;
  bool firstTime = false;
  Map<String, Object?>? registrationPayload;
  final List<int> recoveredSequences = [];
  final List<RiderLocationCommand> locations = [];
  Completer<void>? locationGate;
  RiderDuty? activeDuty;
  var profileValue = const RiderProfile(
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
  List<RiderTask> taskValues = const [];

  @override
  Future<RiderProfile> profile() async {
    if (firstTime && registrationPayload == null) {
      throw StateError('not registered');
    }
    return profileValue;
  }

  @override
  Future<RiderProfile> register(Map<String, Object?> value) async {
    onRegister?.call();
    registrationPayload = value;
    return RiderProfile(
      id: 'rider-registration-001',
      revision: 1,
      status: 'KYC_REVIEW',
      fullName: value['full_name']! as String,
      vehicleNumber: value['vehicle_number']! as String,
      bankStatus: 'PENDING_VERIFICATION',
      zones: (value['zones']! as List<Object?>).cast<String>(),
      maxConcurrent: 1,
      allowedActions: const {},
    );
  }

  @override
  Future<RiderDuty> duty() async =>
      activeDuty ?? (throw StateError('off duty'));
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
  Future<List<RiderTask>> tasks() async => taskValues;
  @override
  Future<RiderTask> accept(RiderTask task) async {
    if (failAccept) {
      failAccept = false;
      throw const ApiTransportFailure(correlationId: 'offline-test');
    }
    return task;
  }

  @override
  Future<RiderTask> pickup(RiderTask task) async {
    if (failAccept) {
      failAccept = false;
      throw const ApiTransportFailure(correlationId: 'offline-pickup-test');
    }
    return task;
  }

  @override
  Future<List<Map<String, Object?>>> recover(
    List<RiderOfflineCommand> commands,
  ) async {
    recoveredSequences.addAll(commands.map((value) => value.deviceSequence));
    final old = profileValue;
    profileValue = RiderProfile(
      id: old.id,
      revision: old.revision,
      status: old.status,
      fullName: old.fullName,
      vehicleNumber: old.vehicleNumber,
      bankStatus: old.bankStatus,
      zones: old.zones,
      maxConcurrent: old.maxConcurrent,
      allowedActions: old.allowedActions,
      lastCommandSequence: commands.last.deviceSequence,
      lastLocationSequence: old.lastLocationSequence,
    );
    return [
      for (final command in commands)
        {'command_id': command.commandId, 'status': 'APPLIED'},
    ];
  }

  @override
  Future<void> updateLocation(RiderLocationCommand command) async {
    if (failLocation) {
      throw const ApiTransportFailure(correlationId: 'location-offline-test');
    }
    await locationGate?.future;
    locations.add(command);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _RiderTracker implements RiderLocationTracker {
  _RiderTracker({this.startError});

  final RiderLocationException? startError;
  Completer<void>? startGate;
  Future<void> Function(RiderTrackedPosition)? _onPosition;
  bool get started => _onPosition != null;
  bool appSettingsOpened = false;
  bool serviceSettingsOpened = false;

  @override
  Future<void> openAppSettings() async {
    appSettingsOpened = true;
  }

  @override
  Future<void> openServiceSettings() async {
    serviceSettingsOpened = true;
  }

  @override
  Future<void> start(
    Future<void> Function(RiderTrackedPosition position) onPosition, {
    void Function(Object error)? onError,
  }) async {
    if (startError != null) throw startError!;
    await startGate?.future;
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

const _deliveryPolicy = ConsentPolicy(
  purpose: 'LOCATION_DELIVERY',
  policyVersion: 'delivery-v1',
  required: true,
);

final class _DeliveryConsents implements ConsentRemote {
  bool granted = true;
  String version = 'delivery-v1';
  Completer<void>? hold;
  ConsentEvidence evidence() => ConsentEvidence(
    evidenceId: 'delivery-evidence',
    purpose: ConsentPurpose.locationDelivery,
    granted: granted,
    policyVersion: version,
    recordedAt: DateTime.now().toUtc(),
    version: 1,
  );
  @override
  Future<List<ConsentEvidence>> list() async => [evidence()];
  @override
  Future<ConsentEvidence> record({
    int? expectedVersion,
    required ConsentPurpose purpose,
    required bool granted,
    required String policyVersion,
  }) async {
    await hold?.future;
    this.granted = granted;
    version = policyVersion;
    return evidence();
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
