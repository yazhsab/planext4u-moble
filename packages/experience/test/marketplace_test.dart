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
      expect(item.reviews.single.verifiedPurchase, isTrue);
      expect(item.questions.single.answer, contains('everyday cooking'));
      expect(item.deliveryEstimate, contains('tomorrow'));
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

  test('marketplace appends cursor pages without duplicate products', () async {
    final remote = _MarketplaceRemote(CatalogItem.fromJson(_itemJson()))
      ..paginate = true;
    final controller = MarketplaceController(remote: remote);

    await controller.discover();
    expect(controller.state.hasMore, isTrue);
    await controller.loadMore();

    expect(controller.state.results.map((value) => value.id), [
      'item-sesame-oil',
      'item-sesame-oil-refill',
    ]);
    expect(controller.state.hasMore, isFalse);
  });

  test(
    'marketplace exposes backend suggestions and bounded recent searches',
    () async {
      final remote = _MarketplaceRemote(CatalogItem.fromJson(_itemJson()));
      final controller = MarketplaceController(remote: remote);
      await controller.suggest('sesame');
      expect(
        controller.state.suggestions.single.type,
        DiscoverySuggestionType.product,
      );
      await controller.discover('sesame');
      await controller.discover('oil');
      expect(controller.recentQueries, ['oil', 'sesame']);
      controller.clearRecentQueries();
      expect(controller.recentQueries, isEmpty);
    },
  );

  test(
    'marketplace sends customer questions through the catalog command',
    () async {
      final remote = _MarketplaceRemote(CatalogItem.fromJson(_itemJson()));
      final controller = MarketplaceController(remote: remote);

      await controller.askQuestion(
        'item-sesame-oil',
        'Is the bottle recyclable?',
      );

      expect(remote.askedItemId, 'item-sesame-oil');
      expect(remote.askedQuestion, 'Is the bottle recyclable?');
      expect(controller.state.selectedItem?.id, 'item-sesame-oil');
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
  'delivery_estimate': 'In stock • earliest delivery tomorrow',
  'reviews': [
    {
      'id': 'review-001',
      'author_display_name': 'Verified customer',
      'score': 5,
      'body': 'Fresh aroma and careful packaging.',
      'verified_purchase': true,
      'created_at': '2026-08-20T10:00:00Z',
    },
  ],
  'questions': [
    {
      'id': 'question-001',
      'question': 'Can I use this for cooking?',
      'asked_by': 'Local customer',
      'asked_at': '2026-08-19T10:00:00Z',
      'answer': 'Yes, it is suitable for everyday cooking.',
      'answered_by': 'Anbu Naturals',
      'answered_at': '2026-08-19T11:00:00Z',
    },
  ],
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

final class _MarketplaceRemote
    implements CatalogRemote, DiscoverySuggestionRemote, CatalogQuestionRemote {
  _MarketplaceRemote(this.value);

  final CatalogItem value;
  bool empty = false;
  bool fail = false;
  bool paginate = false;
  String? lastCategoryId;
  String? askedItemId;
  String? askedQuestion;

  CatalogPage<CatalogItem> _page([String? cursor]) {
    if (fail) throw StateError('offline');
    if (paginate && cursor != null) {
      final json = _itemJson()..['id'] = 'item-sesame-oil-refill';
      return CatalogPage(
        items: [CatalogItem.fromJson(json)],
        hasMore: false,
        projectionStatus: ProjectionStatus.fresh,
        generatedAt: DateTime.utc(2026, 8, 27, 10),
      );
    }
    return CatalogPage(
      items: empty ? const [] : [value],
      nextCursor: paginate ? 'cursor-next' : null,
      hasMore: paginate,
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
    return _page(cursor);
  }

  @override
  Future<CatalogPage<CatalogItem>> search({
    required String query,
    String? categoryId,
    String? cursor,
    int limit = 20,
  }) async {
    lastCategoryId = categoryId;
    return _page(cursor);
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

  @override
  Future<List<DiscoverySuggestion>> suggestions(String query) async => const [
    DiscoverySuggestion(
      type: DiscoverySuggestionType.product,
      id: 'product-item-sesame-oil',
      label: 'Cold-pressed sesame oil',
      itemId: 'item-sesame-oil',
    ),
  ];

  @override
  Future<CatalogQuestion> askQuestion({
    required String itemId,
    required String question,
  }) async {
    askedItemId = itemId;
    askedQuestion = question;
    return CatalogQuestion(
      id: 'question-new',
      question: question,
      askedBy: 'Planext4u customer',
      askedAt: DateTime.utc(2026, 8, 27, 10),
    );
  }
}
