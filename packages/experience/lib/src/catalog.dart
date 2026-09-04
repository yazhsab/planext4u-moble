import 'package:flutter/foundation.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';

enum ProjectionStatus { fresh, stale, degraded }

final class CatalogMoney {
  const CatalogMoney({required this.amountMinor, required this.currency});

  factory CatalogMoney.fromJson(Object? value) {
    final json = _object(value, 'money');
    final amount = json['amount_minor'];
    final currency = json['currency'];
    if (amount is! int ||
        amount < 0 ||
        currency is! String ||
        currency.length != 3) {
      throw const FormatException('Money contract is invalid.');
    }
    return CatalogMoney(amountMinor: amount, currency: currency);
  }

  final int amountMinor;
  final String currency;

  String display() {
    final symbol = currency == 'INR' ? '₹' : '$currency ';
    return '$symbol${(amountMinor ~/ 100)}.${(amountMinor % 100).toString().padLeft(2, '0')}';
  }
}

final class CatalogResponsiveMediaVariant {
  const CatalogResponsiveMediaVariant({
    required this.url,
    required this.width,
    required this.height,
  });

  factory CatalogResponsiveMediaVariant.fromJson(Object? value) {
    final json = _object(value, 'responsive media variant');
    final url = _string(json, 'url');
    final width = _integer(json, 'width');
    final height = _integer(json, 'height');
    if (!_safePresentationUrl(url) ||
        width < 1 ||
        width > 16384 ||
        height < 1 ||
        height > 16384) {
      throw const FormatException('Responsive media variant is invalid.');
    }
    return CatalogResponsiveMediaVariant(
      url: url,
      width: width,
      height: height,
    );
  }

  final String url;
  final int width;
  final int height;
}

final class CatalogMediaPresentation {
  const CatalogMediaPresentation({
    required this.assetId,
    required this.url,
    required this.contentType,
    required this.width,
    required this.height,
    required this.altText,
    this.variants = const [],
    this.expiresAt,
  });

  factory CatalogMediaPresentation.fromJson(Object? value) {
    final json = _object(value, 'media presentation');
    final assetId = _string(json, 'asset_id');
    final url = _string(json, 'url');
    final contentType = _string(json, 'content_type');
    final width = _integer(json, 'width');
    final height = _integer(json, 'height');
    final altText = _string(json, 'alt_text').trim();
    final variants = _list(json, 'variants');
    final expiresAt = json['expires_at'] == null
        ? null
        : _instant(json, 'expires_at');
    if (assetId.length > 128 ||
        !_safePresentationUrl(url) ||
        !const {
          'image/jpeg',
          'image/png',
          'image/webp',
        }.contains(contentType) ||
        width < 1 ||
        width > 16384 ||
        height < 1 ||
        height > 16384 ||
        altText.length > 240 ||
        variants.length > 10) {
      throw const FormatException('Media presentation is invalid.');
    }
    return CatalogMediaPresentation(
      assetId: assetId,
      url: url,
      contentType: contentType,
      width: width,
      height: height,
      altText: altText,
      variants: List<CatalogResponsiveMediaVariant>.unmodifiable(
        variants.map(CatalogResponsiveMediaVariant.fromJson),
      ),
      expiresAt: expiresAt,
    );
  }

  final String assetId;
  final String url;
  final String contentType;
  final int width;
  final int height;
  final String altText;
  final List<CatalogResponsiveMediaVariant> variants;
  final DateTime? expiresAt;

  bool isExpiredAt(DateTime instant) =>
      expiresAt != null && !expiresAt!.isAfter(instant.toUtc());
}

final class CatalogCategory {
  const CatalogCategory({
    required this.id,
    required this.name,
    required this.priority,
    this.iconRef,
    this.icon,
  });

  factory CatalogCategory.fromJson(Object? value) {
    final json = _object(value, 'category');
    return CatalogCategory(
      id: _string(json, 'id'),
      name: _string(json, 'name'),
      priority: _integer(json, 'priority'),
      iconRef: json['icon_ref'] as String?,
      icon: json['icon'] == null
          ? null
          : CatalogMediaPresentation.fromJson(json['icon']),
    );
  }

