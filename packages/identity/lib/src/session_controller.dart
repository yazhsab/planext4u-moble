import 'dart:async';

import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_core/planext4u_core.dart';

import 'identity_api.dart';
import 'identity_models.dart';
import 'identity_providers.dart';
import 'role_router.dart';
import 'session_store.dart';

enum IdentitySessionStatus {
  uninitialized,
  signedOut,
  authenticating,
  authenticated,
  offlineAuthenticated,
  offlineRecoveryRequired,
  roleDenied,
  expired,
}

final class IdentitySessionState {
  const IdentitySessionState({required this.status, this.authentication});

  final IdentitySessionStatus status;
  final IdentityAuthentication? authentication;
}

abstract interface class ConnectivityProbe {
  Future<bool> isOnline();
}

final class AlwaysOnlineConnectivity implements ConnectivityProbe {
  const AlwaysOnlineConnectivity();

  @override
  Future<bool> isOnline() async => true;
}

typedef IdentityClock = DateTime Function();

final class IdentitySessionController implements ApiAuthSession {
  IdentitySessionController({
    required IdentityRemote remote,
    required SecureSessionStore store,
    required AppRole applicationRole,
    required String deviceId,
    required String country,
    ConnectivityProbe connectivity = const AlwaysOnlineConnectivity(),
    IdentityClock clock = _utcNow,
    this.refreshSkew = const Duration(minutes: 1),
  }) : _remote = remote,
       _store = store,
       _applicationRole = applicationRole,
       _deviceId = deviceId,
       _country = country,
       _connectivity = connectivity,
       _clock = clock {
    if (deviceId.isEmpty || !RegExp(r'^[A-Z]{2}$').hasMatch(country)) {
      throw const FormatException('Identity device configuration is invalid.');
    }
  }

  final IdentityRemote _remote;
  final SecureSessionStore _store;
  final AppRole _applicationRole;
  final String _deviceId;
  final String _country;
  final ConnectivityProbe _connectivity;
  final IdentityClock _clock;
  final Duration refreshSkew;
  final StreamController<IdentitySessionState> _states =
      StreamController.broadcast(sync: true);

  IdentitySessionState _state = const IdentitySessionState(
    status: IdentitySessionStatus.uninitialized,
  );
  Future<bool>? _refreshInFlight;

  IdentitySessionState get state => _state;
  Stream<IdentitySessionState> get states => _states.stream;

  Future<void> initialize() async {
    if (_state.status != IdentitySessionStatus.uninitialized) return;
    IdentityAuthentication? restored;
    try {
      restored = await _store.read();
    } catch (_) {
      _emit(
        const IdentitySessionState(status: IdentitySessionStatus.signedOut),
      );
      return;
    }
    if (restored == null) {
      _emit(
        const IdentitySessionState(status: IdentitySessionStatus.signedOut),
      );
      return;
    }
    if (!_roleAllowed(restored)) {
      _emit(
        IdentitySessionState(
          status: IdentitySessionStatus.roleDenied,
          authentication: restored,
        ),
      );
      return;
    }
    final now = _clock().toUtc();
    if (!restored.tokens.refreshExpiresAt.isAfter(now)) {
      await _store.clear();
      _emit(const IdentitySessionState(status: IdentitySessionStatus.expired));
      return;
    }
    if (restored.tokens.accessExpiresAt.isAfter(now.add(refreshSkew))) {
      final online = await _connectivity.isOnline();
      _emit(
        IdentitySessionState(
          status: online
              ? IdentitySessionStatus.authenticated
              : IdentitySessionStatus.offlineAuthenticated,
          authentication: restored,
        ),
      );
      return;
    }
    _emit(
      IdentitySessionState(
        status: IdentitySessionStatus.offlineRecoveryRequired,
        authentication: restored,
      ),
    );
    await refresh();
  }

  Future<IdentitySessionState> signInWithPhoneOtp({
    required PhoneOtpProvider provider,
    required String challengeId,
    required String code,
  }) async =>
      _signIn(() => provider.verifyCode(challengeId: challengeId, code: code));

  Future<IdentitySessionState> signInWithEmail({
    required EmailIdentityProvider provider,
    required String email,
    required String secret,
  }) async =>
      _signIn(() => provider.authenticate(email: email, secret: secret));

  Future<IdentitySessionState> signInWithOAuth({
    required OAuthIdentityProvider provider,
    required OAuthVendor vendor,
  }) async => _signIn(() => provider.authenticate(vendor));

