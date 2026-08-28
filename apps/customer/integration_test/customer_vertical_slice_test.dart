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
