import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_core/planext4u_core.dart';
import 'package:planext4u_identity/planext4u_identity.dart';

void main() {
  final now = DateTime.utc(2026, 8, 27, 10);

  group('identity provider flows', () {
    test(
      'verified phone enrollment opens vendor and rider onboarding only',
      () async {
        for (final role in [AppRole.vendor, AppRole.rider]) {
          final remote = FakeRemote(
            authentication(now, roles: {AppRole.customer, role}),
          );
          final controller = IdentitySessionController(
            remote: remote,
            store: MemorySecureSessionStore(),
            applicationRole: role,
            deviceId: 'new-phone-install',
            country: 'IN',
            clock: () => now,
          );
          final result = await controller.signInWithPhoneOtp(
            provider: FakePhoneProvider(),
            challengeId: 'verified-challenge',
            code: '123456',
          );
          expect(result.status, IdentitySessionStatus.authenticated);
          expect(remote.enrollments, [role]);
          expect(
            remote.exchanges.single.provider,
            IdentityProviderKind.firebase,
          );
          controller.dispose();
        }
      },
    );
    test(
      'explicit recovery uses the recovery endpoint and never enrollment',
      () async {
        final remote = FakeRemote(authentication(now));
        final controller = session(remote, MemorySecureSessionStore(), now);
        final result = await controller.signInWithEmail(
          provider: FakeEmailProvider(),
          email: 'owner@example.test',
          secret: 'synthetic-secret',
          recoverAccount: true,
        );
        expect(result.status, IdentitySessionStatus.authenticated);
        expect(remote.recoveryCalls, 1);
        expect(remote.enrollments, isEmpty);
      },
    );
    test(
      'registration enrolls only the application participation role',
      () async {
        final remote = FakeRemote(authentication(now));
        final controller = session(remote, MemorySecureSessionStore(), now);
        final result = await controller.registerWithEmail(
          provider: FakeEmailProvider(),
          email: 'new@example.test',
          secret: 'synthetic-password',
        );
        expect(result.status, IdentitySessionStatus.authenticated);
        expect(remote.enrollments, [AppRole.customer]);
        expect(remote.exchanges, hasLength(1));
      },
    );
    test('phone OTP assertion is exchanged and persisted', () async {
      final remote = FakeRemote(authentication(now));
      final store = MemorySecureSessionStore();
      final controller = session(remote, store, now);

      final result = await controller.signInWithPhoneOtp(
        provider: FakePhoneProvider(),
        challengeId: 'challenge-1',
        code: '123456',
      );

      expect(result.status, IdentitySessionStatus.authenticated);
      expect(remote.exchanges.single.provider, IdentityProviderKind.firebase);
      expect(remote.deviceIds, ['device-install-001']);
      expect(store.hasSession, isTrue);
    });

    test('email and OAuth assertions use their provider channels', () async {
      final remote = FakeRemote(authentication(now));
      final controller = session(remote, MemorySecureSessionStore(), now);

      await controller.signInWithEmail(
        provider: FakeEmailProvider(),
        email: 'person@example.test',
        secret: 'synthetic-password',
      );
      await controller.signInWithOAuth(
        provider: FakeOAuthProvider(),
        vendor: OAuthVendor.apple,
      );

      expect(remote.exchanges.map((value) => value.provider), [
        IdentityProviderKind.local,
        IdentityProviderKind.oidc,
      ]);
    });

    test('wrong application role revokes and never persists a token', () async {
      final remote = FakeRemote(authentication(now, roles: {AppRole.vendor}));
      final store = MemorySecureSessionStore();
      final controller = session(remote, store, now);

      final result = await controller.signInWithEmail(
        provider: FakeEmailProvider(),
        email: 'vendor@example.test',
        secret: 'synthetic-password',
      );

      expect(result.status, IdentitySessionStatus.roleDenied);
      expect(store.hasSession, isFalse);
      expect(remote.revokedTokens, [
        'refresh-token-00000000000000000000000000000001',
      ]);
    });
    test('cross-country sign-in revokes and never persists a token', () async {
      final remote = FakeRemote(authentication(now));
      final store = MemorySecureSessionStore();
      final controller = session(remote, store, now, country: 'NG');

      final result = await controller.signInWithEmail(
        provider: FakeEmailProvider(),
        email: 'customer@example.test',
        secret: 'synthetic-password',
      );

      expect(result.status, IdentitySessionStatus.roleDenied);
      expect(store.hasSession, isFalse);
      expect(await controller.accessToken(), isNull);
      expect(remote.revokedTokens, [
        'refresh-token-00000000000000000000000000000001',
      ]);
    });
    test('matching country sign-in persists the session', () async {
      final remote = FakeRemote(authentication(now, country: 'NG'));
      final store = MemorySecureSessionStore();
      final controller = session(remote, store, now, country: 'NG');

      final result = await controller.signInWithEmail(
        provider: FakeEmailProvider(),
        email: 'customer@example.test',
        secret: 'synthetic-password',
      );

      expect(result.status, IdentitySessionStatus.authenticated);
      expect(store.hasSession, isTrue);
      expect(await controller.accessToken(), 'access-token-1');
    });
  });

  group('session lifecycle', () {
    test('cross-country stored session is purged before restore', () async {
      final store = MemorySecureSessionStore();
      await store.write(authentication(now));
      final remote = FakeRemote(authentication(now));
      final controller = session(remote, store, now, country: 'NG');

      await controller.initialize();

      expect(controller.state.status, IdentitySessionStatus.roleDenied);
      expect(store.hasSession, isFalse);
      expect(await controller.accessToken(), isNull);
      expect(remote.revokedTokens, [
        'refresh-token-00000000000000000000000000000001',
      ]);
    });
    test('cross-country device session is purged before restore', () async {
      final store = MemorySecureSessionStore();
      await store.write(
        authentication(now, country: 'NG', sessionCountry: 'IN'),
      );
      final controller = session(
        FakeRemote(authentication(now, country: 'NG')),
        store,
        now,
        country: 'NG',
      );

      await controller.initialize();

      expect(controller.state.status, IdentitySessionStatus.roleDenied);
      expect(store.hasSession, isFalse);
      expect(await controller.accessToken(), isNull);
    });
    test('restores a valid session while offline', () async {
      final store = MemorySecureSessionStore();
      await store.write(authentication(now));
      final controller = session(
        FakeRemote(authentication(now)),
        store,
        now,
        online: false,
      );

      await controller.initialize();

      expect(
        controller.state.status,
        IdentitySessionStatus.offlineAuthenticated,
      );
      expect(await controller.accessToken(), 'access-token-1');
    });

    test(
      'expired access requires online recovery and preserves refresh',
      () async {
        final store = MemorySecureSessionStore();
        await store.write(
          authentication(
            now,
            accessExpiresAt: now.subtract(const Duration(seconds: 1)),
          ),
        );
        final controller = session(
          FakeRemote(authentication(now)),
          store,
          now,
          online: false,
        );

        await controller.initialize();

        expect(
          controller.state.status,
          IdentitySessionStatus.offlineRecoveryRequired,
        );
        expect(store.hasSession, isTrue);
        expect(await controller.accessToken(), isNull);
      },
    );

    test('expired refresh is purged during restore', () async {
      final store = MemorySecureSessionStore();
      await store.write(
        authentication(
          now,
          refreshExpiresAt: now.subtract(const Duration(seconds: 1)),
        ),
      );
      final controller = session(FakeRemote(authentication(now)), store, now);

      await controller.initialize();

      expect(controller.state.status, IdentitySessionStatus.expired);
      expect(store.hasSession, isFalse);
    });

    test('concurrent refresh calls rotate exactly once', () async {
      final store = MemorySecureSessionStore();
      await store.write(authentication(now));
      final remote = BlockingRemote(
        authentication(now, accessToken: 'access-token-2'),
      );
      final controller = session(remote, store, now);
      await controller.initialize();

      final first = controller.refresh();
      final second = controller.refresh();
      remote.complete();

      expect(await Future.wait([first, second]), [isTrue, isTrue]);
      expect(remote.refreshCalls, 1);
      expect(await controller.accessToken(), 'access-token-2');
    });

    test('refresh denial purges local credentials', () async {
      final store = MemorySecureSessionStore();
      await store.write(authentication(now));
      final remote = FakeRemote(authentication(now))..denyRefresh = true;
      final controller = session(remote, store, now);
      await controller.initialize();

      expect(await controller.refresh(), isFalse);
      expect(controller.state.status, IdentitySessionStatus.signedOut);
      expect(store.hasSession, isFalse);
    });

    test(
      'logout purges locally even when server revoke is unavailable',
      () async {
        final store = MemorySecureSessionStore();
        await store.write(authentication(now));
        final remote = FakeRemote(authentication(now))..failRevoke = true;
        final controller = session(remote, store, now);
        await controller.initialize();

        await controller.signOut();

        expect(controller.state.status, IdentitySessionStatus.signedOut);
        expect(store.hasSession, isFalse);
      },
    );

    test('corrupt storage is cleared without exposing its contents', () async {
      final store = MemorySecureSessionStore()..corruptForTest();
      final controller = session(FakeRemote(authentication(now)), store, now);

      await controller.initialize();

      expect(controller.state.status, IdentitySessionStatus.signedOut);
      expect(store.hasSession, isFalse);
    });
  });

  group('role routing', () {
    test('allows the current app and suggests an available app on denial', () {
      expect(
        IdentityRoleRouter.decide(
          applicationRole: AppRole.customer,
          grantedRoles: {AppRole.customer, AppRole.vendor},
        ).outcome,
        RoleRouteOutcome.allowed,
      );
      final denied = IdentityRoleRouter.decide(
        applicationRole: AppRole.rider,
        grantedRoles: {AppRole.vendor},
      );
      expect(denied.outcome, RoleRouteOutcome.wrongApplication);
      expect(denied.suggestedRole, AppRole.vendor);
    });
  });
}