  Future<IdentitySessionState> _signIn(
    Future<ProviderAssertion> Function() acquire,
  ) async {
    _emit(
      const IdentitySessionState(status: IdentitySessionStatus.authenticating),
    );
    try {
      final assertion = await acquire();
      final authentication = await _remote.exchange(
        assertion: assertion,
        deviceId: _deviceId,
        country: _country,
      );
      if (!_roleAllowed(authentication)) {
        await _bestEffortRevoke(authentication.tokens.refreshToken);
        await _store.clear();
        return _emit(
          const IdentitySessionState(status: IdentitySessionStatus.roleDenied),
        );
      }
      await _store.write(authentication);
      return _emit(
        IdentitySessionState(
          status: IdentitySessionStatus.authenticated,
          authentication: authentication,
        ),
      );
    } catch (_) {
      _emit(
        const IdentitySessionState(status: IdentitySessionStatus.signedOut),
      );
      rethrow;
    }
  }

  @override
  Future<String?> accessToken() async {
    if (_state.status == IdentitySessionStatus.uninitialized) {
      await initialize();
    }
    final authentication = _state.authentication;
    if (authentication == null || !_roleAllowed(authentication)) return null;
    final now = _clock().toUtc();
    if (!authentication.tokens.accessExpiresAt.isAfter(now.add(refreshSkew))) {
      final refreshed = await refresh();
      if (!refreshed) {
        final current = _state.authentication;
        if (current != null && current.tokens.accessExpiresAt.isAfter(now)) {
          return current.tokens.accessToken;
        }
        return null;
      }
    }
    return _state.authentication?.tokens.accessToken;
  }

  @override
  Future<bool> refresh() {
    final active = _refreshInFlight;
    if (active != null) return active;
    final operation = _performRefresh();
    _refreshInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_refreshInFlight, operation)) _refreshInFlight = null;
    });
  }

  Future<bool> _performRefresh() async {
    final authentication = _state.authentication;
    if (authentication == null || !_roleAllowed(authentication)) return false;
    final now = _clock().toUtc();
    if (!authentication.tokens.refreshExpiresAt.isAfter(now)) {
      await _store.clear();
      _emit(const IdentitySessionState(status: IdentitySessionStatus.expired));
      return false;
    }
    if (!await _connectivity.isOnline()) {
      _emit(
        IdentitySessionState(
          status: authentication.tokens.accessExpiresAt.isAfter(now)
              ? IdentitySessionStatus.offlineAuthenticated
              : IdentitySessionStatus.offlineRecoveryRequired,
          authentication: authentication,
        ),
      );
      return false;
    }
    try {
      final rotated = await _remote.refresh(authentication.tokens.refreshToken);
      if (!_roleAllowed(rotated) ||
          rotated.session.id != authentication.session.id) {
        await _store.clear();
        _emit(
          const IdentitySessionState(status: IdentitySessionStatus.roleDenied),
        );
        return false;
      }
      await _store.write(rotated);
      _emit(
        IdentitySessionState(
          status: IdentitySessionStatus.authenticated,
          authentication: rotated,
        ),
      );
      return true;
    } on ApiAuthenticationFailure {
      await _store.clear();
      _emit(
        const IdentitySessionState(status: IdentitySessionStatus.signedOut),
      );
      return false;
    } catch (_) {
      _emit(
        IdentitySessionState(
          status: authentication.tokens.accessExpiresAt.isAfter(now)
              ? IdentitySessionStatus.offlineAuthenticated
              : IdentitySessionStatus.offlineRecoveryRequired,
          authentication: authentication,
        ),
      );
      return false;
    }
  }

  Future<void> signOut() async {
    final refreshToken = _state.authentication?.tokens.refreshToken;
    await _store.clear();
    _emit(const IdentitySessionState(status: IdentitySessionStatus.signedOut));
    if (refreshToken != null) await _bestEffortRevoke(refreshToken);
  }

  Future<void> _bestEffortRevoke(String refreshToken) async {
    try {
      await _remote.revoke(refreshToken);
    } catch (_) {
      // Local credentials are purged even when the network revoke is unavailable.
    }
  }

  bool _roleAllowed(IdentityAuthentication authentication) =>
      IdentityRoleRouter.decide(
        applicationRole: _applicationRole,
        grantedRoles: authentication.roles,
      ).isAllowed;

  IdentitySessionState _emit(IdentitySessionState next) {
    _state = next;
    if (!_states.isClosed) _states.add(next);
    return next;
  }

  Future<void> dispose() => _states.close();
}

DateTime _utcNow() => DateTime.now().toUtc();
