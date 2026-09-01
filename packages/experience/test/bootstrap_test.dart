import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

void main() {
  test(
    'bootstrap decodes gates, defaults unknown flags off and orders shell data',
    () {
      final config = BootstrapConfig.fromJson(bootstrapJson());

      expect(config.revision, 7);
      expect(config.updateGate, UpdateGate.optional);
      expect(config.locale, 'ta');
      expect(config.flag('customer_home'), isTrue);
      expect(config.flag('not_published'), isFalse);
      expect(config.consentPolicies.single.policyVersion, 'privacy-2026-01');
      expect(config.homeSections.single.displayTitle, 'Local festival offers');
      expect(config.homeSections.single.actionRoute, '/app/catalog');
      expect(config.homeSections.single.items.single.icon, 'offers');
      expect(
        BootstrapConfig.fromJson(
          config.toJson(),
        ).homeSections.single.displaySubtitle,
        'Offers selected for your serviceable area.',
      );
    },
  );

  test(
    'controller uses cached configuration only as an explicit offline state',
    () async {
      final cached = BootstrapConfig.fromJson(bootstrapJson());
      final cache = MemoryBootstrapCache()..value = cached;
      final controller = BootstrapController(
        remote: FailingBootstrapRemote(),
        cache: cache,
        platform: MobilePlatform.android,
        appVersion: '1.0.0',
        locale: 'en',
      );

      await controller.load();

      expect(controller.state.status, BootstrapStatus.offline);
      expect(controller.state.config.revision, 7);
    },
  );

  test('customer home sections are filtered, ordered and deduplicated', () {
    const sections = [
      HomeSectionConfig(
        id: 'unknown',
        kind: 'NEW_SERVER_SECTION',
        titleKey: 'home.new',
        enabled: true,
        priority: 0,
      ),
      HomeSectionConfig(
        id: 'disabled-help',
        kind: 'HELP_SHORTCUTS',
        titleKey: 'home.help',
        enabled: false,
        priority: 1,
      ),
      HomeSectionConfig(
        id: 'category-primary',
        kind: 'CATEGORY_GRID',
        titleKey: 'home.categories',
        enabled: true,
        priority: 5,
      ),
      HomeSectionConfig(
        id: 'featured',
        kind: 'FEATURED_ITEMS',
        titleKey: 'home.featured',
        enabled: true,
        priority: 10,
      ),
      HomeSectionConfig(
        id: 'category-duplicate',
        kind: 'CATEGORY_GRID',
        titleKey: 'home.categories',
        enabled: true,
        priority: 20,
      ),
    ];

    final normalized = normalizeCustomerHomeSections(sections);

    expect(normalized.map((section) => section.id), [
      'category-primary',
      'featured',
    ]);
    expect(() => normalized.add(sections.first), throwsUnsupportedError);
  });

  test('home aliases deduplicate and service discovery routes remain safe', () {
    const sections = [
      HomeSectionConfig(
        id: 'bestsellers',
        kind: 'BESTSELLERS',
        titleKey: 'home.bestsellers',
        enabled: true,
        priority: 1,
      ),
      HomeSectionConfig(
        id: 'featured',
        kind: 'FEATURED_ITEMS',
        titleKey: 'home.featured',
        enabled: true,
        priority: 2,
      ),
      HomeSectionConfig(
        id: 'services',
        kind: 'SERVICE_DISCOVERY',
        titleKey: 'home.services',
        enabled: true,
        priority: 3,
        actionRoute: '/app/services',
        items: [
          HomeSectionItemConfig(
            id: 'food',
            title: 'Food',
            actionRoute: '/app/food',
          ),
        ],
      ),
    ];

    final normalized = normalizeCustomerHomeSections(sections);

    expect(normalized.map((section) => section.id), [
      'bestsellers',
      'services',
    ]);
    expect(
      supportedCustomerHomeRoutes,
      containsAll(['/app/services', '/app/food']),
    );
  });

  test('customer home content rejects routes outside the app allowlist', () {
    expect(
      () => BootstrapConfig.fromJson({
        ...bootstrapJson(),
        'home_sections': [
          {
            ...((bootstrapJson()['home_sections']! as List<Object?>).single
                as Map<String, Object?>),
            'action_route': 'https://untrusted.example/checkout',
          },
        ],
      }),
      throwsFormatException,
    );
  });

  test(
    'controller fails closed with safe defaults when no cache exists',
    () async {
      final controller = BootstrapController(
        remote: FailingBootstrapRemote(),
        cache: MemoryBootstrapCache(),
        platform: MobilePlatform.ios,
        appVersion: '1.0.0',
        locale: 'en',
      );

      await controller.load();

      expect(controller.state.status, BootstrapStatus.failure);
      expect(controller.state.config.flags, isEmpty);
      expect(controller.state.config.homeSections, isEmpty);
    },
  );

  testWidgets('required update and maintenance block application content', (
    tester,
  ) async {
    Future<void> render(BootstrapConfig config) => tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: Planext4uLocalizations.supportedLocales,
        localizationsDelegates: const [
          Planext4uLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: BootstrapGateView(
            state: BootstrapState(
              status: BootstrapStatus.ready,
              config: config,
            ),
            onRetry: () {},
            child: const Text('private-content'),
          ),
        ),
      ),
    );

    await render(
      BootstrapConfig.fromJson({...bootstrapJson(), 'update_gate': 'REQUIRED'}),
    );
    expect(find.text('Update required'), findsOneWidget);
    expect(find.text('private-content'), findsNothing);

    await render(
      BootstrapConfig.fromJson({
        ...bootstrapJson(),
        'update_gate': 'NONE',
        'maintenance': true,
        'maintenance_text': 'Synthetic planned maintenance',
      }),
    );
    expect(find.text('Synthetic planned maintenance'), findsOneWidget);
    expect(find.text('private-content'), findsNothing);
  });

  testWidgets('Tamil localization provides application copy', (tester) async {
    late Planext4uLocalizations strings;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ta'),
        supportedLocales: Planext4uLocalizations.supportedLocales,
        localizationsDelegates: const [
          Planext4uLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) {
            strings = Planext4uLocalizations.of(context);
            return Text(strings.homeTitle);
          },
        ),
      ),
    );
    expect(strings.homeTitle, 'முகப்பு');
    expect(find.text('முகப்பு'), findsOneWidget);
  });

  test('all nine supported locales contain safety and commerce copy', () {
    for (final locale in Planext4uLocalizations.supportedLocales) {
      final strings = Planext4uLocalizations(locale);
      expect(
        Planext4uLocalizations.hasCompleteTranslation(locale),
        isTrue,
        reason: '${locale.languageCode} is incomplete',
      );
      expect(strings.homeTitle, isNotEmpty);
      expect(strings.secureCheckout, isNotEmpty);
      expect(strings.cashOnDelivery, isNotEmpty);
      expect(strings.socioTitle, isNotEmpty);
      expect(strings.accountTitle, isNotEmpty);
      expect(strings.cartTitle, isNotEmpty);
      expect(strings.availablePoints(25), contains('25'));
    }
  });
}