  final String id;
  final String name;
  final int priority;
  final String? iconRef;
  final CatalogMediaPresentation? icon;
}

final class CatalogVariant {
  const CatalogVariant({
    required this.id,
    required this.label,
    required this.price,
    required this.available,
    required this.stockQuantity,
    required this.maxPerOrder,
    this.compareAtPrice,
  });

  factory CatalogVariant.fromJson(Object? value) {
    final json = _object(value, 'catalog variant');
    final stock = _integer(json, 'stock_quantity');
    final maximum = _integer(json, 'max_per_order');
    if (stock < 0 || maximum < 1 || maximum > 999) {
      throw const FormatException('Variant availability is invalid.');
    }
    return CatalogVariant(
      id: _string(json, 'id'),
      label: _string(json, 'label'),
      price: CatalogMoney.fromJson(json['price']),
      compareAtPrice: json['compare_at_price'] == null
          ? null
          : CatalogMoney.fromJson(json['compare_at_price']),
      available: _boolean(json, 'available'),
      stockQuantity: stock,
      maxPerOrder: maximum,
    );
  }

  final String id;
  final String label;
  final CatalogMoney price;
  final CatalogMoney? compareAtPrice;
  final bool available;
  final int stockQuantity;
  final int maxPerOrder;
}

final class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.summary,
    required this.price,
    required this.available,
    this.mediaRef,
    this.mediaRefs = const [],
    this.media = const [],
    this.sellerName,
    this.verifiedLocalSeller = false,
    this.description,
    this.specifications = const {},
    this.ratingAverage,
    this.reviewCount = 0,
    this.variants = const [],
    this.deliveryEstimate,
    this.reviews = const [],
    this.questions = const [],
    this.relatedItemIds = const [],
  });

  factory CatalogItem.fromJson(Object? value) {
    final json = _object(value, 'catalog item');
    return CatalogItem(
      id: _string(json, 'id'),
      categoryId: _string(json, 'category_id'),
      name: _string(json, 'name'),
      summary: _string(json, 'summary'),
      mediaRef: json['media_ref'] as String?,
      mediaRefs: List<String>.unmodifiable(
        (json['media_refs'] as List<Object?>? ?? const []).cast<String>(),
      ),
      media: List<CatalogMediaPresentation>.unmodifiable(
        (json['media'] as List<Object?>? ?? const []).map(
          CatalogMediaPresentation.fromJson,
        ),
      ),
      price: CatalogMoney.fromJson(json['price']),
      available: _boolean(json, 'available'),
      sellerName: json['seller_name'] as String?,
      verifiedLocalSeller: json['verified_local_seller'] as bool? ?? false,
      description: json['description'] as String?,
      specifications: _stringMap(json['specifications']),
      ratingAverage: _optionalNumber(json['rating_average']),
      reviewCount: json['review_count'] as int? ?? 0,
      variants: List<CatalogVariant>.unmodifiable(
        (json['variants'] as List<Object?>? ?? const []).map(
          CatalogVariant.fromJson,
        ),
      ),
      deliveryEstimate: json['delivery_estimate'] as String?,
      reviews: List<CatalogReview>.unmodifiable(
        (json['reviews'] as List<Object?>? ?? const []).map(
          CatalogReview.fromJson,
        ),
      ),
      questions: List<CatalogQuestion>.unmodifiable(
        (json['questions'] as List<Object?>? ?? const []).map(
          CatalogQuestion.fromJson,
        ),
      ),
      relatedItemIds: List<String>.unmodifiable(
        (json['related_item_ids'] as List<Object?>? ?? const []).cast<String>(),
      ),
    );
  }

  final String id;
  final String categoryId;
  final String name;
  final String summary;
  final String? mediaRef;
  final List<String> mediaRefs;
  final List<CatalogMediaPresentation> media;
  final CatalogMoney price;
  final bool available;
  final String? sellerName;
  final bool verifiedLocalSeller;
  final String? description;
  final Map<String, String> specifications;
  final double? ratingAverage;
  final int reviewCount;
  final List<CatalogVariant> variants;
  final String? deliveryEstimate;
  final List<CatalogReview> reviews;
  final List<CatalogQuestion> questions;
  final List<String> relatedItemIds;
}

