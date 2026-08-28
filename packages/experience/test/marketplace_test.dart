import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

void main() {
  test(
    'product detail contract decodes seller, ratings, specs and variants',
    () {
      final item = CatalogItem.fromJson(_itemJson());

      expect(item.sellerName, 'Anbu Naturals');
      expect(item.verifiedLocalSeller, isTrue);
      expect(item.ratingAverage, 4.8);
      expect(item.reviewCount, 126);
      expect(item.specifications['Extraction'], 'Cold pressed');
      expect(item.variants.map((value) => value.label), ['500 ml', '1 litre']);
      expect(
        item.variants.first.compareAtPrice?.display(),
        '\u20B9'
        '160.00',
      );
    },
  );

  test(
    'marketplace exposes deliberate results, empty and failure states',
    () async {
      final item = CatalogItem.fromJson(_itemJson());
      final remote = _MarketplaceRemote(item);
      final controller = MarketplaceController(remote: remote);

      await controller.discover();
      expect(controller.state.status, MarketplaceStatus.ready);
      expect(controller.state.results.single.name, item.name);
      expect(controller.state.categories.single.id, 'groceries');

      await controller.selectCategory('groceries');
      expect(controller.state.selectedCategoryId, 'groceries');
      expect(remote.lastCategoryId, 'groceries');

      remote.empty = true;
      await controller.discover('missing');
      expect(controller.state.status, MarketplaceStatus.empty);

      remote.fail = true;
      await controller.discover('network');
      expect(controller.state.status, MarketplaceStatus.failure);
    },
  );
}

Map<String, Object?> _itemJson() => {
  'id': 'item-sesame-oil',
  'category_id': 'groceries',
  'name': 'Cold-pressed sesame oil',
  'summary': 'Traditional wooden-pressed oil',
  'price': {'amount_minor': 13000, 'currency': 'INR'},
  'available': true,
  'seller_name': 'Anbu Naturals',
  'verified_local_seller': true,
  'description': 'Freshly pressed in small batches.',
  'specifications': {'Extraction': 'Cold pressed', 'Origin': 'Tamil Nadu'},
  'rating_average': 4.8,
  'review_count': 126,
  'variants': [
    {
      'id': 'variant-500ml',
      'label': '500 ml',
      'price': {'amount_minor': 13000, 'currency': 'INR'},
      'compare_at_price': {'amount_minor': 16000, 'currency': 'INR'},
      'available': true,
      'stock_quantity': 20,
      'max_per_order': 5,
    },
    {
      'id': 'variant-1l',
      'label': '1 litre',
      'price': {'amount_minor': 24500, 'currency': 'INR'},
      'available': true,
      'stock_quantity': 10,
      'max_per_order': 5,
    },
  ],
};

final class _MarketplaceRemote implements CatalogRemote {
  _MarketplaceRemote(this.value);

  final CatalogItem value;
  bool empty = false;
  bool fail = false;
  String? lastCategoryId;

  CatalogPage<CatalogItem> _page() {
    if (fail) throw StateError('offline');
    return CatalogPage(
      items: empty ? const [] : [value],
      hasMore: false,
      projectionStatus: ProjectionStatus.fresh,
      generatedAt: DateTime.utc(2026, 8, 27, 10),
    );
  }

  @override
  Future<CatalogPage<CatalogItem>> items({
    String? categoryId,
    String? cursor,
    int limit = 20,
  }) async {
    lastCategoryId = categoryId;
    return _page();
  }

  @override
  Future<CatalogPage<CatalogItem>> search({
    required String query,
    String? categoryId,
    String? cursor,
    int limit = 20,
  }) async {
    lastCategoryId = categoryId;
    return _page();
  }

  @override
  Future<CatalogItem> item(String id) async => value;

  @override
  Future<CatalogPage<CatalogCategory>> categories() async => CatalogPage(
    items: const [
      CatalogCategory(id: 'groceries', name: 'Groceries', priority: 10),
    ],
    hasMore: false,
    projectionStatus: ProjectionStatus.fresh,
    generatedAt: DateTime.utc(2026, 8, 27, 10),
  );

  @override
  Future<CustomerHomeProjection> home() => throw UnimplementedError();
}
