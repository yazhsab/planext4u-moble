import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

void main() {
  test(
    'linking checks binding and fresh proof without replacing the session',
    () async {
      final fixture = _Fixture();
      expect(
        await fixture.controller.unlock(SignInMethod.phone, code: '123456'),
        isTrue,
      );
      expect(fixture.remote.freshness, [false, true]);
      expect(
        await fixture.controller.link(
          SignInMethod.password,
          email: 'new@example.test',
          password: 'secret',
        ),
        isTrue,
      );
      expect(fixture.remote.freshness, [false, true, true, true]);
      expect(fixture.provider.actions, [
        'reauthenticate:phone',
        'link:password',
      ]);
      expect(fixture.controller.verified!.methods, contains('password'));
      expect(fixture.controller.message, contains('Verify your email'));
      expect(fixture.controller.unlocked, isTrue);
      fixture.controller.dispose();
    },
  );

  test(
    'foreign provider UID is rejected before reauthentication or mutation',
    () async {
      final fixture = _Fixture();
      fixture.remote.subject = 'foreign-user';
      expect(await fixture.controller.unlock(SignInMethod.google), isFalse);
      expect(fixture.provider.actions, isEmpty);
      expect(fixture.controller.verified, isNull);
      expect(await fixture.controller.link(SignInMethod.google), isFalse);
      expect(fixture.provider.actions, isEmpty);
      fixture.controller.dispose();
    },
  );

  test('expired local grant requires reauthentication', () async {
    final fixture = _Fixture();
    await fixture.controller.unlock(SignInMethod.google);
    fixture.now = fixture.now.add(const Duration(minutes: 5));
    expect(await fixture.controller.link(SignInMethod.password), isFalse);
    expect(fixture.provider.actions, ['reauthenticate:google']);
    fixture.controller.dispose();
  });

  for (final change in ['scope', 'provider', 'dispose', 'lock']) {
    test(
      '$change during binding prevents subsequent credential operations',
      () async {
        final fixture = _Fixture();
        fixture.remote.block = Completer<void>();
        final pending = fixture.controller.unlock(SignInMethod.google);
        await Future<void>.delayed(Duration.zero);
        switch (change) {
          case 'scope':
            fixture.scopeCurrent = false;
          case 'provider':
            fixture.provider.subject = 'another-provider';
          case 'dispose':
            fixture.controller.dispose();
          case 'lock':
            fixture.controller.lock();
        }
        fixture.remote.block!.complete();
        expect(await pending, isFalse);
        expect(fixture.provider.actions, isEmpty);
        expect(fixture.controller.verified, isNull);
        if (change != 'dispose') fixture.controller.dispose();
      },
    );
  }

  test(
    'duplicate credential failure is private and never merges accounts',
    () async {
      final fixture = _Fixture();
      await fixture.controller.unlock(SignInMethod.google);
      fixture.provider.linkFailure = StateError(
        'credential-already-in-use private@example.test secret',
      );
      expect(
        await fixture.controller.link(
          SignInMethod.password,
          email: 'private@example.test',
          password: 'secret',
        ),
        isFalse,
      );
      expect(
        fixture.controller.status,
        AccountSecurityStatus.confirmationRequired,
      );
      expect(
        fixture.controller.message,
        isNot(contains('private@example.test')),
      );
      expect(fixture.controller.message, isNot(contains('secret')));
      expect(fixture.controller.verified, isNull);
      expect(fixture.controller.unlocked, isFalse);
      fixture.controller.dispose();
    },
  );

  test(
    'interrupted committed link requires readback before another mutation',
    () async {
      final fixture = _Fixture();
      await fixture.controller.unlock(SignInMethod.google);
      fixture.remote.failAt = 4;
      expect(await fixture.controller.link(SignInMethod.password), isFalse);
      expect(fixture.provider.methods, contains('password'));
      expect(
        fixture.controller.status,
        AccountSecurityStatus.confirmationRequired,
      );
      fixture.remote.failAt = null;
      expect(await fixture.controller.refresh(), isTrue);
      expect(fixture.controller.verified!.methods, contains('password'));
      expect(fixture.controller.unlocked, isFalse);
      fixture.controller.dispose();
    },
  );

  test(
    'single flight rejects a second concurrent credential request',
    () async {
      final fixture = _Fixture();
      fixture.remote.block = Completer<void>();
      final pending = fixture.controller.unlock(SignInMethod.google);
      expect(
        await fixture.controller.requestPhoneCode('+919876543210'),
        isFalse,
      );
      fixture.remote.block!.complete();
      expect(await pending, isTrue);
      fixture.controller.dispose();
    },
  );

  test('method response rejects malformed or duplicate methods', () {
    for (final methods in <List<Object>>[
      [],
      ['password', 'password'],
      ['ADMIN'],
      [1],
    ]) {
      expect(
        () => VerifiedSignInMethods.fromJson({
          'provider_subject': 'owner',
          'methods': methods,
          'email_verified': true,
        }),
        throwsFormatException,
      );
    }
    expect(
      () => VerifiedSignInMethods.fromJson({
        'provider_subject': 'owner with whitespace',
        'methods': ['phone'],
        'email_verified': true,
      }),
      throwsFormatException,
    );
  });

  testWidgets(
    'security controls fit narrow large text and clear secrets after use',
    (tester) async {
      final fixture = _Fixture();
      await tester.binding.setSurfaceSize(const Size(320, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: AccountSecurityScreen(controller: fixture.controller),
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('account-security-email')),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byKey(const ValueKey('account-security-email')),
        'owner@example.test',
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('account-security-password')),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byKey(const ValueKey('account-security-password')),
        'private-secret',
      );
      await tester.ensureVisible(find.text('Verify existing method'));
      await tester.tap(find.text('Verify existing method'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('account-security-password')),
      );
      final password = tester.widget<TextField>(
        find.byKey(const ValueKey('account-security-password')),
      );
      expect(password.controller!.text, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      expect(fixture.controller.unlocked, isFalse);
      fixture.controller.dispose();
    },
  );
}

