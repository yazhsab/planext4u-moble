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

  testWidgets('catalog deep link opens the explore destination', (
    tester,
  ) async {
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
        initialUri: Uri.parse('https://dev.planext4u.net/app/catalog'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'This destination is enabled as its Phase 2 contract becomes available.',
      ),
      findsOneWidget,
    );
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
    String? cursor,
    int limit = 20,
  }) => items();
}