final class CatalogReview {
  const CatalogReview({
    required this.id,
    required this.authorDisplayName,
    required this.score,
    required this.body,
    required this.verifiedPurchase,
    required this.createdAt,
  });

  factory CatalogReview.fromJson(Object? value) {
    final json = _object(value, 'catalog review');
    final score = _integer(json, 'score');
    if (score < 1 || score > 5) {
      throw const FormatException('Review score is invalid.');
    }
    return CatalogReview(
      id: _string(json, 'id'),
      authorDisplayName: _string(json, 'author_display_name'),
      score: score,
      body: _string(json, 'body'),
      verifiedPurchase: _boolean(json, 'verified_purchase'),
      createdAt: _instant(json, 'created_at'),
    );
  }

  final String id;
  final String authorDisplayName;
  final int score;
  final String body;
  final bool verifiedPurchase;
  final DateTime createdAt;
}

final class CatalogQuestion {
  const CatalogQuestion({
    required this.id,
    required this.question,
    required this.askedBy,
    required this.askedAt,
    this.answer,
    this.answeredBy,
    this.answeredAt,
  });

  factory CatalogQuestion.fromJson(Object? value) {
    final json = _object(value, 'catalog question');
    return CatalogQuestion(
      id: _string(json, 'id'),
      question: _string(json, 'question'),
      askedBy: _string(json, 'asked_by'),
      askedAt: _instant(json, 'asked_at'),
      answer: json['answer'] as String?,
      answeredBy: json['answered_by'] as String?,
      answeredAt: json['answered_at'] == null
          ? null
          : _instant(json, 'answered_at'),
    );
  }

  final String id;
  final String question;
  final String askedBy;
  final DateTime askedAt;
  final String? answer;
  final String? answeredBy;
  final DateTime? answeredAt;
}

final class CatalogPage<T> {
  const CatalogPage({
    required this.items,
    required this.hasMore,
    required this.projectionStatus,
    required this.generatedAt,
    this.nextCursor,
  });

  final List<T> items;
  final String? nextCursor;
  final bool hasMore;
  final ProjectionStatus projectionStatus;
  final DateTime generatedAt;
}

final class CatalogServiceTrustSummary {
  const CatalogServiceTrustSummary({
    required this.verifiedProvider,
    required this.ratingAverage,
    required this.completedBookings,
  });

  factory CatalogServiceTrustSummary.fromJson(Object? value) {
    final json = _object(value, 'service trust summary');
    final rating = json['rating_average'];
    final completed = _integer(json, 'completed_bookings');
    if (rating is! num || rating < 0 || rating > 5 || completed < 0) {
      throw const FormatException('Service trust summary is invalid.');
    }
    return CatalogServiceTrustSummary(
      verifiedProvider: _boolean(json, 'verified_provider'),
      ratingAverage: rating.toDouble(),
      completedBookings: completed,
    );
  }

  final bool verifiedProvider;
  final double ratingAverage;
  final int completedBookings;
}

final class CatalogServiceCollectionItem {
  const CatalogServiceCollectionItem({
    required this.serviceId,
    required this.providerId,
    required this.title,
    required this.summary,
    required this.price,
    required this.priceDisplay,
    required this.serviceable,
    required this.trust,
    required this.navigationTarget,
    this.media,
  });

