import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

class Cache implements PublicStartupStore {
  @override
  Future<PublicStartupDocument?> read() async => null;
  @override
  Future<void> save(PublicStartupDocument document) async {}
}

class Remote implements PublicStartupRemote {
  final result = Completer<PublicStartupDocument>();
  ApiCancellationToken? cancellation;
  @override
  Future<PublicStartupDocument> fetch({
    required String country,
    required String role,
    required String locale,
    required ApiCancellationToken cancellation,
  }) {
    this.cancellation = cancellation;
    return result.future;
  }
}

PublicStartupController controller(Remote remote) => PublicStartupController(
  remote: remote,
  store: Cache(),
  country: 'IN',
  role: 'customer',
  locale: 'en',
);
PublicStartupGate gate(
  PublicStartupController controller,
  Future<Widget> Function() initialize,
) => PublicStartupGate(
  apiBaseUrl: Uri.parse('https://api.example.test'),
  role: 'customer',
  controller: controller,
  initialize: initialize,
);
const runtime = MaterialApp(home: Scaffold(body: Text('Private runtime')));
void main() {
  testWidgets(
    'First frame draws before provider startup and skip cancels public network work',
    (tester) async {
      final remote = Remote(),
          c = controller(remote),
          initialized = Completer<Widget>();
      await tester.pumpWidget(gate(c, () => initialized.future));
      expect(find.text('Planext4u'), findsOneWidget);
      expect(find.text('Private runtime'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('skip-public-startup')));
      await tester.pump();
      expect(remote.cancellation?.isCancelled, true);
      initialized.complete(runtime);
      await tester.pumpAndSettle();
      expect(find.text('Private runtime'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets(
    'The splash budget ends at 1.2 seconds and the already mounted runtime stays intact',
    (tester) async {
      final remote = Remote(), c = controller(remote);
      var builds = 0;
      await tester.pumpWidget(
        gate(c, () async {
          builds++;
          return runtime;
        }),
      );
      await tester.pump();
      expect(find.text('Private runtime'), findsNothing);
      await tester.pump(const Duration(milliseconds: 1201));
      await tester.pumpAndSettle();
      expect(find.text('Private runtime'), findsOneWidget);
      expect(builds, 1);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets(
    'A timed out initializer can be retried and its late old result is ignored',
    (tester) async {
      final remote = Remote(),
          c = controller(remote),
          old = Completer<Widget>();
      var calls = 0;
      await tester.pumpWidget(
        gate(c, () {
          calls++;
          return calls == 1 ? old.future : Future.value(runtime);
        }),
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      expect(find.text('The app could not start. Try again.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('retry-startup-runtime')));
      await tester.pumpAndSettle();
      expect(find.text('Private runtime'), findsOneWidget);
      old.complete(const MaterialApp(home: Text('Obsolete runtime')));
      await tester.pumpAndSettle();
      expect(find.text('Obsolete runtime'), findsNothing);
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets(
    'Disposal cancels timers and ignores both late runtime and public responses',
    (tester) async {
      final remote = Remote(),
          c = controller(remote),
          pending = Completer<Widget>();
      await tester.pumpWidget(gate(c, () => pending.future));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(remote.cancellation?.isCancelled, true);
      pending.complete(runtime);
      await tester.pump();
      expect(find.text('Private runtime'), findsNothing);
      c.dispose();
    },
  );
  testWidgets(
    'Public splash remains usable on a narrow landscape screen with large text',
    (tester) async {
      tester.view.physicalSize = const Size(640, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final remote = Remote(), c = controller(remote);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: gate(c, () async => runtime),
        ),
      );
      remote.result.complete(
        PublicStartupDocument(
          revision: 1,
          publishedAt: DateTime.utc(2026, 10, 25),
          country: 'IN',
          role: 'customer',
          locale: 'en',
          version: '1',
          title: 'A published public welcome',
          message: 'You can continue without granting any device permission.',
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        MediaQuery.textScalerOf(
          tester.element(find.byKey(const ValueKey('public-startup-title'))),
        ).scale(10),
        20,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('skip-public-startup')),
      );
      await tester.tap(find.byKey(const ValueKey('skip-public-startup')));
      await tester.pumpAndSettle();
      expect(find.text('Private runtime'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
}