IdentitySessionController session(
  IdentityRemote remote,
  SecureSessionStore store,
  DateTime now, {
  bool online = true,
  String country = 'IN',
}) => IdentitySessionController(
  remote: remote,
  store: store,
  applicationRole: AppRole.customer,
  deviceId: 'device-install-001',
  country: country,
  connectivity: FixedConnectivity(online),
  clock: () => now,
);

IdentityAuthentication authentication(
  DateTime now, {
  Set<AppRole> roles = const {AppRole.customer},
  DateTime? accessExpiresAt,
  DateTime? refreshExpiresAt,
  String accessToken = 'access-token-1',
  String identityId = 'identity-1',
  String sessionId = 'session-1',
  String country = 'IN',
  String? sessionCountry,
  String refreshToken = 'refresh-token-00000000000000000000000000000001',
}) => IdentityAuthentication(
  identityId: identityId,
  tenantId: 'tenant-1',
  country: country,
  tokens: IdentityTokens(
    accessToken: accessToken,
    accessExpiresAt: accessExpiresAt ?? now.add(const Duration(minutes: 10)),
    refreshToken: refreshToken,
    refreshExpiresAt: refreshExpiresAt ?? now.add(const Duration(days: 30)),
  ),
  profile: IdentityProfile(
    displayName: 'Synthetic Customer',
    locale: 'en',
    timeZone: 'Asia/Kolkata',
    version: 1,
    updatedAt: now,
  ),
  roles: roles,
  session: IdentityDeviceSession(
    id: sessionId,
    deviceReference: 'device-hash-1',
    country: sessionCountry ?? country,
    authenticatedAt: now,
    lastSeenAt: now,
    expiresAt: now.add(const Duration(days: 30)),
    current: true,
  ),
);

