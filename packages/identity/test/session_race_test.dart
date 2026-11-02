import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_identity/planext4u_identity.dart';

import 'identity_session_test.dart'
    show authentication, session, FakeRemote, FakeEmailProvider;

void main() {
  final now = DateTime.utc(2026, 8, 27, 10);
  final old = authentication(now);
  final next = authentication(
    now,
    identityId: 'identity-new',
    sessionId: 'session-new',
    accessToken: 'new-access-token',
    refreshToken: 'refresh-token-new00000000000000000000000000001',
  );
  final rotated = authentication(
    now,
    accessToken: 'rotated-old-access',
    refreshToken: 'refresh-token-oldrotated000000000000000000001',
  );
  test(
    'A country change cannot reuse an earlier interactive unlock proof',
    () async {
      final remote = FakeRemote(old);
      final store = MemorySecureSessionStore();
      final controller = session(remote, store, now);
      await controller.signInWithEmail(
        provider: FakeEmailProvider(),
        email: 'person@example.test',
        secret: 'synthetic-secret',
      );
      expect(controller.hasFreshInteractiveAuthentication, true);
      final value = old.toJson();
      value['country'] = 'SG';
      value['session'] = {
        ...value['session']! as Map<String, Object?>,
        'country': 'SG',
      };
      remote.next = IdentityAuthentication.fromJson(value);
      await controller.refresh();
      expect(controller.hasFreshInteractiveAuthentication, false);
      await controller.dispose();
    },
  );
  test(
    'Restore and refresh cannot invent fresh interactive local-unlock proof',
    () async {
      final store = MemorySecureSessionStore();
      await store.write(old);
      final controller = session(FakeRemote(old), store, now);
      await controller.initialize();
      expect(controller.hasFreshInteractiveAuthentication, false);
      await controller.refresh();
      expect(controller.hasFreshInteractiveAuthentication, false);
      await controller.signInWithEmail(
        provider: FakeEmailProvider(),
        email: 'person@example.test',
        secret: 'synthetic-secret',
      );
      expect(controller.hasFreshInteractiveAuthentication, true);
      await controller.signOut();
      expect(controller.hasFreshInteractiveAuthentication, false);
      await controller.dispose();
    },
  );
  test(
    'An interactive exchange with old provider authentication cannot reset local unlock',
    () async {
      final store = MemorySecureSessionStore();
      final controller = session(
        FakeRemote(authentication(now.subtract(const Duration(hours: 1)))),
        store,
        now,
      );
      await controller.signInWithEmail(
        provider: FakeEmailProvider(),
        email: 'person@example.test',
        secret: 'synthetic-secret',
      );
      expect(controller.hasFreshInteractiveAuthentication, false);
      await controller.dispose();
    },
  );

  test('failed account switch cannot restore the previous account', () async {
    final store = MemorySecureSessionStore();
    await store.write(old);
    final remote = FakeRemote(next);
    final controller = session(remote, store, now);
    await controller.initialize();
    await expectLater(
      controller.signInWithEmail(
        provider: _EmailRejected(),
        email: 'other@example.test',
        secret: 'synthetic-secret',
      ),
      throwsStateError,
    );
    expect(controller.state.status, IdentitySessionStatus.signedOut);
    expect(await controller.accessToken(), isNull);
    expect(await store.read(), isNull);
    expect(remote.revokedTokens, [old.tokens.refreshToken]);
    final restarted = session(remote, store, now);
    await restarted.initialize();
    expect(restarted.state.status, IdentitySessionStatus.signedOut);
    await controller.dispose();
    await restarted.dispose();
  });

  test(
    'failed credential deletion revokes known stored sessions and stops login',
    () async {
      final store = _ClearRejected(old);
      final remote = FakeRemote(next);
      final controller = session(remote, store, now);
      await expectLater(
        controller.signInWithEmail(
          provider: FakeEmailProvider(),
          email: 'new@example.test',
          secret: 'synthetic-secret',
        ),
        throwsStateError,
      );
      expect(remote.revokedTokens, [old.tokens.refreshToken]);
      expect(remote.exchanges, isEmpty);
      expect(controller.state.status, IdentitySessionStatus.signedOut);
      await controller.dispose();
    },
  );

  test(
    'direct login retires stored credentials before acquiring a provider',
    () async {
      final store = MemorySecureSessionStore();
      await store.write(old);
      final remote = FakeRemote(next);
      final provider = _EmailBlocked();
      final controller = session(remote, store, now);
      final login = controller.signInWithEmail(
        provider: provider,
        email: 'new@example.test',
        secret: 'synthetic-secret',
      );
      await provider.started.future;
      expect(await store.read(), isNull);
      expect(remote.revokedTokens, [old.tokens.refreshToken]);
      provider.release.complete();
      await login;
      expect(controller.state.authentication?.identityId, next.identityId);
      expect((await store.read())?.identityId, next.identityId);
      expect(remote.revokedTokens, isNot(contains(next.tokens.refreshToken)));
      await controller.dispose();
    },
  );

  test(
    'a late refresh cannot restore the account after logout and another login',
    () async {
      final store = MemorySecureSessionStore();
      await store.write(old);
      final remote = _RefreshBlocked(old, rotated);
      final controller = session(remote, store, now);
      await controller.initialize();
      final pending = controller.refresh();
      await remote.started.future;
      await controller.signOut();
      remote.next = next;
      await controller.signInWithEmail(
        provider: FakeEmailProvider(),
        email: 'new@example.test',
        secret: 'synthetic-secret',
      );
      remote.release.complete();
      expect(await pending, isFalse);
      expect(controller.state.authentication?.identityId, next.identityId);
      expect((await store.read())?.identityId, next.identityId);
      expect(remote.revokedTokens, contains(rotated.tokens.refreshToken));
      expect(remote.revokedTokens, isNot(contains(next.tokens.refreshToken)));
      await controller.dispose();
      expect(await controller.accessToken(), isNull);
    },
  );

  test(
    'a late provider exchange is revoked without replacing a later login',
    () async {
      final store = MemorySecureSessionStore();
      final remote = _ExchangeBlocked(next);
      final controller = session(remote, store, now);
      final first = controller.signInWithEmail(
        provider: FakeEmailProvider(),
        email: 'old@example.test',
        secret: 'synthetic-secret',
      );
      await remote.started.future;
      await controller.signOut();
      await controller.signInWithEmail(
        provider: FakeEmailProvider(),
        email: 'new@example.test',
        secret: 'synthetic-secret',
      );
      remote.release.complete(old);
      await first;
      expect(controller.state.authentication?.identityId, next.identityId);
      expect((await store.read())?.identityId, next.identityId);
      expect(remote.revokedTokens, contains(old.tokens.refreshToken));
      expect(remote.revokedTokens, isNot(contains(next.tokens.refreshToken)));
      await controller.dispose();
    },
  );

  test(
    'slow secure-store writes cannot clear or overwrite an acknowledged later login',
    () async {
      final store = _WriteBlocked();
      final remote = FakeRemote(old);
      final controller = session(remote, store, now);
      final first = controller.signInWithEmail(
        provider: FakeEmailProvider(),
        email: 'old@example.test',
        secret: 'synthetic-secret',
      );
      await store.started.future;
      final logout = controller.signOut();
      remote.next = next;
      final later = controller.signInWithEmail(
        provider: FakeEmailProvider(),
        email: 'new@example.test',
        secret: 'synthetic-secret',
      );
      store.release.complete();
      await Future.wait([first, logout, later]);
      expect(controller.state.authentication?.identityId, next.identityId);
      expect((await store.read())?.identityId, next.identityId);
      expect(remote.revokedTokens, isNot(contains(next.tokens.refreshToken)));
      await controller.dispose();
    },
  );

  test(
    'a delayed restore cannot clear or display a newly signed-in account',
    () async {
      final store = _ReadBlocked(
        authentication(
          now,
          refreshExpiresAt: now.subtract(const Duration(seconds: 1)),
        ),
      );
      final controller = session(FakeRemote(next), store, now);
      final restore = controller.initialize();
      await store.started.future;
      final login = controller.signInWithEmail(
        provider: FakeEmailProvider(),
        email: 'new@example.test',
        secret: 'synthetic-secret',
      );
      store.release.complete();
      await Future.wait([restore, login]);
      expect(controller.state.authentication?.identityId, next.identityId);
      expect((await store.read())?.identityId, next.identityId);
      await controller.dispose();
    },
  );
}