  factory CatalogServiceCollectionItem.fromJson(Object? value) {
    final json = _object(value, 'service collection item');
    final serviceId = _string(json, 'service_id');
    final providerId = _string(json, 'provider_id');
    final title = _string(json, 'title').trim();
    final summary = _string(json, 'summary').trim();
    final priceDisplay = _string(json, 'price_display').trim();
    final navigationTarget = _string(json, 'navigation_target');
    if (!_safeCatalogIdentifier(serviceId) ||
        !_safeCatalogIdentifier(providerId) ||
        title.length > 120 ||
        summary.length > 500 ||
        priceDisplay.length > 80 ||
        navigationTarget != '/app/services/$serviceId') {
      throw const FormatException('Service collection item is invalid.');
    }
    return CatalogServiceCollectionItem(
      serviceId: serviceId,
      providerId: providerId,
      title: title,
      summary: summary,
      media: json['media'] == null
          ? null
          : CatalogMediaPresentation.fromJson(json['media']),
      price: CatalogMoney.fromJson(json['price']),
      priceDisplay: priceDisplay,
      serviceable: _boolean(json, 'serviceable'),
      trust: CatalogServiceTrustSummary.fromJson(json['trust']),
      navigationTarget: navigationTarget,
    );
  }

  final String serviceId;
  final String providerId;
  final String title;
  final String summary;
  final CatalogMediaPresentation? media;
  final CatalogMoney price;
  final String priceDisplay;
  final bool serviceable;
  final CatalogServiceTrustSummary trust;
  final String navigationTarget;
}

final class CatalogServiceCollection {
  const CatalogServiceCollection({
    required this.collectionId,
    required this.title,
    required this.items,
  });

  factory CatalogServiceCollection.fromJson(Object? value) {
    final json = _object(value, 'service collection');
    final collectionId = _string(json, 'collection_id');
    final title = _string(json, 'title').trim();
    final rawItems = _list(json, 'items');
    if (!_safeCatalogIdentifier(collectionId) ||
        title.length > 120 ||
        rawItems.isEmpty ||
        rawItems.length > 24) {
      throw const FormatException('Service collection is invalid.');
    }
    final items = rawItems
        .map(CatalogServiceCollectionItem.fromJson)
        .toList(growable: false);
    if (items.map((item) => item.serviceId).toSet().length != items.length) {
      throw const FormatException('Service collection IDs are duplicated.');
    }
    return CatalogServiceCollection(
      collectionId: collectionId,
      title: title,
      items: List.unmodifiable(items),
    );
  }

  final String collectionId;
  final String title;
  final List<CatalogServiceCollectionItem> items;
}

final class CustomerHomeProjection {
  const CustomerHomeProjection({
    required this.categories,
    required this.featuredItems,
    this.recommendations = const [],
    this.leaderboard = const [],
    this.helpShortcuts = const [],
    this.serviceCollections = const {},
    required this.projectionStatus,
    required this.generatedAt,
  });

  factory CustomerHomeProjection.fromJson(Object? value) {
    final json = _object(value, 'customer home');
    return CustomerHomeProjection(
      categories: List<CatalogCategory>.unmodifiable(
        _list(json, 'categories').map(CatalogCategory.fromJson),
      ),
      featuredItems: List<CatalogItem>.unmodifiable(
        _list(json, 'featured_items').map(CatalogItem.fromJson),
      ),
      recommendations: List<CatalogItem>.unmodifiable(
        (json['recommendations'] as List<Object?>? ?? const []).map(
          CatalogItem.fromJson,
        ),
      ),
      leaderboard: List<CatalogSellerLeader>.unmodifiable(
        (json['leaderboard'] as List<Object?>? ?? const []).map(
          CatalogSellerLeader.fromJson,
        ),
      ),
      helpShortcuts: List<CustomerHelpShortcut>.unmodifiable(
        (json['help_shortcuts'] as List<Object?>? ?? const []).map(
          CustomerHelpShortcut.fromJson,
        ),
      ),
      serviceCollections: _serviceCollections(json['service_collections']),
      projectionStatus: _projection(json['projection_status']),
      generatedAt: _instant(json, 'generated_at'),
    );
  }

