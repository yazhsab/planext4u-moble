import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

void main() {
  test('home contract decodes integer money and projection freshness', () {
    final home = CustomerHomeProjection.fromJson(homeJson());
    expect(home.categories.single.name, 'Daily needs');
    expect(home.featuredItems.single.price.display(), '₹65.00');
    expect(home.projectionStatus, ProjectionStatus.fresh);
  });

  test('controller exposes cached data as offline, not fresh', () async {
    final cached = CustomerHomeProjection.fromJson(homeJson());
    final controller = CatalogController(
      remote: OfflineCatalogRemote(),
      cache: MemoryCustomerHomeCache()..value = cached,
    );

    await controller.loadHome();

    expect(controller.state.status, CatalogStatus.offline);
    expect(controller.state.home, same(cached));
  });

  test(
    'degraded empty backend result becomes a deliberate empty state',
    () async {
      final controller = CatalogController(
        remote: FixedCatalogRemote(
          CustomerHomeProjection(
            categories: const [],
            featuredItems: const [],
            projectionStatus: ProjectionStatus.degraded,
            generatedAt: DateTime.utc(2026, 8, 27, 10),
          ),
        ),
        cache: MemoryCustomerHomeCache(),
      );
      await controller.loadHome();
      expect(controller.state.status, CatalogStatus.empty);
    },
  );

  test('deep links are restricted to safe customer routes and identifiers', () {
    expect(
      CustomerDeepLink.parse(Uri.parse('https://planext4u.net/app/home')),
      isA<CustomerHomeLink>(),
    );
    expect(
      CustomerDeepLink.parse(
        Uri.parse('planext4u-customer://open/app/catalog'),
      ),
      isA<CustomerCatalogLink>(),
    );
    final item = CustomerDeepLink.parse(
      Uri.parse('https://planext4u.net/app/catalog/items/item-1'),
    );
    expect((item! as CustomerItemLink).itemId, 'item-1');
    expect(
      CustomerDeepLink.parse(Uri.parse('https://planext4u.net/admin')),
      isNull,
    );
    expect(
      CustomerDeepLink.parse(
        Uri.parse('https://planext4u.net/app/catalog/items/%2Fescape'),
      ),
      isNull,
    );
  });
}

Map<String, Object?> homeJson() => {
  'categories': [
    {'id': 'daily-needs', 'name': 'Daily needs', 'priority': 10},
  ],
  'featured_items': [
    {
      'id': 'item-milk',
      'category_id': 'daily-needs',
      'name': 'Fresh milk',
      'summary': 'One litre',
      'price': {'amount_minor': 6500, 'currency': 'INR'},
      'available': true,
    },
  ],
  'projection_status': 'FRESH',
  'generated_at': '2026-08-27T10:00:00Z',
};

class FixedCatalogRemote implements CatalogRemote {
  FixedCatalogRemote(this.value);
  final CustomerHomeProjection value;

  @override
  Future<CustomerHomeProjection> home() async => value;
  @override
  Future<CatalogPage<CatalogCategory>> categories() =>
      throw UnimplementedError();
  @override
  Future<CatalogItem> item(String id) => throw UnimplementedError();
  @override
  Future<CatalogPage<CatalogItem>> items({
    String? categoryId,
    String? cursor,
    int limit = 20,
  }) => throw UnimplementedError();
  @override
  Future<CatalogPage<CatalogItem>> search({
    required String query,
    String? categoryId,
    String? cursor,
    int limit = 20,
  }) => throw UnimplementedError();
}

final class OfflineCatalogRemote extends FixedCatalogRemote {
  OfflineCatalogRemote()
    : super(
        CustomerHomeProjection(
          categories: const [],
          featuredItems: const [],
          projectionStatus: ProjectionStatus.degraded,
          generatedAt: DateTime.utc(2026, 8, 27, 10),
        ),
      );

  @override
  Future<CustomerHomeProjection> home() async =>
      throw const ApiTransportFailure(correlationId: 'corr-catalog-offline');
}
