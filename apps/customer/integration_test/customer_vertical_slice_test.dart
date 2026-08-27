import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:planext4u_config/planext4u_config.dart';
import 'package:planext4u_customer/main.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'MOB-E2E-001 fresh install consent login location home catalog read',
    (tester) async {
      final evidence = <String>[];
      final controller = CatalogController(
        remote: _SyntheticCatalogRemote(evidence),
        cache: MemoryCustomerHomeCache(),
      );
      await tester.pumpWidget(
        _FreshInstallJourney(controller: controller, evidence: evidence),
      );

      expect(find.text('Consent'), findsOneWidget);
      await tester.tap(find.text('Continue with required consent'));
      await tester.pumpAndSettle();
      expect(find.text('Secure sign in'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('email')),
        'synthetic.customer@example.test',
      );
      await tester.enterText(find.byKey(const ValueKey('secret')), 'synthetic');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Location'), findsOneWidget);

      await tester.tap(find.text('Use synthetic serviceable location'));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsWidgets);
      expect(find.text('Daily needs'), findsOneWidget);
      expect(find.text('Fresh milk'), findsOneWidget);
      expect(find.text('₹65.00'), findsOneWidget);
      expect(evidence, ['consent', 'login', 'location', 'home', 'catalog']);
    },
  );
}

enum _JourneyStage { consent, login, location, home }

final class _FreshInstallJourney extends StatefulWidget {
  const _FreshInstallJourney({
    required this.controller,
    required this.evidence,
  });

  final CatalogController controller;
  final List<String> evidence;

  @override
  State<_FreshInstallJourney> createState() => _FreshInstallJourneyState();
}

final class _FreshInstallJourneyState extends State<_FreshInstallJourney> {
  _JourneyStage stage = _JourneyStage.consent;

  void _advance(_JourneyStage next, String evidence) {
    widget.evidence.add(evidence);
    setState(() => stage = next);
  }

  @override
  Widget build(BuildContext context) => switch (stage) {
    _JourneyStage.consent => _Gate(
      title: 'Consent',
      action: 'Continue with required consent',
      onPressed: () => _advance(_JourneyStage.login, 'consent'),
    ),
    _JourneyStage.login => MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Secure sign in')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const TextField(key: ValueKey('email')),
              const TextField(key: ValueKey('secret'), obscureText: true),
              FilledButton(
                onPressed: () => _advance(_JourneyStage.location, 'login'),
                child: const Text('Sign in'),
              ),
            ],
          ),
        ),
      ),
    ),
    _JourneyStage.location => _Gate(
      title: 'Location',
      action: 'Use synthetic serviceable location',
      onPressed: () {
        widget.evidence.add('location');
        setState(() => stage = _JourneyStage.home);
      },
    ),
    _JourneyStage.home => CustomerApp(
      config: AppConfig.parse(
        rawEnvironment: 'development',
        rawApiBaseUrl: 'http://10.0.2.2:8080',
      ),
      catalogController: widget.controller,
    ),
  };
}

final class _Gate extends StatelessWidget {
  const _Gate({
    required this.title,
    required this.action,
    required this.onPressed,
  });

  final String title;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: FilledButton(onPressed: onPressed, child: Text(action)),
      ),
    ),
  );
}

final class _SyntheticCatalogRemote implements CatalogRemote {
  _SyntheticCatalogRemote(this.evidence);

  final List<String> evidence;
  final value = CustomerHomeProjection(
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
  Future<CustomerHomeProjection> home() async {
    evidence.addAll(['home', 'catalog']);
    return value;
  }

  @override
  Future<CatalogPage<CatalogCategory>> categories() async => CatalogPage(
    items: value.categories,
    hasMore: false,
    projectionStatus: ProjectionStatus.fresh,
    generatedAt: value.generatedAt,
  );

  @override
  Future<CatalogItem> item(String id) async => value.featuredItems.single;

  @override
  Future<CatalogPage<CatalogItem>> items({
    String? categoryId,
    String? cursor,
    int limit = 20,
  }) async => CatalogPage(
    items: value.featuredItems,
    hasMore: false,
    projectionStatus: ProjectionStatus.fresh,
    generatedAt: value.generatedAt,
  );

  @override
  Future<CatalogPage<CatalogItem>> search({
    required String query,
    String? cursor,
    int limit = 20,
  }) => items();
}
