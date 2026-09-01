import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_core/planext4u_core.dart';
import 'package:planext4u_design_system/planext4u_design_system.dart';

void main() {
  test('themes retain approved brand and semantic colours', () {
    expect(Planext4uTheme.light.colorScheme.primary, Planext4uColors.teal);
    expect(Planext4uTheme.light.colorScheme.onPrimary, Planext4uColors.navy);
    expect(Planext4uTheme.light.colorScheme.error, Planext4uColors.danger);
    expect(Planext4uTheme.dark.brightness, Brightness.dark);
    expect(
      Planext4uTheme.light.textTheme.headlineMedium?.fontFamily,
      Planext4uTypography.displayFamily,
    );
    expect(
      Planext4uTheme.light.textTheme.bodyMedium?.fontFamily,
      Planext4uTypography.bodyFamily,
    );
    expect(
      Planext4uTheme.light.textTheme.bodyMedium?.fontFamilyFallback,
      contains(Planext4uTypography.tamilFallbackFamily),
    );
    expect(
      Planext4uTextStyles.identifier.fontFamily,
      Planext4uTypography.identifierFamily,
    );
  });

  test('generated foundations preserve the approved scale', () {
    expect(Planext4uSpacing.x4, 16);
    expect(Planext4uRadii.control, 12);
    expect(Planext4uRadii.card, 16);
    expect(Planext4uMotion.fast, const Duration(milliseconds: 200));
    expect(Planext4uBreakpoints.tablet, 768);
  });

  testWidgets('foundation shell exposes role and environment semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Planext4uFoundationApp(
        role: AppRole.customer,
        environmentLabel: 'staging',
      ),
    );

    expect(find.text('Customer application'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Build environment: staging',
      ),
      findsOneWidget,
    );
    expect(find.text('Customer shell ready'), findsOneWidget);
  });

  testWidgets('buttons meet the 48 pixel interaction target', (tester) async {
    await tester.pumpWidget(
      _testApp(
        const Center(
          child: Planext4uButton(label: 'Continue', onPressed: _noop),
        ),
      ),
    );

    final size = tester.getSize(find.byType(FilledButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('status conveys its meaning without colour alone', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        _testApp(
          const Planext4uStatusPill(
            label: 'Verified',
            tone: Planext4uStatusTone.success,
          ),
        ),
      );

      expect(find.bySemanticsLabel('Status: Verified'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('status remains readable in a compact product card', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        const SizedBox(
          width: 72,
          child: Planext4uStatusPill(
            label: 'Available',
            tone: Planext4uStatusTone.success,
          ),
        ),
      ),
    );

    expect(find.text('Available'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('campaign and benefit components fit narrow large-text layouts', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        _testApp(
          SizedBox(
            width: 390,
            height: 500,
            child: ListView(
              children: const [
                Planext4uCampaignHero(
                  title: 'Smart shopping, everyday.',
                  subtitle: 'Everything you need from trusted local sellers.',
                  actionLabel: 'Start shopping',
                  onAction: _noop,
                ),
                SizedBox(height: Planext4uSpacing.x3),
                Planext4uBenefitStrip(
                  items: [
                    Planext4uBenefitItem(
                      title: 'Secure shopping',
                      subtitle: 'Protected payments and privacy',
                      icon: Icons.verified_user_outlined,
                    ),
                    Planext4uBenefitItem(
                      title: 'Fast delivery',
                      subtitle: 'Live fulfilment updates',
                      icon: Icons.local_shipping_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),
          textScale: 1.3,
        ),
      );

      expect(
        find.bySemanticsLabel(
          RegExp(
            r'^Smart shopping, everyday\. Everything you need from trusted local sellers\.',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Secure shopping'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('discovery and commerce components fit at 200% text', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        SizedBox(
          width: 390,
          height: 760,
          child: ListView(
            key: const ValueKey('a11y-discovery-list'),
            children: const [
              Planext4uCampaignHero(
                title: 'Smart shopping, everyday.',
                subtitle: 'Everything you need from trusted local sellers.',
                actionLabel: 'Start shopping',
                onAction: _noop,
              ),
              SizedBox(height: Planext4uSpacing.x3),
              Planext4uBenefitStrip(
                items: [
                  Planext4uBenefitItem(
                    title: 'Secure shopping',
                    subtitle: 'Protected payments and privacy',
                    icon: Icons.verified_user_outlined,
                  ),
                ],
              ),
              SizedBox(height: Planext4uSpacing.x3),
              SizedBox(
                height: 520,
                child: Planext4uProductCard(
                  name: 'Synthetic neighbourhood essentials basket',
                  vendor: 'Verified local seller',
                  price: '₹1,249.00',
                  status: 'Available',
                  onPressed: _noop,
                  onFavorite: _noop,
                  onAddToCart: _noop,
                ),
              ),
            ],
          ),
        ),
        textScale: 2,
      ),
    );

    for (var index = 0; index < 4; index++) {
      await tester.drag(
        find.byKey(const ValueKey('a11y-discovery-list')),
        const Offset(0, -360),
      );
      await tester.pumpAndSettle();
    }
    expect(
      find.byTooltip('Add Synthetic neighbourhood essentials basket to cart'),
      findsOneWidget,
    );
    expect(
      find.byTooltip(
        'Add Synthetic neighbourhood essentials basket to favourites',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final state in Planext4uViewState.values) {
    testWidgets('$state has a stable accessible rendering at 130% text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          Planext4uStatePanel(
            state: state,
            title: 'Synthetic state',
            message:
                'The application explains this state and the next safe action.',
            actionLabel: 'Try again',
            onAction: _noop,
          ),
          textScale: 1.3,
        ),
      );
      await tester.pump();

      expect(find.text('Synthetic state'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('visible catalogue meets automated accessibility guidelines', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        _catalogueApp(brightness: Brightness.light, textScale: 1.3),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(tester, meetsGuideline(androidTapTargetGuideline));
      expect(tester, meetsGuideline(labeledTapTargetGuideline));
      expect(tester, meetsGuideline(textContrastGuideline));
    } finally {
      semantics.dispose();
    }
  });
}

Widget _testApp(Widget child, {double textScale = 1}) => MaterialApp(
  theme: Planext4uTheme.light,
  builder: (context, renderedChild) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: renderedChild!,
  ),
  home: Scaffold(body: Center(child: child)),
);

Widget _catalogueApp({
  required Brightness brightness,
  required double textScale,
}) => MaterialApp(
  theme: Planext4uTheme.light,
  darkTheme: Planext4uTheme.dark,
  themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: const Planext4uWidgetCatalogue(),
);

void _noop() {}