final class _EmailRejected implements EmailIdentityProvider {
  @override
  Future<ProviderAssertion> authenticate({
    required String email,
    required String secret,
  }) async => throw StateError('Provider rejected the account switch.');
}

final class _ClearRejected implements SecureSessionStore {
  _ClearRejected(this.previous);
  final IdentityAuthentication previous;
  @override
  Future<IdentityAuthentication?> read() async => previous;
  @override
  Future<void> write(IdentityAuthentication value) async =>
      throw StateError('Secure storage failed.');
  @override
  Future<void> clear() async => throw StateError('Secure storage failed.');
}

final class _EmailBlocked implements EmailIdentityProvider {
  final started = Completer<void>(), release = Completer<void>();
  @override
  Future<ProviderAssertion> authenticate({
    required String email,
    required String secret,
  }) async {
    started.complete();
    await release.future;
    return FakeEmailProvider().authenticate(email: email, secret: secret);
  }
}

final class _RefreshBlocked extends FakeRemote {
  _RefreshBlocked(super.next, this.rotated);
  final IdentityAuthentication rotated;
  final started = Completer<void>(), release = Completer<void>();
  @override
  Future<IdentityAuthentication> refresh(String token) async {
    started.complete();
    await release.future;
    return rotated;
  }
}

final class _ExchangeBlocked extends FakeRemote {
  _ExchangeBlocked(super.next);
  final started = Completer<void>();
  final release = Completer<IdentityAuthentication>();
  bool first = true;
  @override
  Future<IdentityAuthentication> exchange({
    required ProviderAssertion assertion,
    required String deviceId,
    required String country,
  }) {
    if (first) {
      first = false;
      started.complete();
      return release.future;
    }
    return super.exchange(
      assertion: assertion,
      deviceId: deviceId,
      country: country,
    );
  }
}

final class _WriteBlocked implements SecureSessionStore {
  final delegate = MemorySecureSessionStore();
  final started = Completer<void>(), release = Completer<void>();
  bool first = true;
  @override
  Future<void> write(IdentityAuthentication value) async {
    if (first) {
      first = false;
      started.complete();
      await release.future;
    }
    await delegate.write(value);
  }

  @override
  Future<IdentityAuthentication?> read() => delegate.read();
  @override
  Future<void> clear() => delegate.clear();
}

final class _ReadBlocked implements SecureSessionStore {
  _ReadBlocked(this.previous);
  final IdentityAuthentication previous;
  final delegate = MemorySecureSessionStore();
  final started = Completer<void>(), release = Completer<void>();
  bool first = true;
  @override
  Future<IdentityAuthentication?> read() async {
    if (first) {
      first = false;
      started.complete();
      await release.future;
      return previous;
    }
    return delegate.read();
  }

  @override
  Future<void> write(IdentityAuthentication value) => delegate.write(value);
  @override
  Future<void> clear() => delegate.clear();
}