final class FixedConnectivity implements ConnectivityProbe {
  const FixedConnectivity(this.online);
  final bool online;

  @override
  Future<bool> isOnline() async => online;
}

class FakeRemote
    implements
        IdentityRemote,
        IdentityEnrollmentRemote,
        IdentityRecoveryRemote {
  FakeRemote(this.next);
  IdentityAuthentication next;
  bool denyRefresh = false;
  bool failRevoke = false;
  final List<ProviderAssertion> exchanges = [];
  final List<String> deviceIds = [];
  final List<String> revokedTokens = [];
  int refreshCalls = 0;
  int recoveryCalls = 0;
  @override
  Future<IdentityAuthentication> recover({
    required ProviderAssertion assertion,
    required String deviceId,
    required String country,
  }) async {
    recoveryCalls++;
    return exchange(assertion: assertion, deviceId: deviceId, country: country);
  }

  final List<AppRole> enrollments = [];
  @override
  Future<IdentityAuthentication> enroll({
    required ProviderAssertion assertion,
    required String deviceId,
    required String country,
    required AppRole role,
  }) async {
    enrollments.add(role);
    return exchange(assertion: assertion, deviceId: deviceId, country: country);
  }

  @override
  Future<IdentityAuthentication> exchange({
    required ProviderAssertion assertion,
    required String deviceId,
    required String country,
  }) async {
    exchanges.add(assertion);
    deviceIds.add(deviceId);
    return next;
  }

  @override
  Future<IdentityAuthentication> refresh(String refreshToken) async {
    refreshCalls++;
    if (denyRefresh) {
      throw const ApiAuthenticationFailure(
        code: 'AUTHENTICATION_EXPIRED',
        message: 'Sign in again.',
        correlationId: 'corr-test',
      );
    }
    return next;
  }

  @override
  Future<void> revoke(String refreshToken) async {
    revokedTokens.add(refreshToken);
    if (failRevoke) throw StateError('offline');
  }
}

final class BlockingRemote extends FakeRemote {
  BlockingRemote(super.next);
  final Completer<void> _release = Completer<void>();

  void complete() => _release.complete();

  @override
  Future<IdentityAuthentication> refresh(String refreshToken) async {
    refreshCalls++;
    await _release.future;
    return next;
  }
}

final class FakePhoneProvider implements PhoneOtpProvider {
  @override
  Future<String> requestCode({required String phoneNumber}) async =>
      'challenge-1';

  @override
  Future<ProviderAssertion> verifyCode({
    required String challengeId,
    required String code,
  }) async => ProviderAssertion(
    provider: IdentityProviderKind.firebase,
    token: 'firebase-provider-assertion',
  );
}

final class FakeEmailProvider
    implements EmailIdentityProvider, EmailRegistrationProvider {
  @override
  Future<ProviderAssertion> register({
    required String email,
    required String secret,
  }) => authenticate(email: email, secret: secret);
  @override
  Future<ProviderAssertion> authenticate({
    required String email,
    required String secret,
  }) async => ProviderAssertion(
    provider: IdentityProviderKind.local,
    token: 'local-provider-assertion',
  );
}

final class FakeOAuthProvider implements OAuthIdentityProvider {
  @override
  Future<ProviderAssertion> authenticate(OAuthVendor vendor) async =>
      ProviderAssertion(
        provider: IdentityProviderKind.oidc,
        token: 'oidc-provider-assertion',
      );
}
