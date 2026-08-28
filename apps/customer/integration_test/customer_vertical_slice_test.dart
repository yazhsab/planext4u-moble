import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:planext4u_config/planext4u_config.dart';
import 'package:planext4u_customer/main.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'MOB-E2E-001 fresh install consent login location home catalog read',
    (tester) async {
      final evidence = <String>[];
      final controller = CatalogController(
        remote: _SyntheticCatalogRemote(evidence),
        cache: MemoryCustomerHomeCache(),
      );
      await tester.pumpWidget(
        _FreshInstallJourney(controller: controller, evidence: evidence),
      );

      expect(find.text('Consent'), findsOneWidget);
      await tester.tap(find.text('Continue with required consent'));
      await tester.pumpAndSettle();
      expect(find.text('Secure sign in'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('email')),
        'synthetic.customer@example.test',
      );
      await tester.enterText(find.byKey(const ValueKey('secret')), 'synthetic');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Location'), findsOneWidget);

      await tester.tap(find.text('Use synthetic serviceable location'));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsWidgets);
      expect(find.text('Daily needs'), findsOneWidget);
      expect(find.text('Fresh milk'), findsOneWidget);
      expect(find.text('₹65.00'), findsOneWidget);
      expect(evidence, ['consent', 'login', 'location', 'home', 'catalog']);
    },
  );

  testWidgets(
    'MOB-E2E-002 checkout maintains controlled success and places a COD order',
    (tester) async {
      final remote = _Phase3TransactionRemote();
      final loadController = TransactionController(remote: remote);
      await loadController.loadCheckout();
      var successes = 0;
      for (var index = 0; index < 100; index++) {
        final quoted = await loadController.createQuote(
          cartRevision: 1,
          addressId: remote.address.id,
          slotId: remote.slot.id,
        );
        final placed = quoted
            ? await loadController.place(CustomerPaymentMethod.cod)
            : null;
        if (placed?.order.status == 'PLACED') successes++;
      }
      expect(successes / 100, greaterThanOrEqualTo(0.97));

      final controller = TransactionController(remote: remote);
      await tester.pumpWidget(
        MaterialApp(
          home: CheckoutReviewScreen(cart: remote.cart, controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Secure checkout'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Cash on delivery'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Cash on delivery'), findsOneWidget);
      await tester.tap(find.textContaining('Place order'));
      await tester.pumpAndSettle();
      expect(controller.state.status, TransactionStatus.success);
      expect(controller.state.order?.status, 'PLACED');
    },
  );

  testWidgets('MOB-E2E-003 wallet ledger reconciles in customer activity', (
    tester,
  ) async {
    final remote = _Phase3TransactionRemote();
    expect(remote.walletValue.reconciles, isTrue);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerActivityScreen(
            controller: TransactionController(remote: remote),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Points'));
    await tester.pumpAndSettle();
    expect(find.text('24000'), findsOneWidget);
    expect(find.text('WELCOME REWARD'), findsOneWidget);
  });

  testWidgets(
    'MOB-E2E-004 service slot lock payment reschedule start and evidence',
    (tester) async {
      final remote = _Phase4ServiceRemote();
      final controller = ServiceBookingController(remote: remote);
      await controller.loadOfferings(postalCode: '600001');
      await controller.selectOffering(remote.offeringValue);
      expect(await controller.hold(remote.slotsValue.first), isNotNull);
      var booking = await controller.create(ServicePaymentMethod.wallet);
      expect(booking?.payment.status, 'CAPTURED');
      booking = await controller.reschedule(
        booking!,
        remote.slotsValue.last,
        'Customer schedule changed',
      );
      booking = await controller.providerTransition(booking!, 'ACCEPTED');
      booking = await controller.providerTransition(booking!, 'ARRIVED');
      booking = await controller.providerTransition(
        booking!,
        'START_OTP_REQUIRED',
      );
      expect(booking?.startOtp, '482613');
      booking = await controller.start(booking!, booking.startOtp!);
      booking = await controller.providerTransition(
        booking!,
        'COMPLETION_EVIDENCE_REQUIRED',
      );
      booking = await controller.complete(booking!, 'asset-evidence-004');

      await tester.pumpWidget(
        MaterialApp(
          home: ServiceBookingDetailScreen(
            controller: controller,
            initialBooking: booking!,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Completion evidence received'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('confirm-service-completion')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(
        find.byKey(const ValueKey('confirm-service-completion')),
      );
      await tester.pumpAndSettle();
      expect(controller.state.booking?.status, 'COMPLETED');
      expect(remote.evidence, [
        'slot_lock',
        'payment',
        'slot_lock',
        'reschedule',
        'ACCEPTED',
        'ARRIVED',
        'START_OTP_REQUIRED',
        'start',
        'COMPLETION_EVIDENCE_REQUIRED',
        'completion_evidence',
        'confirm_completion',
      ]);
    },
  );

  testWidgets(
    'MOB-E2E-005 food cart restaurant queue dispatch tracking and chat expiry',
    (tester) async {
      final remote = _Phase4FoodRemote();
      final controller = FoodController(remote: remote);
      await tester.pumpWidget(
        MaterialApp(home: CustomerFoodScreen(controller: controller)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Saravana Kitchen'), findsOneWidget);
      await tester.tap(find.text('Saravana Kitchen'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add one South Indian meals'));
      await tester.pump();
      final review = find.byKey(const ValueKey('review-food-cart'));
      expect(tester.widget<FilledButton>(review).onPressed, isNotNull);
      await tester.ensureVisible(review);
      await tester.tap(review);
      await tester.pumpAndSettle();
      expect(find.text('Server-confirmed total'), findsOneWidget);
      expect(find.text('₹434.50'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('place-food-order')));
      await tester.pumpAndSettle();
      expect(find.text('PENDING RESTAURANT'), findsWidgets);

      remote.advance('ACCEPTED');
      await controller.refreshActiveOrder();
      remote.advance('PREPARING');
      await controller.refreshActiveOrder();
      remote.advance('READY');
      await controller.refreshActiveOrder();
      remote.advance('RIDER_ASSIGNED');
      await controller.refreshActiveOrder();
      expect(controller.state.activeOrder?.status, 'RIDER_ASSIGNED');
      expect(remote.evidence, [
        'restaurants',
        'menu',
        'server_price',
        'payment_capture',
        'restaurant_ACCEPTED',
        'tracking',
        'restaurant_PREPARING',
        'tracking',
        'restaurant_READY',
        'tracking',
        'dispatch_RIDER_ASSIGNED',
        'tracking',
      ]);

      remote.advance('TIMED_OUT', refunded: true);
      await controller.refreshActiveOrder();
      await tester.pumpAndSettle();
      expect(find.text('Refund completed'), findsOneWidget);
      expect(remote.chatExpiresAfterDelivery, isTrue);
    },
  );
}

enum _JourneyStage { consent, login, location, home }

final class _FreshInstallJourney extends StatefulWidget {
  const _FreshInstallJourney({
    required this.controller,
    required this.evidence,
  });

  final CatalogController controller;
  final List<String> evidence;

  @override
  State<_FreshInstallJourney> createState() => _FreshInstallJourneyState();
}

final class _FreshInstallJourneyState extends State<_FreshInstallJourney> {
  _JourneyStage stage = _JourneyStage.consent;

  void _advance(_JourneyStage next, String evidence) {
    widget.evidence.add(evidence);
    setState(() => stage = next);
  }

  @override
  Widget build(BuildContext context) => switch (stage) {
    _JourneyStage.consent => _Gate(
      title: 'Consent',
      action: 'Continue with required consent',
      onPressed: () => _advance(_JourneyStage.login, 'consent'),
    ),
    _JourneyStage.login => MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Secure sign in')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const TextField(key: ValueKey('email')),
              const TextField(key: ValueKey('secret'), obscureText: true),
              FilledButton(
                onPressed: () => _advance(_JourneyStage.location, 'login'),
                child: const Text('Sign in'),
              ),
            ],
          ),
        ),
      ),
    ),
    _JourneyStage.location => _Gate(
      title: 'Location',
      action: 'Use synthetic serviceable location',
      onPressed: () {
        widget.evidence.add('location');
        setState(() => stage = _JourneyStage.home);
      },
    ),
    _JourneyStage.home => CustomerApp(
      config: AppConfig.parse(
        rawEnvironment: 'development',
        rawApiBaseUrl: 'http://10.0.2.2:8080',
      ),
      catalogController: widget.controller,
    ),
  };
}

final class _Gate extends StatelessWidget {
  const _Gate({
    required this.title,
    required this.action,
    required this.onPressed,
  });

  final String title;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: FilledButton(onPressed: onPressed, child: Text(action)),
      ),
    ),
  );
}

final class _SyntheticCatalogRemote implements CatalogRemote {
  _SyntheticCatalogRemote(this.evidence);

  final List<String> evidence;
  final value = CustomerHomeProjection(
    categories: const [
      CatalogCategory(id: 'daily-needs', name: 'Daily needs', priority: 10),
    ],
    featuredItems: const [
      CatalogItem(
        id: 'item-milk',
        categoryId: 'daily-needs',
        name: 'Fresh milk',
        summary: 'One litre',
        price: CatalogMoney(amountMinor: 6500, currency: 'INR'),
        available: true,
      ),
    ],
    projectionStatus: ProjectionStatus.fresh,
    generatedAt: DateTime.utc(2026, 8, 27, 10),
  );

  @override
  Future<CustomerHomeProjection> home() async {
    evidence.addAll(['home', 'catalog']);
    return value;
  }

  @override
  Future<CatalogPage<CatalogCategory>> categories() async => CatalogPage(
    items: value.categories,
    hasMore: false,
    projectionStatus: ProjectionStatus.fresh,
    generatedAt: value.generatedAt,
  );

  @override
  Future<CatalogItem> item(String id) async => value.featuredItems.single;

  @override
  Future<CatalogPage<CatalogItem>> items({
    String? categoryId,
    String? cursor,
    int limit = 20,
  }) async => CatalogPage(
    items: value.featuredItems,
    hasMore: false,
    projectionStatus: ProjectionStatus.fresh,
    generatedAt: value.generatedAt,
  );

  @override
  Future<CatalogPage<CatalogItem>> search({
    required String query,
    String? categoryId,
    String? cursor,
    int limit = 20,
  }) => items();
}

final class _Phase3TransactionRemote implements TransactionRemote {
  final address = const CustomerAddress(
    id: 'address-synthetic-001',
    label: 'Home',
    postalCode: '600001',
    locality: 'Chennai',
  );
  final slot = CustomerDeliverySlot(
    id: 'slot-synthetic-001',
    country: 'IN',
    windowStart: DateTime.utc(2026, 8, 28, 10),
    windowEnd: DateTime.utc(2026, 8, 28, 14),
    fee: const CatalogMoney(amountMinor: 3000, currency: 'INR'),
    capacity: 100,
  );
  late final cart = CustomerCart(
    id: 'cart-synthetic-001',
    revision: 1,
    items: const [
      CartLine(
        variantId: 'variant-milk-1l',
        itemId: 'item-milk',
        vendorId: 'vendor-dairy-001',
        itemName: 'Fresh milk',
        variantName: '1 litre',
        quantity: 1,
        unitPrice: CatalogMoney(amountMinor: 6500, currency: 'INR'),
        lineTotal: CatalogMoney(amountMinor: 6500, currency: 'INR'),
        available: true,
        priceChanged: false,
      ),
    ],
    subtotal: const CatalogMoney(amountMinor: 6500, currency: 'INR'),
    discount: const CatalogMoney(amountMinor: 0, currency: 'INR'),
    tax: const CatalogMoney(amountMinor: 325, currency: 'INR'),
    fees: const CatalogMoney(amountMinor: 3500, currency: 'INR'),
    total: const CatalogMoney(amountMinor: 10325, currency: 'INR'),
    pricingStatus: CartPricingStatus.current,
    allowedActions: const {'CHECKOUT'},
    updatedAt: DateTime.utc(2026, 8, 27, 10),
  );
  late final quoteValue = CheckoutQuote(
    id: 'quote-synthetic-001',
    cartRevision: 1,
    items: cart.items,
    address: address,
    delivery: slot,
    subtotal: cart.subtotal,
    discount: cart.discount,
    tax: cart.tax,
    fees: cart.fees,
    walletApplied: const CatalogMoney(amountMinor: 1000, currency: 'INR'),
    walletPointsRedeemed: 1000,
    total: const CatalogMoney(amountMinor: 9325, currency: 'INR'),
    promotionCode: '',
    pricingPolicyVersion: 'pricing-2026-01',
    paymentMethods: const [CustomerPaymentMethod.cod],
    warnings: const [],
    allowedActions: const {'PLACE_ORDER'},
    expiresAt: DateTime.utc(2026, 8, 27, 10, 10),
  );
  late final paymentValue = CustomerPayment(
    id: 'payment-synthetic-001',
    orderReference: 'order-synthetic-001',
    method: CustomerPaymentMethod.cod,
    status: 'CAPTURED',
    amount: quoteValue.total,
    allowedActions: const {},
    updatedAt: DateTime.utc(2026, 8, 27, 10, 1),
  );
  late final orderValue = CustomerOrder(
    id: 'order-synthetic-001',
    revision: 1,
    status: 'PLACED',
    total: quoteValue.total,
    paymentMethod: CustomerPaymentMethod.cod,
    lines: const [
      CustomerOrderLine(
        variantId: 'variant-synthetic-001',
        itemName: 'Local essentials',
        variantName: 'Standard',
        quantity: 1,
        lineTotal: CatalogMoney(amountMinor: 10000, currency: 'INR'),
      ),
    ],
    deliveryWindowStart: DateTime.utc(2026, 8, 28, 10),
    deliveryWindowEnd: DateTime.utc(2026, 8, 28, 14),
    allowedActions: const {'VIEW_TRACKING', 'REQUEST_CANCELLATION'},
    timeline: [
      OrderTimelineEvent(
        status: 'PLACED',
        actor: 'PLATFORM',
        createdAt: DateTime.utc(2026, 8, 27, 10, 1),
      ),
    ],
    createdAt: DateTime.utc(2026, 8, 27, 10, 1),
  );
  late final walletValue = WalletAccount(
    balance: 24000,
    entries: [
      WalletEntry(
        id: 'wallet-synthetic-001',
        type: 'CREDIT',
        category: 'WELCOME_REWARD',
        sourceReference: 'launch-synthetic-001',
        deltaPoints: 25000,
        balanceAfter: 25000,
        createdAt: DateTime.utc(2026, 8, 27, 10),
        originalExpiryAt: DateTime.utc(2027, 8, 27, 10),
      ),
      WalletEntry(
        id: 'wallet-synthetic-002',
        type: 'DEBIT',
        category: 'CHECKOUT_REDEMPTION',
        sourceReference: 'checkout-synthetic-001',
        deltaPoints: -1000,
        balanceAfter: 24000,
        createdAt: DateTime.utc(2026, 8, 27, 10, 1),
      ),
    ],
  );

  @override
  Future<List<CustomerAddress>> addresses() async => [address];
  @override
  Future<CustomerAddress> createAddress(
    CustomerAddressDraft value, {
    String? idempotencyKey,
  }) async => address;
  @override
  Future<CustomerAddress> updateAddress(
    CustomerAddress current,
    CustomerAddressDraft value, {
    String? idempotencyKey,
  }) async => current;
  @override
  Future<void> deleteAddress(
    CustomerAddress value, {
    String? idempotencyKey,
  }) async {}
  @override
  Future<List<CustomerDeliverySlot>> deliverySlots() async => [slot];
  @override
  Future<CheckoutQuote> quote({
    required int cartRevision,
    required String addressId,
    required String deliverySlotId,
    required String promotionCode,
    required int walletPoints,
    String? idempotencyKey,
  }) async => quoteValue;
  @override
  Future<PlaceOrderResult> place({
    required String quoteId,
    required CustomerPaymentMethod method,
    String? idempotencyKey,
  }) async => PlaceOrderResult(
    quote: quoteValue,
    payment: paymentValue,
    order: orderValue,
  );
  @override
  Future<CustomerPayment> payment(String id) async => paymentValue;
  @override
  Future<CustomerPayment> retryPayment(
    String id, {
    String? idempotencyKey,
  }) async => paymentValue;
  @override
  Future<List<CustomerOrder>> orders() async => [orderValue];
  @override
  Future<CustomerOrder> order(String id) async => orderValue;
  @override
  Future<WalletAccount> wallet() async => walletValue;
  @override
  Future<WalletExperience> walletExperience() async => WalletExperience(
    account: walletValue,
    referral: const ReferralProfile(
      code: 'P4UTEST001',
      shareUrl: 'https://planext4u.net/referral/P4UTEST001',
      senderPoints: 500,
      recipientPoints: 250,
      rewarded: false,
    ),
    refills: const [],
    campaigns: const [],
  );
  @override
  Future<ReferralProfile> applyReferral(String code) async => ReferralProfile(
    code: 'P4UTEST001',
    shareUrl: 'https://planext4u.net/referral/P4UTEST001',
    senderPoints: 500,
    recipientPoints: 250,
    pendingCode: code,
    rewarded: false,
  );
  @override
  Future<WalletRefillResult> createWalletRefill({
    required String offerId,
    required CustomerPaymentMethod method,
  }) async => throw UnimplementedError();
  @override
  Future<CustomerOrder> cancel({
    required CustomerOrder order,
    required String reason,
  }) async => order;
  @override
  Future<CustomerOrder> confirmDelivery(CustomerOrder order) async => order;
  @override
  Future<CustomerOrder> requestReturn({
    required CustomerOrder order,
    required List<Map<String, Object?>> lines,
    required String reason,
  }) async => order;
  @override
  Future<CustomerOrder> rate({
    required CustomerOrder order,
    required int score,
    required String comment,
  }) async => order;
}

final class _Phase4ServiceRemote implements ServiceBookingRemote {
  final evidence = <String>[];
  int _revision = 1;

  late final offeringValue = const ServiceOffering(
    id: 'service-home-cleaning',
    providerId: 'provider-synthetic-001',
    providerName: 'Synthetic Home Services',
    categoryId: 'home-cleaning',
    name: 'Home deep cleaning',
    summary: 'Verified synthetic cleaning service',
    durationMinutes: 120,
    price: CatalogMoney(amountMinor: 20000, currency: 'INR'),
    advance: CatalogMoney(amountMinor: 5000, currency: 'INR'),
    paymentMode: 'ADVANCE',
    verifiedProvider: true,
    ratingAverage: 4.8,
    completedBookings: 241,
    liveEngagements: 3,
    servicePostalCodes: ['600001'],
    cancellationPolicyRef: 'service-cancel-v1',
    reschedulePolicyRef: 'service-reschedule-v1',
    active: true,
  );
  late final slotsValue = [
    _slot('slot-synthetic-001', DateTime.utc(2026, 8, 29, 10), 1),
    _slot('slot-synthetic-002', DateTime.utc(2026, 8, 30, 10), 2),
  ];
  late ServiceBooking _booking = _newBooking(
    status: 'REQUESTED',
    slot: slotsValue.first,
    actions: const {'RESCHEDULE', 'CANCEL'},
  );

  ServiceSlot _slot(String id, DateTime startsAt, int version) => ServiceSlot(
    id: id,
    offeringId: offeringValue.id,
    providerId: offeringValue.providerId,
    startsAt: startsAt,
    endsAt: startsAt.add(const Duration(hours: 2)),
    timeZone: 'Asia/Kolkata',
    capacity: 2,
    remaining: 1,
    bufferMinutes: 30,
    price: offeringValue.price,
    advance: offeringValue.advance,
    allowedActions: const {'HOLD'},
    policyVersion: 'service-slot-v1',
    serviceDate: startsAt.toIso8601String().substring(0, 10),
    providerVersion: version,
  );

  ServiceBooking _newBooking({
    required String status,
    required ServiceSlot slot,
    required Set<String> actions,
    int rescheduleCount = 0,
    String? startOtp,
    ServiceCompletionEvidence? completionEvidence,
    List<ServiceBookingTimelineEvent> timeline = const [],
  }) {
    final now = DateTime.utc(2026, 8, 28, 10);
    return ServiceBooking(
      id: 'service-booking-synthetic-004',
      revision: _revision,
      status: status,
      offering: offeringValue,
      slot: slot,
      price: offeringValue.price,
      amountDue: offeringValue.advance,
      payment: CustomerPayment(
        id: 'payment-service-synthetic-004',
        orderReference: 'service-booking-synthetic-004',
        method: CustomerPaymentMethod.wallet,
        status: 'CAPTURED',
        amount: offeringValue.advance,
        allowedActions: const {'VIEW_RECEIPT'},
        updatedAt: now,
      ),
      startOtp: startOtp,
      completionEvidence: completionEvidence,
      rescheduleCount: rescheduleCount,
      freeReschedulesLeft: 1 - rescheduleCount,
      allowedActions: actions,
      timeline: timeline.isEmpty
          ? [
              ServiceBookingTimelineEvent(
                status: status,
                actor: 'CUSTOMER',
                createdAt: now,
              ),
            ]
          : timeline,
      createdAt: now,
      updatedAt: now,
    );
  }

  ServiceBooking _transition(
    String status, {
    Set<String> actions = const {},
    ServiceSlot? slot,
    int? rescheduleCount,
    String? startOtp,
    ServiceCompletionEvidence? completionEvidence,
  }) {
    _revision++;
    _booking = _newBooking(
      status: status,
      slot: slot ?? _booking.slot,
      actions: actions,
      rescheduleCount: rescheduleCount ?? _booking.rescheduleCount,
      startOtp: startOtp ?? _booking.startOtp,
      completionEvidence: completionEvidence ?? _booking.completionEvidence,
      timeline: [
        ..._booking.timeline,
        ServiceBookingTimelineEvent(
          status: status,
          actor: status == 'COMPLETED' ? 'CUSTOMER' : 'PROVIDER',
          createdAt: DateTime.utc(2026, 8, 28, 11),
        ),
      ],
    );
    return _booking;
  }

  @override
  Future<List<ServiceOffering>> offerings({
    required String postalCode,
    String? categoryId,
  }) async => [offeringValue];
  @override
  Future<ServiceOffering> offering(
    String id, {
    required String postalCode,
  }) async => offeringValue;
  @override
  Future<List<ServiceSlot>> slots(
    String offeringId, {
    DateTime? from,
    DateTime? to,
  }) async => slotsValue;
  @override
  Future<ServiceSlotHold> hold({
    required String slotId,
    required String postalCode,
  }) async {
    evidence.add('slot_lock');
    return ServiceSlotHold(
      id: 'hold-$slotId',
      slotId: slotId,
      offeringId: offeringValue.id,
      status: 'HELD',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
      createdAt: DateTime.now().toUtc(),
      allowedActions: const {'RELEASE', 'CREATE_BOOKING'},
    );
  }

  @override
  Future<void> releaseHold(String id) async {}
  @override
  Future<List<ServiceBooking>> bookings() async => [_booking];
  @override
  Future<ServiceBooking> booking(String id) async => _booking;
  @override
  Future<ServiceBooking> create({
    required String holdId,
    required ServicePaymentMethod paymentMethod,
  }) async {
    evidence.add('payment');
    return _booking;
  }

  @override
  Future<ServiceBooking> confirmPayment(ServiceBooking booking) async =>
      _booking;
  @override
  Future<ServiceBooking> reschedule({
    required ServiceBooking booking,
    required String holdId,
    required String reason,
  }) async {
    evidence.add('reschedule');
    return _transition(
      'REQUESTED',
      actions: const {'CANCEL'},
      slot: slotsValue.last,
      rescheduleCount: 1,
    );
  }

  @override
  Future<ServiceBooking> cancel({
    required ServiceBooking booking,
    required String reason,
  }) async => _transition('CANCELLED');
  @override
  Future<ServiceBooking> providerTransition({
    required ServiceBooking booking,
    required String status,
    String reason = '',
  }) async {
    evidence.add(status);
    return _transition(
      status,
      actions: status == 'COMPLETED_PENDING_CONFIRMATION'
          ? const {'CONFIRM_COMPLETION', 'DISPUTE'}
          : const {},
      startOtp: status == 'START_OTP_REQUIRED' ? '482613' : booking.startOtp,
    );
  }

  @override
  Future<ServiceBooking> start({
    required ServiceBooking booking,
    required String otp,
  }) async {
    evidence.add('start');
    return _transition('IN_PROGRESS');
  }

  @override
  Future<ServiceBooking> complete({
    required ServiceBooking booking,
    required String photoAssetId,
  }) async {
    evidence.add('completion_evidence');
    return _transition(
      'COMPLETED_PENDING_CONFIRMATION',
      actions: const {'CONFIRM_COMPLETION', 'DISPUTE'},
      completionEvidence: ServiceCompletionEvidence(
        photoAssetId: photoAssetId,
        capturedAt: DateTime.utc(2026, 8, 28, 11),
        submittedBy: offeringValue.providerId,
      ),
    );
  }

  @override
  Future<ServiceBooking> confirmCompletion(ServiceBooking booking) async {
    evidence.add('confirm_completion');
    return _transition('COMPLETED');
  }

  @override
  Future<ServiceBooking> noShow({
    required ServiceBooking booking,
    required String reason,
  }) async => _transition('CUSTOMER_NO_SHOW');
  @override
  Future<ServiceBooking> dispute({
    required ServiceBooking booking,
    required String reason,
  }) async => _transition('DISPUTED');
}

final class _Phase4FoodRemote implements FoodRemote {
  final evidence = <String>[];
  bool chatExpiresAfterDelivery = true;
  String _status = 'PENDING_RESTAURANT';
  bool _refunded = false;
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

  void advance(String status, {bool refunded = false}) {
    _status = status;
    _refunded = refunded;
    evidence.add(
      status == 'RIDER_ASSIGNED'
          ? 'dispatch_$status'
          : status == 'TIMED_OUT'
          ? 'timeout_refund'
          : 'restaurant_$status',
    );
  }

  FoodOrder get _order => FoodOrder(
    id: 'food-order-e2e-005',
    revision: evidence.length,
    restaurantId: restaurant.id,
    status: _status,
    total: const CatalogMoney(amountMinor: 43450, currency: 'INR'),
    paymentStatus: _refunded ? 'REFUNDED' : 'CAPTURED',
    refundState: _refunded ? 'REFUNDED' : '',
    pricingVersion: 'food-pricing-v1',
    acceptBy: DateTime.now().toUtc().add(const Duration(minutes: 3)),
    allowedActions: const {},
    timeline: [
      {
        'status': _status,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
    ],
  );

  @override
  Future<List<FoodRestaurant>> restaurants(String postalCode) async {
    evidence.add('restaurants');
    return [restaurant];
  }

  @override
  Future<List<FoodMenuItem>> menu(String restaurantId) async {
    evidence.add('menu');
    return const [
      FoodMenuItem(
        id: 'menu-meals-001',
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
            minimum: 0,
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
      ),
    ];
  }

  @override
  Future<FoodCart> priceCart({
    required String restaurantId,
    required String postalCode,
    required List<FoodCartLineRequest> lines,
  }) async {
    evidence.add('server_price');
    return FoodCart(
      id: 'food-cart-e2e-005',
      revision: 1,
      restaurant: restaurant,
      lines: const [
        {'menu_item_id': 'menu-meals-001', 'quantity': 1},
      ],
      subtotal: const CatalogMoney(amountMinor: 39000, currency: 'INR'),
      deliveryFee: const CatalogMoney(amountMinor: 2500, currency: 'INR'),
      tax: const CatalogMoney(amountMinor: 1950, currency: 'INR'),
      total: const CatalogMoney(amountMinor: 43450, currency: 'INR'),
      pricingVersion: 'food-pricing-v1',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
    );
  }

  @override
  Future<FoodOrder> placeOrder(String cartId, String paymentMethod) async {
    evidence.add('payment_capture');
    return _order;
  }

  @override
  Future<FoodOrder> order(String id) async {
    evidence.add('tracking');
    return _order;
  }

  @override
  Future<List<FoodOrder>> orders() async => [_order];
}
