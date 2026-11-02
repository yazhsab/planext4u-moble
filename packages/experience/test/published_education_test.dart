import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

void main() {
  test('published education is role/language/account/content scoped', () async {
    final remote = _Remote();
    final first = _controller(remote);
    await first.load('en');
    final version = first.config!.version;
    expect(first.config!.steps.single.title, 'Welcome');
    remote.title = 'Updated introduction';
    await first.load('en', retry: true);
    expect(first.config!.version, isNot(version));
    final second = _controller(remote, scope: 'another-account');
    await second.load('en');
    expect(first.config!.version, isNot(second.config!.version));
    first.dispose();
    second.dispose();
  });

  test('missing local language falls back to published English only', () async {
    final remote = _Remote()..missingTamil = true;
    final controller = _controller(remote);
    await controller.load('ta');
    expect(remote.requests, ['customer:ta', 'customer:en']);
    expect(controller.config, isNotNull);
    expect(controller.failed, isFalse);
    controller.dispose();
  });

  test(
    'no published page preserves the existing native introduction',
    () async {
      final remote = _Remote()..missingAll = true;
      final controller = _controller(remote);
      await controller.load('en');
      expect(controller.loading, isFalse);
      expect(controller.failed, isFalse);
      expect(controller.config, isNull);
      controller.dispose();
    },
  );

  test(
    'malformed or foreign audience content cannot become education',
    () async {
      for (final change in ['audience', 'id', 'kind', 'message', 'version']) {
        final remote = _Remote()..bad = change;
        final controller = _controller(remote);
        await controller.load('en');
        expect(controller.failed, isTrue, reason: change);
        expect(controller.config, isNull);
        controller.dispose();
      }
    },
  );

  test(
    'a newer language load supersedes an earlier delayed response',
    () async {
      final remote = _Remote()..block = Completer<void>();
      final controller = _controller(remote);
      final old = controller.load('ta');
      remote.block = null;
      await controller.load('en');
      final version = controller.config!.version;
      remote.firstBlock!.complete();
      await old;
      expect(controller.config!.version, version);
      controller.dispose();
    },
  );

  test('retired account cannot publish delayed education', () async {
    final remote = _Remote()..block = Completer<void>();
    var current = true;
    final controller = _controller(remote, isCurrent: () => current);
    final pending = controller.load('en');
    current = false;
    controller.dispose();
    remote.firstBlock!.complete();
    await pending;
    expect(controller.config, isNull);
  });

  testWidgets('configured education persists completion and fits large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final remote = _Remote();
    final store = _Store();
    final controller = _controller(remote, store: store);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: PublishedEducationGate(controller: controller, child: child!),
        ),
        home: const Text('Account home'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Welcome'), findsOneWidget);
    await tester.ensureVisible(find.text('Get started'));
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.text('Account home'), findsOneWidget);
    expect(store.versions, contains(controller.config!.version));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}

PublishedEducationController _controller(
  _Remote remote, {
  String scope = 'tenant:IN:account',
  bool Function()? isCurrent,
  FirstRunStore? store,
}) => PublishedEducationController(
  remote: remote,
  role: 'customer',
  scope: scope,
  scopeIsCurrent: isCurrent ?? () => true,
  store: store ?? _Store(),
);

final class _Store implements FirstRunStore {
  final versions = <String>{};
  @override
  Future<bool> completed(String version) async => versions.contains(version);
  @override
  Future<void> complete(String version) async {
    versions.add(version);
  }
}

final class _Remote implements PublishedEducationRemote {
  final requests = <String>[];
  bool missingTamil = false;
  bool missingAll = false;
  String title = 'Welcome';
  String? bad;
  Completer<void>? block;
  Completer<void>? firstBlock;
  @override
  Future<Map<String, Object?>?> fetch(String role, String locale) async {
    requests.add('$role:$locale');
    final pending = block;
    firstBlock ??= pending;
    await pending?.future;
    if (missingAll || missingTamil && locale == 'ta') return null;
    return {
      'revision': 1,
      'page': {
        'id': bad == 'id' ? 'other-page' : 'mobile-onboarding-$role-$locale',
        'enabled': true,
        'audience': [bad == 'audience' ? 'RIDER' : role.toUpperCase()],
        'blocks': [
          {
            'kind': bad == 'kind' ? 'HTML' : 'ONBOARDING',
            'enabled': true,
            'content': {
              'version': bad == 'version' ? 'bad version' : '1',
              'title': title,
              'message': bad == 'message'
                  ? ''
                  : 'Choose when to share your location.',
            },
          },
        ],
      },
    };
  }
}
