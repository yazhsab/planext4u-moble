import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_config/planext4u_config.dart';
import 'package:planext4u_customer/main.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

void main() {
  testWidgets('renders customer home and navigation from catalog projection', (
    tester,
  ) async {
    final controller = CatalogController(
      remote: SyntheticCatalogRemote(),
      cache: MemoryCustomerHomeCache(),
    );
    await tester.pumpWidget(
      CustomerApp(
        config: AppConfig.parse(
          rawEnvironment: 'development',
          rawApiBaseUrl: 'http://localhost:8080',
        ),
        catalogController: controller,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Daily needs'), findsOneWidget);
    expect(find.text('Fresh milk'), findsOneWidget);
    expect(find.text('₹65.00'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('customer product grid fits a narrow Android viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      CustomerApp(
        config: AppConfig.parse(
          rawEnvironment: 'development',
          rawApiBaseUrl: 'http://localhost:8080',
        ),
        catalogController: CatalogController(
          remote: SyntheticCatalogRemote(),
          cache: MemoryCustomerHomeCache(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Available'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('catalog deep link opens the explore destination', (
    tester,
  ) async {
    final remote = SyntheticCatalogRemote();
    await tester.pumpWidget(
      CustomerApp(
        config: AppConfig.parse(
          rawEnvironment: 'development',
          rawApiBaseUrl: 'http://localhost:8080',
        ),
        catalogController: CatalogController(
          remote: remote,
          cache: MemoryCustomerHomeCache(),
        ),
        marketplaceController: MarketplaceController(remote: remote),
        cartController: CartController(remote: SyntheticCartRemote()),
        initialUri: Uri.parse('https://dev.planext4u.net/app/catalog'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Search local products and services'), findsOneWidget);
    expect(find.text('Fresh milk'), findsOneWidget);
  });

  testWidgets('product deep link renders the Phase 3 PDP on a narrow device', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final remote = SyntheticCatalogRemote();

    await tester.pumpWidget(
      CustomerApp(
        config: AppConfig.parse(
          rawEnvironment: 'development',
          rawApiBaseUrl: 'http://localhost:8080',
        ),
        catalogController: CatalogController(
          remote: remote,
          cache: MemoryCustomerHomeCache(),
        ),
        marketplaceController: MarketplaceController(remote: remote),
        cartController: CartController(remote: SyntheticCartRemote()),
        initialUri: Uri.parse(
          'https://dev.planext4u.net/app/catalog/items/item-milk',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Product details'), findsOneWidget);
    expect(find.text('Verified local seller'), findsOneWidget);
    expect(find.text('500 ml'), findsOneWidget);
    expect(find.text('Add to cart'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final class SyntheticCatalogRemote implements CatalogRemote {
  final homeValue = CustomerHomeProjection(
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
        sellerName: 'Kovai Fresh Foods',
        verifiedLocalSeller: true,
        description: 'Fresh local milk delivered chilled.',
        specifications: {'Origin': 'Coimbatore'},
        ratingAverage: 4.8,
        reviewCount: 126,
        variants: [
          CatalogVariant(
            id: 'variant-milk-500ml',
            label: '500 ml',
            price: CatalogMoney(amountMinor: 3500, currency: 'INR'),
            available: true,
            stockQuantity: 20,
            maxPerOrder: 5,
          ),
          CatalogVariant(
            id: 'variant-milk-1l',
            label: '1 litre',
            price: CatalogMoney(amountMinor: 6500, currency: 'INR'),
            available: true,
            stockQuantity: 10,
            maxPerOrder: 5,
          ),
        ],
      ),
    ],
    projectionStatus: ProjectionStatus.fresh,
    generatedAt: DateTime.utc(2026, 8, 27, 10),
  );

  @override
  Future<CustomerHomeProjection> home() async => homeValue;

  @override
  Future<CatalogPage<CatalogCategory>> categories() async => CatalogPage(
    items: homeValue.categories,
    hasMore: false,
    projectionStatus: ProjectionStatus.fresh,
    generatedAt: homeValue.generatedAt,
  );

  @override
  Future<CatalogItem> item(String id) async => homeValue.featuredItems.single;

  @override
  Future<CatalogPage<CatalogItem>> items({
    String? categoryId,
    String? cursor,
    int limit = 20,
  }) async => CatalogPage(
    items: homeValue.featuredItems,
    hasMore: false,
    projectionStatus: ProjectionStatus.fresh,
    generatedAt: homeValue.generatedAt,
  );

  @override
  Future<CatalogPage<CatalogItem>> search({
    required String query,
    String? categoryId,
    String? cursor,
    int limit = 20,
  }) => items();
}

final class SyntheticCartRemote implements CartRemote {
  CustomerCart get value => CustomerCart.fromJson({
    'id': 'cart-customer-1',
    'revision': 1,
    'items': const [],
    'subtotal': {'amount_minor': 0, 'currency': 'INR'},
    'discount': {'amount_minor': 0, 'currency': 'INR'},
    'tax': {'amount_minor': 0, 'currency': 'INR'},
    'fees': {'amount_minor': 0, 'currency': 'INR'},
    'total': {'amount_minor': 0, 'currency': 'INR'},
    'pricing_status': 'CURRENT',
    'allowed_actions': const [],
    'updated_at': '2026-08-27T10:00:00Z',
  });

  @override
  Future<CustomerCart> getCart() async => value;

  @override
  Future<CustomerCart> removeItem({
    required String variantId,
    required int expectedRevision,
    String? idempotencyKey,
  }) async => value;

  @override
  Future<CustomerCart> setItem({
    required String variantId,
    required int quantity,
    required int expectedRevision,
    String? idempotencyKey,
  }) async => value;
}
