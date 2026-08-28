import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

void main() {
  testWidgets('checkout review fits a narrow viewport at 130% text', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final remote = _FixtureTransactionRemote();
    final cart = CustomerCart.fromJson(_fixture('commerce_cart.fixture.json'));
    await tester.pumpWidget(
      MaterialApp(
        home: CheckoutReviewScreen(
          cart: cart,
          controller: TransactionController(remote: remote),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Secure checkout'), findsOneWidget);
    expect(find.text('Delivery address'), findsOneWidget);
    expect(find.text('Order review'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Cash on delivery'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Cash on delivery'), findsOneWidget);
    expect(find.textContaining('₹147.85'), findsWidgets);
    expect(tester, meetsGuideline(androidTapTargetGuideline));
    expect(tester, meetsGuideline(labeledTapTargetGuideline));
    expect(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('activity exposes order lifecycle and reconciled points ledger', (
    tester,
  ) async {
    final controller = TransactionController(
      remote: _FixtureTransactionRemote(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CustomerActivityScreen(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('PLACED'), findsOneWidget);
    expect(find.text('₹147.85'), findsOneWidget);
    await tester.tap(find.text('Points'));
    await tester.pumpAndSettle();
    expect(find.text('24000'), findsOneWidget);
    expect(find.text('WELCOME REWARD'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('online payment invokes provider handoff and stays recoverable', (
    tester,
  ) async {
    final launcher = _RecordingPaymentLauncher();
    final remote = _FixtureTransactionRemote();
    final cart = CustomerCart.fromJson(_fixture('commerce_cart.fixture.json'));
    await tester.pumpWidget(
      MaterialApp(
        home: CheckoutReviewScreen(
          cart: cart,
          controller: TransactionController(remote: remote),
          paymentLauncher: launcher,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Place order'));
    await tester.pumpAndSettle();
    expect(launcher.payment?.id, remote.paymentValue.id);
    expect(find.text('Check payment status'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing provider setup fails safely without losing the order', (
    tester,
  ) async {
    final remote = _FixtureTransactionRemote();
    final cart = CustomerCart.fromJson(_fixture('commerce_cart.fixture.json'));
    await tester.pumpWidget(
      MaterialApp(
        home: CheckoutReviewScreen(
          cart: cart,
          controller: TransactionController(remote: remote),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Place order'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Payment setup is temporarily unavailable'),
      findsOneWidget,
    );
    expect(find.text('Check payment status'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

final class _RecordingPaymentLauncher implements PaymentProviderLauncher {
  CustomerPayment? payment;

  @override
  Future<void> launch(CustomerPayment payment) async {
    this.payment = payment;
  }
}

Object? _fixture(String name) => jsonDecode(
  File(
    '${_workspaceRoot().path}/packages/api_client/contracts/$name',
  ).readAsStringSync(),
);
Directory _workspaceRoot() {
  var directory = Directory.current.absolute;
  while (directory.parent.path != directory.path) {
    if (File(
      '${directory.path}/packages/api_client/contracts/transaction.openapi.json',
    ).existsSync()) {
      return directory;
    }
    directory = directory.parent;
  }
  throw StateError('Workspace not found.');
}

final class _FixtureTransactionRemote implements TransactionRemote {
  late final CheckoutQuote quoteValue = CheckoutQuote.fromJson(
    _fixture('checkout_quote.fixture.json'),
  );
  late final CustomerPayment paymentValue = CustomerPayment.fromJson(
    _fixture('payment.fixture.json'),
  );
  late final CustomerOrder orderValue = CustomerOrder.fromJson(
    _fixture('order.fixture.json'),
  );
  late final WalletAccount walletValue = WalletAccount.fromJson(
    _fixture('wallet.fixture.json'),
  );
  @override
  Future<List<CustomerAddress>> addresses() async => [quoteValue.address];
  @override
  Future<List<CustomerDeliverySlot>> deliverySlots() async => [
    quoteValue.delivery,
  ];
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
  Future<List<CustomerOrder>> orders() async => [orderValue];
  @override
  Future<CustomerOrder> order(String id) async => orderValue;
  @override
  Future<WalletAccount> wallet() async => walletValue;
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