  final List<CatalogCategory> categories;
  final List<CatalogItem> featuredItems;
  final List<CatalogItem> recommendations;
  final List<CatalogSellerLeader> leaderboard;
  final List<CustomerHelpShortcut> helpShortcuts;
  final Map<String, CatalogServiceCollection> serviceCollections;
  final ProjectionStatus projectionStatus;
  final DateTime generatedAt;
}

final class CatalogSellerLeader {
  const CatalogSellerLeader({
    required this.sellerName,
    required this.verified,
    required this.ratingAverage,
    required this.reviewCount,
  });

  factory CatalogSellerLeader.fromJson(Object? value) {
    final json = _object(value, 'seller leader');
    return CatalogSellerLeader(
      sellerName: _string(json, 'seller_name'),
      verified: _boolean(json, 'verified'),
      ratingAverage: _optionalNumber(json['rating_average']) ?? 0,
      reviewCount: _integer(json, 'review_count'),
    );
  }

  final String sellerName;
  final bool verified;
  final double ratingAverage;
  final int reviewCount;
}

final class CustomerHelpShortcut {
  const CustomerHelpShortcut({
    required this.id,
    required this.title,
    required this.route,
  });

  factory CustomerHelpShortcut.fromJson(Object? value) {
    final json = _object(value, 'help shortcut');
    final route = _string(json, 'route');
    if (!route.startsWith('/app/')) {
      throw const FormatException('Help route is invalid.');
    }
    return CustomerHelpShortcut(
      id: _string(json, 'id'),
      title: _string(json, 'title'),
      route: route,
    );
  }

  final String id;
  final String title;
  final String route;
}

enum DiscoverySuggestionType { trending, product, vendor, tag }

final class DiscoverySuggestion {
  const DiscoverySuggestion({
    required this.type,
    required this.id,
    required this.label,
    this.subtitle,
    this.itemId,
  });

  factory DiscoverySuggestion.fromJson(Object? value) {
    final json = _object(value, 'discovery suggestion');
    return DiscoverySuggestion(
      type: switch (_string(json, 'type')) {
        'TRENDING' => DiscoverySuggestionType.trending,
        'PRODUCT' => DiscoverySuggestionType.product,
        'VENDOR' => DiscoverySuggestionType.vendor,
        'TAG' => DiscoverySuggestionType.tag,
        _ => throw const FormatException('Suggestion type is invalid.'),
      },
      id: _string(json, 'id'),
      label: _string(json, 'label'),
      subtitle: json['subtitle'] as String?,
      itemId: json['item_id'] as String?,
    );
  }

  final DiscoverySuggestionType type;
  final String id;
  final String label;
  final String? subtitle;
  final String? itemId;
}

abstract interface class DiscoverySuggestionRemote {
  Future<List<DiscoverySuggestion>> suggestions(String query);
}

abstract interface class CatalogRemote {
  Future<CustomerHomeProjection> home();
  Future<CatalogPage<CatalogCategory>> categories();
  Future<CatalogPage<CatalogItem>> items({
    String? categoryId,
    String? cursor,
    int limit = 20,
  });
  Future<CatalogPage<CatalogItem>> search({
    required String query,
    String? categoryId,
    String? cursor,
    int limit = 20,
  });
  Future<CatalogItem> item(String id);
}

abstract interface class CatalogQuestionRemote {
  Future<CatalogQuestion> askQuestion({
    required String itemId,
    required String question,
  });
}