Map<String, Object?> bootstrapJson() => {
  'revision': 7,
  'published_at': '2026-08-27T10:00:00Z',
  'update_gate': 'OPTIONAL',
  'latest_version': '1.2.0',
  'maintenance': false,
  'locale': 'ta',
  'supported_locales': ['en', 'ta'],
  'consent_policies': [
    {
      'purpose': 'LOCATION_SERVICEABILITY',
      'policy_version': 'privacy-2026-01',
      'required': true,
    },
  ],
  'flags': {'customer_home': true},
  'home_sections': [
    {
      'id': 'hero',
      'kind': 'HERO',
      'title_key': 'home.hero',
      'display_title': 'Local festival offers',
      'display_subtitle': 'Offers selected for your serviceable area.',
      'action_label': 'View offers',
      'action_route': '/app/catalog',
      'enabled': true,
      'priority': 10,
      'items': [
        {
          'id': 'festival-offers',
          'title': 'Festival offers',
          'subtitle': 'Limited-time local savings',
          'icon': 'offers',
          'action_route': '/app/catalog',
        },
      ],
    },
  ],
};

final class FailingBootstrapRemote implements BootstrapRemote {
  @override
  Future<BootstrapConfig> fetch({
    required MobilePlatform platform,
    required String appVersion,
    required String locale,
  }) async => throw StateError('offline');
}