final class _Fixture {
  _Fixture() {
    remote = _Remote(provider);
    controller = AccountSecurityController(
      remote: remote,
      provider: provider,
      scopeIsCurrent: () => scopeCurrent,
      clock: () => now,
    );
  }
  final provider = _Provider();
  late final _Remote remote;
  late final AccountSecurityController controller;
  bool scopeCurrent = true;
  DateTime now = DateTime.utc(2026, 10, 25);
}

final class _Remote implements AccountSecurityRemote {
  _Remote(this.provider);
  final _Provider provider;
  final freshness = <bool>[];
  String subject = 'provider-owner';
  Completer<void>? block;
  int? failAt;
  @override
  Future<VerifiedSignInMethods> verify(
    String token, {
    bool requireFresh = true,
  }) async {
    freshness.add(requireFresh);
    await block?.future;
    if (freshness.length == failAt) throw StateError('network interrupted');
    return VerifiedSignInMethods(
      subject: subject,
      methods: provider.methods,
      emailVerified: false,
    );
  }
}

final class _Provider implements AccountLinkingProvider {
  String? subject = 'provider-owner';
  final methods = <String>{'phone'};
  final actions = <String>[];
  Object? linkFailure;
  @override
  String? get currentSubject => subject;
  @override
  Future<String> assertion(String expectedSubject) async =>
      'fresh-provider-token';
  @override
  Future<void> reauthenticate(
    String subject,
    SignInMethod method, {
    String email = '',
    String password = '',
    String code = '',
  }) async {
    actions.add('reauthenticate:${method.name}');
  }

  @override
  Future<void> link(
    String subject,
    SignInMethod method, {
    String email = '',
    String password = '',
    String code = '',
  }) async {
    actions.add('link:${method.name}');
    if (linkFailure != null) throw linkFailure!;
    methods.add(switch (method) {
      SignInMethod.password => 'password',
      SignInMethod.google => 'google.com',
      SignInMethod.phone => 'phone',
    });
  }

  @override
  Future<void> requestPhoneCode(String subject, String phone) async {
    actions.add('phone');
  }

  @override
  Future<void> sendEmailVerification(String subject) async {
    actions.add('email-verification');
  }

  @override
  void cancel() {}
}