final class CatalogApi
    implements CatalogRemote, DiscoverySuggestionRemote, CatalogQuestionRemote {
  const CatalogApi(this._client, {String? Function()? postalCodeProvider})
    : _postalCodeProvider = postalCodeProvider;
  final ApiClient _client;
  final String? Function()? _postalCodeProvider;

  @override
  Future<CustomerHomeProjection> home() async {
    final postalCode = _postalCodeProvider?.call()?.trim();
    final safePostalCode =
        postalCode != null &&
            postalCode.length >= 3 &&
            postalCode.length <= 12 &&
            !RegExp(r'[\s\r\n]').hasMatch(postalCode)
        ? postalCode
        : null;
    return (await _client.send(
      ApiRequest.get(
        operation: 'catalog.get_customer_home',
        path: '/v1/home',
        query: {
          if (safePostalCode != null) 'postal_code': [safePostalCode],
        },
      ),
      CustomerHomeProjection.fromJson,
    )).value;
  }

  @override
  Future<CatalogPage<CatalogCategory>> categories() async =>
      (await _client.send(
        ApiRequest.get(
          operation: 'catalog.list_categories',
          path: '/v1/catalog/categories',
        ),
        (json) => _page(json, CatalogCategory.fromJson),
      )).value;

  @override
  Future<CatalogPage<CatalogItem>> items({
    String? categoryId,
    String? cursor,
    int limit = 20,
  }) async => (await _client.send(
    ApiRequest.get(
      operation: 'catalog.list_items',
      path: '/v1/catalog/items',
      query: {
        if (categoryId != null) 'category_id': [categoryId],
        if (cursor != null) 'cursor': [cursor],
        'limit': ['$limit'],
      },
    ),
    (json) => _page(json, CatalogItem.fromJson),
  )).value;

  @override
  Future<CatalogPage<CatalogItem>> search({
    required String query,
    String? categoryId,
    String? cursor,
    int limit = 20,
  }) async => (await _client.send(
    ApiRequest.get(
      operation: 'catalog.search',
      path: '/v1/catalog/search',
      query: {
        'q': [query],
        if (categoryId != null) 'category_id': [categoryId],
        if (cursor != null) 'cursor': [cursor],
        'limit': ['$limit'],
      },
    ),
    (json) => _page(json, CatalogItem.fromJson),
  )).value;

  @override
  Future<CatalogItem> item(String id) async => (await _client.send(
    ApiRequest.get(
      operation: 'catalog.get_item',
      path: '/v1/catalog/items/${Uri.encodeComponent(id)}',
    ),
    CatalogItem.fromJson,
  )).value;

  @override
  Future<CatalogQuestion> askQuestion({
    required String itemId,
    required String question,
  }) async => (await _client.send(
    ApiRequest.command(
      operation: 'catalog.ask_question',
      method: 'POST',
      path: '/v1/catalog/items/${Uri.encodeComponent(itemId)}/questions',
      body: {'question': question.trim()},
    ),
    CatalogQuestion.fromJson,
  )).value;

  @override
  Future<List<DiscoverySuggestion>> suggestions(String query) async =>
      (await _client.send(
        ApiRequest.get(
          operation: 'catalog.suggestions',
          path: '/v1/catalog/suggestions',
          query: {
            'q': [query.trim()],
          },
        ),
        (json) {
          final object = _object(json, 'suggestion page');
          return List<DiscoverySuggestion>.unmodifiable(
            _list(object, 'items').map(DiscoverySuggestion.fromJson),
          );
        },
      )).value;
}

CatalogPage<T> _page<T>(Object? value, T Function(Object?) decode) {
  final json = _object(value, 'catalog page');
  return CatalogPage(
    items: List<T>.unmodifiable(_list(json, 'items').map(decode)),
    nextCursor: json['next_cursor'] as String?,
    hasMore: _boolean(json, 'has_more'),
    projectionStatus: _projection(json['projection_status']),
    generatedAt: _instant(json, 'generated_at'),
  );
}

abstract interface class CustomerHomeCache {
  Future<CustomerHomeProjection?> read();
  Future<void> write(CustomerHomeProjection value);
}

final class MemoryCustomerHomeCache implements CustomerHomeCache {
  CustomerHomeProjection? value;
  @override
  Future<CustomerHomeProjection?> read() async => value;
  @override
  Future<void> write(CustomerHomeProjection value) async => this.value = value;
}

enum CatalogStatus { loading, ready, empty, offline, failure }

final class CatalogState {
  const CatalogState({required this.status, this.home});
  final CatalogStatus status;
  final CustomerHomeProjection? home;
}

