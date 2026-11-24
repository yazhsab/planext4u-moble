import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_experience/planext4u_experience.dart';
import 'package:planext4u_storage/planext4u_storage.dart';

void main() {
  testWidgets('skipping introduction persists completion across restart', (
    tester,
  ) async {
    final records = MemoryBinaryRecordStore();
    final keys = MemoryCacheKeyProvider();
    Widget gate() => MaterialApp(
      home: FirstRunGate(
        config: FirstRunConfig.forRole('customer'),
        store: EncryptedFirstRunStore(
          EncryptedRecordStore(
            records: records,
            keyProvider: keys,
            namespace: 'skip.onboarding',
            maxPlaintextBytes: 4096,
          ),
        ),
        child: const Text('Signed out home'),
      ),
    );
    await tester.pumpWidget(gate());
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Planext4u customer'), findsOneWidget);
    await tester.tap(find.text('Skip introduction'));
    await tester.pumpAndSettle();
    expect(find.text('Signed out home'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(gate());
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Planext4u customer'), findsNothing);
    expect(find.text('Signed out home'), findsOneWidget);
  });

  testWidgets('education remains scrollable on landscape at 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = EncryptedFirstRunStore(
      EncryptedRecordStore(
        records: MemoryBinaryRecordStore(),
        keyProvider: MemoryCacheKeyProvider(),
        namespace: 'landscape.onboarding',
        maxPlaintextBytes: 4096,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: FirstRunGate(
          config: FirstRunConfig.forRole('customer'),
          store: store,
          child: const Text('Home'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (var index = 0; index < 3; index++) {
      final label = index == 2 ? 'Get started' : 'Continue';
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(find.text('Home'), findsOneWidget);
  });
  testWidgets(
    'completion survives widget and encrypted-store restart; new version repeats education',
    (tester) async {
      final records = MemoryBinaryRecordStore();
      final keys = MemoryCacheKeyProvider();
      FirstRunStore store() => EncryptedFirstRunStore(
        EncryptedRecordStore(
          records: records,
          keyProvider: keys,
          namespace: 'test.onboarding',
          maxPlaintextBytes: 4096,
        ),
      );
      FirstRunConfig config(String version) => FirstRunConfig(
        version: version,
        steps: const [
          OnboardingStep(
            title: 'Welcome',
            message: 'Choose when to share location.',
          ),
        ],
      );
      Widget gate(String version) => MaterialApp(
        home: FirstRunGate(
          key: ValueKey(version),
          config: config(version),
          store: store(),
          child: const Text('Signed out home'),
        ),
      );
      await tester.pumpWidget(gate('1'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome'), findsOneWidget);
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      expect(find.text('Signed out home'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(gate('1'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome'), findsNothing);
      await tester.pumpWidget(gate('2'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome'), findsOneWidget);
    },
  );
}
