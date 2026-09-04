import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
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

  test('catalog decodes typed public media with accessibility metadata', () {
    final json = homeJson();
    final category =
        (json['categories']! as List<Object?>).single as Map<String, Object?>;
    category['icon'] = mediaPresentationJson(expiresAt: null);
    final item =
        (json['featured_items']! as List<Object?>).single
            as Map<String, Object?>;
    item['media'] = [mediaPresentationJson()];

    final home = CustomerHomeProjection.fromJson(json);
    expect(home.categories.single.icon?.altText, 'Synthetic milk bottle');
    expect(home.featuredItems.single.media.single.assetId, 'asset-milk');
    expect(home.featuredItems.single.media.single.variants.single.width, 480);
    expect(
      home.featuredItems.single.media.single.isExpiredAt(
        DateTime.utc(2026, 9, 2, 12),
      ),
      isFalse,
    );
    expect(
      home.featuredItems.single.media.single.isExpiredAt(
        DateTime.utc(2026, 9, 2, 12, 5),
      ),
      isTrue,
    );
  });

  test('catalog rejects unsafe media URLs and missing alt text', () {
    final unsafe = mediaPresentationJson(expiresAt: null)
      ..['url'] = 'javascript:alert(1)';
    expect(
      () => CatalogMediaPresentation.fromJson(unsafe),
      throwsFormatException,
    );
    final inaccessible = mediaPresentationJson(expiresAt: null)
      ..['alt_text'] = '';
    expect(
      () => CatalogMediaPresentation.fromJson(inaccessible),
      throwsFormatException,
    );
  });

  test(
    'home decodes CMS-keyed service collections without deriving authority',
    () {
      final home = CustomerHomeProjection.fromJson(homeJson());
      final collection = home.serviceCollections['popular-services']!;
      final service = collection.items.single;

      expect(collection.collectionId, 'popular-services');
      expect(service.serviceId, 'home-cleaning');
      expect(service.priceDisplay, 'From ₹499');
      expect(service.price.amountMinor, 49900);
      expect(service.serviceable, isTrue);
      expect(service.trust.verifiedProvider, isTrue);
      expect(service.navigationTarget, '/app/services/home-cleaning');
    },
  );

  test('home rejects mismatched collection keys and service navigation', () {
    final mismatched = homeJson();
    final collections =
        mismatched['service_collections']! as Map<String, Object?>;
    collections['different-id'] = collections.remove('popular-services');
    expect(
      () => CustomerHomeProjection.fromJson(mismatched),
      throwsFormatException,
    );

    final unsafeRoute = homeJson();
    final collection =
        ((unsafeRoute['service_collections']!
                as Map<String, Object?>)['popular-services']!
            as Map<String, Object?>);
    final item =
        (collection['items']! as List<Object?>).single as Map<String, Object?>;
    item['navigation_target'] = '/app/services/a-different-service';
    expect(
      () => CustomerHomeProjection.fromJson(unsafeRoute),
      throwsFormatException,
    );
  });

  test(
    'catalog home sends only a validated server serviceability postal code',
    () async {
      final transport = _CatalogTransport();
      final api = CatalogApi(
        ApiClient(
          baseUrl: Uri.parse('https://api.example.test'),
          transport: transport,
          authSession: const _StaticAuthSession(),
          correlationIdFactory: () => 'corr-catalog-home',
        ),
        postalCodeProvider: () => '600001',
      );

      await api.home();

      expect(transport.requests.single.url.path, '/v1/home');
      expect(
        transport.requests.single.url.queryParameters['postal_code'],
        '600001',
      );
    },
  );

  testWidgets('configured service rail renders backend display fields', (
    tester,
  ) async {
    final controller = CatalogController(
      remote: FixedCatalogRemote(CustomerHomeProjection.fromJson(homeJson())),
      cache: MemoryCustomerHomeCache(),
    );
    await controller.loadHome();
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: Planext4uLocalizations.supportedLocales,
        localizationsDelegates: Planext4uLocalizations.localizationsDelegates,
        home: CustomerHomeScreen(
          controller: controller,
          homeSections: const [
            HomeSectionConfig(
              id: 'services',
              kind: 'SERVICE_RAIL',
              titleKey: 'home.services',
              collectionId: 'popular-services',
              enabled: true,
              priority: 1,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Popular services'), findsOneWidget);
    expect(find.text('Home cleaning'), findsOneWidget);
    expect(find.text('From ₹499'), findsOneWidget);
    expect(find.text('4.8 ★ • 238 completed'), findsOneWidget);
  });

  testWidgets('configured service rail omits an unknown collection', (
    tester,
  ) async {
    final controller = CatalogController(
      remote: FixedCatalogRemote(CustomerHomeProjection.fromJson(homeJson())),
      cache: MemoryCustomerHomeCache(),
    );
    await controller.loadHome();
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: Planext4uLocalizations.supportedLocales,
        localizationsDelegates: Planext4uLocalizations.localizationsDelegates,
        home: CustomerHomeScreen(
          controller: controller,
          homeSections: const [
            HomeSectionConfig(
              id: 'unknown-services',
              kind: 'SERVICE_RAIL',
              titleKey: 'home.services',
              displayTitle: 'Invented services',
              collectionId: 'unknown-services',
              enabled: true,
              priority: 1,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Invented services'), findsNothing);
    expect(find.text('Home cleaning'), findsNothing);
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
  'recommendations': const [],
  'leaderboard': const [],
  'help_shortcuts': const [],
  'service_collections': {
    'popular-services': {
      'collection_id': 'popular-services',
      'title': 'Popular services',
      'items': [
        {
          'service_id': 'home-cleaning',
          'provider_id': 'provider-clean-001',
          'title': 'Home cleaning',
          'summary': 'Verified local home cleaning',
          'media': null,
          'price': {'amount_minor': 49900, 'currency': 'INR'},
          'price_display': 'From ₹499',
          'serviceable': true,
          'trust': {
            'verified_provider': true,
            'rating_average': 4.8,
            'completed_bookings': 238,
          },
          'navigation_target': '/app/services/home-cleaning',
        },
      ],
    },
  },
  'projection_status': 'FRESH',
  'generated_at': '2026-08-27T10:00:00Z',
};

Map<String, Object?> mediaPresentationJson({
  String? expiresAt = '2026-09-02T12:05:00Z',
}) => {
  'asset_id': 'asset-milk',
  'url': 'https://images.planext4u.net/synthetic-milk.webp',
  'content_type': 'image/webp',
  'width': 1200,
  'height': 900,
  'alt_text': 'Synthetic milk bottle',
  'variants': [
    {
      'url': 'https://images.planext4u.net/synthetic-milk-480.webp',
      'width': 480,
      'height': 360,
    },
  ],
  'expires_at': expiresAt,
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

final class _StaticAuthSession implements ApiAuthSession {
  const _StaticAuthSession();

  @override
  Future<String?> accessToken() async => 'catalog-access-token';

  @override
  Future<bool> refresh() async => false;
}

final class _CatalogTransport implements ApiTransport {
  final List<TransportRequest> requests = [];

  @override
  Future<TransportResponse> send(
    TransportRequest request, {
    required Duration timeout,
    required ApiCancellationToken cancellationToken,
  }) async {
    requests.add(request);
    return TransportResponse(
      statusCode: 200,
      headers: const {'Content-Type': 'application/json'},
      body: Uint8List.fromList(utf8.encode(jsonEncode(homeJson()))),
    );
  }
}