final class CatalogController extends ChangeNotifier {
  CatalogController({
    required CatalogRemote remote,
    required CustomerHomeCache cache,
  }) : _remote = remote,
       _cache = cache;

  final CatalogRemote _remote;
  final CustomerHomeCache _cache;
  CatalogState _state = const CatalogState(status: CatalogStatus.loading);

  CatalogState get state => _state;

  Future<void> loadHome() async {
    _set(CatalogState(status: CatalogStatus.loading, home: _state.home));
    try {
      final home = await _remote.home();
      if (home.projectionStatus != ProjectionStatus.degraded) {
        await _cache.write(home);
      }
      _set(
        CatalogState(
          status:
              home.categories.isEmpty &&
                  home.featuredItems.isEmpty &&
                  home.serviceCollections.isEmpty
              ? CatalogStatus.empty
              : CatalogStatus.ready,
          home: home,
        ),
      );
    } on ApiTransportFailure {
      final cached = await _cache.read();
      _set(
        CatalogState(
          status: cached == null
              ? CatalogStatus.failure
              : CatalogStatus.offline,
          home: cached,
        ),
      );
    } catch (_) {
      _set(CatalogState(status: CatalogStatus.failure, home: _state.home));
    }
  }

  void _set(CatalogState next) {
    _state = next;
    notifyListeners();
  }
}

ProjectionStatus _projection(Object? value) => switch (value) {
  'FRESH' => ProjectionStatus.fresh,
  'STALE' => ProjectionStatus.stale,
  'DEGRADED' => ProjectionStatus.degraded,
  _ => throw const FormatException('Projection status is invalid.'),
};

Map<String, Object?> _object(Object? value, String label) {
  if (value is! Map<String, Object?>) {
    throw FormatException('$label must be an object.');
  }
  return value;
}

List<Object?> _list(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List<Object?>) throw FormatException('$key must be a list.');
  return value;
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return value;
}

int _integer(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('$key must be an integer.');
  return value;
}

bool _boolean(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('$key must be a boolean.');
  return value;
}

DateTime _instant(Map<String, Object?> json, String key) {
  final value = DateTime.tryParse(_string(json, key));
  if (value == null || !value.isUtc) {
    throw FormatException('$key must be a UTC date-time.');
  }
  return value;
}

Map<String, String> _stringMap(Object? value) {
  if (value == null) return const {};
  if (value is! Map<String, Object?>) {
    throw const FormatException('Specifications must be an object.');
  }
  final result = <String, String>{};
  for (final entry in value.entries) {
    if (entry.key.trim().isEmpty || entry.value is! String) {
      throw const FormatException('Specification values are invalid.');
    }
    result[entry.key] = entry.value! as String;
  }
  return Map<String, String>.unmodifiable(result);
}

double? _optionalNumber(Object? value) {
  if (value == null) return null;
  if (value is! num || value < 0 || value > 5) {
    throw const FormatException('Rating must be between zero and five.');
  }
  return value.toDouble();
}

bool _safePresentationUrl(String value) {
  final candidate = value.trim();
  if (candidate.startsWith('/') &&
      !candidate.startsWith('//') &&
      !candidate.contains('\\') &&
      !candidate.contains(RegExp(r'[\r\n]'))) {
    return true;
  }
  final uri = Uri.tryParse(candidate);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty;
}

bool _safeCatalogIdentifier(String value) {
  if (value.isEmpty || value.length > 128) return false;
  return value.codeUnits.every((value) => value >= 0x21 && value <= 0x7e);
}

Map<String, CatalogServiceCollection> _serviceCollections(Object? value) {
  final json = _object(value, 'service collections');
  final result = <String, CatalogServiceCollection>{};
  for (final entry in json.entries) {
    final collection = CatalogServiceCollection.fromJson(entry.value);
    if (entry.key != collection.collectionId || result.containsKey(entry.key)) {
      throw const FormatException('Service collection map key is invalid.');
    }
    result[entry.key] = collection;
  }
  return Map.unmodifiable(result);
}
