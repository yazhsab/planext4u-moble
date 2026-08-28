import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_config/planext4u_config.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';
import 'package:planext4u_experience/planext4u_experience.dart';
import 'package:planext4u_storage/planext4u_storage.dart';

void main() {
  runApp(CustomerApp(config: AppConfig.fromCompileTime()));
}

class CustomerApp extends StatefulWidget {
  const CustomerApp({
    required this.config,
    this.catalogController,
    this.marketplaceController,
    this.cartController,
    this.transactionController,
    this.initialUri,
    super.key,
  });

  final AppConfig config;
  final CatalogController? catalogController;
  final MarketplaceController? marketplaceController;
  final CartController? cartController;
  final TransactionController? transactionController;
  final Uri? initialUri;

  @override
  State<CustomerApp> createState() => _CustomerAppState();
}

class _CustomerAppState extends State<CustomerApp> {
  late final _AuthenticatedSessionRequiredRemote _requiredRemote =
      _AuthenticatedSessionRequiredRemote();
  late final bool _ownsController = widget.catalogController == null;
  late final CatalogController _catalog =
      widget.catalogController ??
      CatalogController(
        remote: _requiredRemote,
        cache: MemoryCustomerHomeCache(),
      );
  late final bool _ownsMarketplace = widget.marketplaceController == null;
  late final MarketplaceController _marketplace =
      widget.marketplaceController ??
      MarketplaceController(remote: _requiredRemote);
  late final bool _ownsCart = widget.cartController == null;
  late final CartController _cart =
      widget.cartController ?? CartController(remote: _requiredRemote);
  late final bool _ownsTransactions = widget.transactionController == null;
  late final TransactionController _transactions =
      widget.transactionController ??
      TransactionController(
        remote: _requiredRemote,
        recoveryStore: _EncryptedPaymentRecoveryStore(),
      );

  @override
  void dispose() {
    if (_ownsController) _catalog.dispose();
    if (_ownsMarketplace) _marketplace.dispose();
    if (_ownsCart) _cart.dispose();
    if (_ownsTransactions) _transactions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final link = widget.initialUri == null
        ? null
        : CustomerDeepLink.parse(widget.initialUri!);
    final destination = link is CustomerCatalogLink || link is CustomerItemLink
        ? CustomerDestination.explore
        : link is CustomerOrderLink
        ? CustomerDestination.activity
        : CustomerDestination.home;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Planext4u Customer',
      theme: Planext4uTheme.light,
      darkTheme: Planext4uTheme.dark,
      themeMode: ThemeMode.system,
      supportedLocales: Planext4uLocalizations.supportedLocales,
      localizationsDelegates: const [
        Planext4uLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Semantics(
        label:
            'Planext4u ${widget.config.environmentLabel} customer application',
        child: CustomerHomeScreen(
          controller: _catalog,
          initialDestination: destination,
          initialItemId: link is CustomerItemLink ? link.itemId : null,
          marketplaceController: _marketplace,
          cartController: _cart,
          transactionController: _transactions,
        ),
      ),
    );
  }
}

final class _AuthenticatedSessionRequiredRemote
    implements CatalogRemote, CartRemote, TransactionRemote {
  Never _required() => throw const ApiAuthenticationFailure(
    code: 'AUTHENTICATION_REQUIRED',
    message: 'Sign in to continue.',
    correlationId: 'local-auth-boundary',
  );

  @override
  Future<CatalogPage<CatalogCategory>> categories() async => _required();

  @override
  Future<CustomerHomeProjection> home() async => _required();

  @override
  Future<CatalogItem> item(String id) async => _required();

  @override
  Future<CatalogPage<CatalogItem>> items({
    String? categoryId,
    String? cursor,
    int limit = 20,
  }) async => _required();

  @override
  Future<CatalogPage<CatalogItem>> search({
    required String query,
    String? categoryId,
    String? cursor,
    int limit = 20,
  }) async => _required();

  @override
  Future<CustomerCart> getCart() async => _required();

  @override
  Future<CustomerCart> removeItem({
    required String variantId,
    required int expectedRevision,
    String? idempotencyKey,
  }) async => _required();

  @override
  Future<CustomerCart> setItem({
    required String variantId,
    required int quantity,
    required int expectedRevision,
    String? idempotencyKey,
  }) async => _required();

  @override
  Future<List<CustomerAddress>> addresses() async => _required();
  @override
  Future<List<CustomerDeliverySlot>> deliverySlots() async => _required();
  @override
  Future<CheckoutQuote> quote({
    required int cartRevision,
    required String addressId,
    required String deliverySlotId,
    required String promotionCode,
    required int walletPoints,
    String? idempotencyKey,
  }) async => _required();
  @override
  Future<PlaceOrderResult> place({
    required String quoteId,
    required CustomerPaymentMethod method,
    String? idempotencyKey,
  }) async => _required();
  @override
  Future<CustomerPayment> payment(String id) async => _required();
  @override
  Future<List<CustomerOrder>> orders() async => _required();
  @override
  Future<CustomerOrder> order(String id) async => _required();
  @override
  Future<CustomerOrder> cancel({
    required CustomerOrder order,
    required String reason,
  }) async => _required();
  @override
  Future<CustomerOrder> confirmDelivery(CustomerOrder order) async =>
      _required();
  @override
  Future<CustomerOrder> requestReturn({
    required CustomerOrder order,
    required List<Map<String, Object?>> lines,
    required String reason,
  }) async => _required();
  @override
  Future<CustomerOrder> rate({
    required CustomerOrder order,
    required int score,
    required String comment,
  }) async => _required();
  @override
  Future<WalletAccount> wallet() async => _required();
}

final class _EncryptedPaymentRecoveryStore implements PaymentRecoveryStore {
  _EncryptedPaymentRecoveryStore()
    : _store = EncryptedRecordStore(
        records: FileBinaryRecordStore(namespace: 'customer-payment-recovery'),
        keyProvider: PlatformCacheKeyProvider(
          namespace: 'planext4u.payment.recovery.v1',
        ),
        namespace: 'customer-payment-recovery',
      );

  static const _key = 'pending.payment';
  final EncryptedRecordStore _store;

  @override
  Future<void> clear() => _store.delete(_key);

  @override
  Future<String?> read() async =>
      (await _store.get<String>(_key, (value) => value! as String)).value;

  @override
  Future<void> save(String paymentId) {
    final now = DateTime.now().toUtc();
    return _store.put(
      _key,
      paymentId,
      expiresAt: now.add(const Duration(days: 7)),
      staleUntil: now.add(const Duration(days: 7)),
    );
  }
}
