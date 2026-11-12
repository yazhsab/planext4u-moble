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
  Future<void>? _initializeInFlight;
  Future<void> _storeTail = Future.value();
  int _epoch = 0;
  int _refreshEpoch = -1;
  bool _disposed = false;
  ({String session, String tenant, String country, String identity})?
  _interactiveProof;
  ({String session, String tenant, String country, String identity}) _proof(
    IdentityAuthentication value,
  ) => (
    session: value.session.id,
    tenant: value.tenantId,
    country: value.country,
    identity: value.identityId,
  );

  IdentitySessionState get state => _state;
  Stream<IdentitySessionState> get states => _states.stream;

  /// Only a newly accepted interactive provider exchange can satisfy local
  /// unlock recovery. Restore and refresh never create this proof.
  bool get hasFreshInteractiveAuthentication {
    final authentication = _state.authentication;
    if (_disposed ||
        authentication == null ||
        _proof(authentication) != _interactiveProof) {
      return false;
    }
    final now = _clock().toUtc();
    final authenticatedAt = authentication.session.authenticatedAt;
    return !authenticatedAt.isBefore(
          now.subtract(const Duration(minutes: 5)),
        ) &&
        !authenticatedAt.isAfter(now.add(const Duration(seconds: 30)));
  }

  bool _current(int epoch) => !_disposed && epoch == _epoch;
  Future<T> _serializeStore<T>(Future<T> Function() operation) {
    final result = _storeTail.then((_) => operation());
    _storeTail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  Future<void> _clearAt(int epoch) => _serializeStore(() async {
    if (_current(epoch)) await _store.clear();
  });
  Future<bool> _saveAt(int epoch, IdentityAuthentication value) =>
      _serializeStore(() async {
        if (!_current(epoch)) return false;
        await _store.write(value);
        return _current(epoch);
      });
  IdentitySessionState _emitAt(int epoch, IdentitySessionState next) =>
      _current(epoch) ? _emit(next) : _state;
  Future<void> _revokeOrphan(IdentityAuthentication value) async {
    if (_state.authentication?.session.id != value.session.id) {
      await _bestEffortRevoke(value.tokens.refreshToken);
    }
  }

  Future<void> initialize() {
    final active = _initializeInFlight;
    if (active != null) return active;
    if (_disposed || _state.status != IdentitySessionStatus.uninitialized) {
      return Future.value();
    }
    final operation = _initialize(++_epoch);
    _initializeInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_initializeInFlight, operation)) _initializeInFlight = null;
    });
  }

  Future<void> _initialize(int epoch) async {
    IdentityAuthentication? restored;
    try {
      restored = await _serializeStore(_store.read);
    } catch (_) {
      _emitAt(
        epoch,
        const IdentitySessionState(status: IdentitySessionStatus.signedOut),
      );
      return;
    }
    if (!_current(epoch)) return;
    if (restored == null) {
      _emitAt(
        epoch,
        const IdentitySessionState(status: IdentitySessionStatus.signedOut),
      );
      return;
    }
    if (!_roleAllowed(restored)) {
      await _clearAt(epoch);
      _emitAt(
        epoch,
        const IdentitySessionState(status: IdentitySessionStatus.roleDenied),
      );
      await _revokeOrphan(restored);
      return;
    }
    final now = _clock().toUtc();
    if (!restored.tokens.refreshExpiresAt.isAfter(now)) {
      await _clearAt(epoch);
      _emitAt(
        epoch,
        const IdentitySessionState(status: IdentitySessionStatus.expired),
      );
      return;
    }
    if (restored.tokens.accessExpiresAt.isAfter(now.add(refreshSkew))) {
      final online = await _connectivity.isOnline();
      _emitAt(
        epoch,
        IdentitySessionState(
          status: online
              ? IdentitySessionStatus.authenticated
              : IdentitySessionStatus.offlineAuthenticated,
          authentication: restored,
        ),
      );
      return;
    }
    _emitAt(
      epoch,
      IdentitySessionState(
        status: IdentitySessionStatus.offlineRecoveryRequired,
        authentication: restored,
      ),
    );
    if (_current(epoch)) await refresh();
  }

  Future<IdentitySessionState> signInWithPhoneOtp({
    required PhoneOtpProvider provider,
    required String challengeId,
    required String code,
    bool recoverAccount = false,
  }) async => _signIn(
    () => provider.verifyCode(challengeId: challengeId, code: code),
    enroll: true,
    recover: recoverAccount,
  );

  Future<IdentitySessionState> signInWithEmail({
    required EmailIdentityProvider provider,
    required String email,
    required String secret,
    bool recoverAccount = false,
  }) async => _signIn(
    () => provider.authenticate(email: email, secret: secret),
    recover: recoverAccount,
  );

  Future<IdentitySessionState> registerWithEmail({
    required EmailRegistrationProvider provider,
    required String email,
    required String secret,
  }) async => _signIn(
    () => provider.register(email: email, secret: secret),
    enroll: true,
  );

  Future<IdentitySessionState> signInWithOAuth({
    required OAuthIdentityProvider provider,
    required OAuthVendor vendor,
    bool recoverAccount = false,
  }) async =>
      _signIn(() => provider.authenticate(vendor), recover: recoverAccount);

  Future<IdentitySessionState> _signIn(
    Future<ProviderAssertion> Function() acquire, {
    bool enroll = false,
    bool recover = false,
  }) async {
    if (_disposed) return _state;
    final previous = _state.authentication;
    final epoch = ++_epoch;
    _emitAt(
      epoch,
      const IdentitySessionState(status: IdentitySessionStatus.authenticating),
    );
    try {
      IdentityAuthentication? persisted;
      try {
        await _serializeStore(() async {
          if (!_current(epoch)) return;
          final value = await _store.read();
          if (!_current(epoch)) return;
          persisted = value;
          await _store.clear();
        });
      } finally {
        final retiredTokens = {
          if (previous != null) previous.tokens.refreshToken,
          if (persisted != null) persisted!.tokens.refreshToken,
        };
        for (final token in retiredTokens) {
          await _bestEffortRevoke(token);
        }
      }
      if (!_current(epoch)) return _state;
      final assertion = await acquire();
      if (!_current(epoch)) return _state;
      final remote = _remote;
      if (recover && remote is! IdentityRecoveryRemote) {
        throw UnsupportedError('Account recovery is unavailable.');
      }
      if (enroll && !recover && remote is! IdentityEnrollmentRemote) {
        throw UnsupportedError('Participation enrollment is unavailable.');
      }
      final authentication = recover
          ? await (remote as IdentityRecoveryRemote).recover(
              assertion: assertion,
              deviceId: _deviceId,
              country: _country,
            )
          : enroll && remote is IdentityEnrollmentRemote
          ? await (remote as IdentityEnrollmentRemote).enroll(
              assertion: assertion,
              deviceId: _deviceId,
              country: _country,
              role: _applicationRole,
            )
          : await _remote.exchange(
              assertion: assertion,
              deviceId: _deviceId,
              country: _country,
            );
      if (!_current(epoch)) {
        await _revokeOrphan(authentication);
        return _state;
      }
      if (!_roleAllowed(authentication)) {
        await _bestEffortRevoke(authentication.tokens.refreshToken);
        await _clearAt(epoch);
        return _emitAt(
          epoch,
          const IdentitySessionState(status: IdentitySessionStatus.roleDenied),
        );
      }
      try {
        if (!await _saveAt(epoch, authentication)) {
          await _revokeOrphan(authentication);
          return _state;
        }
      } catch (_) {
        await _revokeOrphan(authentication);
        rethrow;
      }
      _interactiveProof = _proof(authentication);
      return _emitAt(
        epoch,
        IdentitySessionState(
          status: IdentitySessionStatus.authenticated,
          authentication: authentication,
        ),
      );
    } catch (_) {
      if (!_current(epoch)) return _state;
      try {
        await _clearAt(epoch);
      } finally {
        _emitAt(
          epoch,
          const IdentitySessionState(status: IdentitySessionStatus.signedOut),
        );
      }
      rethrow;
    }
  }

  @override
  Future<String?> accessToken() async {
    if (_disposed) return null;
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
    if (active != null && _refreshEpoch == _epoch) return active;
    if (_disposed) return Future.value(false);
    _refreshEpoch = _epoch;
    final operation = _performRefresh(_epoch);
    _refreshInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_refreshInFlight, operation)) _refreshInFlight = null;
    });
  }

  Future<bool> _performRefresh(int epoch) async {
    final authentication = _state.authentication;
    if (authentication == null || !_roleAllowed(authentication)) return false;
    final now = _clock().toUtc();
    if (!authentication.tokens.refreshExpiresAt.isAfter(now)) {
      await _clearAt(epoch);
      _emitAt(
        epoch,
        const IdentitySessionState(status: IdentitySessionStatus.expired),
      );
      return false;
    }
    if (!await _connectivity.isOnline()) {
      _emitAt(
        epoch,
        IdentitySessionState(
          status: authentication.tokens.accessExpiresAt.isAfter(now)
              ? IdentitySessionStatus.offlineAuthenticated
              : IdentitySessionStatus.offlineRecoveryRequired,
          authentication: authentication,
        ),
      );
      return false;
    }
    if (!_current(epoch)) return false;
    try {
      final rotated = await _remote.refresh(authentication.tokens.refreshToken);
      if (!_current(epoch)) {
        await _revokeOrphan(rotated);
        return false;
      }
      if (!_roleAllowed(rotated) ||
          rotated.session.id != authentication.session.id ||
          rotated.identityId != authentication.identityId ||
          rotated.tenantId != authentication.tenantId ||
          rotated.country != authentication.country) {
        _emitAt(
          epoch,
          const IdentitySessionState(status: IdentitySessionStatus.roleDenied),
        );
        try {
          await _clearAt(epoch);
        } catch (_) {
          // Keep the in-memory session denied even if secure storage fails.
        }
        await _bestEffortRevoke(rotated.tokens.refreshToken);
        if (rotated.tokens.refreshToken != authentication.tokens.refreshToken) {
          await _bestEffortRevoke(authentication.tokens.refreshToken);
        }
        return false;
      }
      if (!await _saveAt(epoch, rotated)) {
        await _revokeOrphan(rotated);
        return false;
      }
      _emitAt(
        epoch,
        IdentitySessionState(
          status: IdentitySessionStatus.authenticated,
          authentication: rotated,
        ),
      );
      return _current(epoch);
    } on ApiAuthenticationFailure {
      await _clearAt(epoch);
      _emitAt(
        epoch,
        const IdentitySessionState(status: IdentitySessionStatus.signedOut),
      );
      return false;
    } catch (_) {
      _emitAt(
        epoch,
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
    final epoch = ++_epoch;
    _emit(const IdentitySessionState(status: IdentitySessionStatus.signedOut));
    try {
      await _clearAt(epoch);
    } finally {
      if (refreshToken != null) await _bestEffortRevoke(refreshToken);
    }
  }

  Future<void> _bestEffortRevoke(String refreshToken) async {
    try {
      await _remote.revoke(refreshToken);
    } catch (_) {
      // Local credentials are purged even when the network revoke is unavailable.
    }
  }

  bool _roleAllowed(IdentityAuthentication authentication) =>
      authentication.country == _country &&
      authentication.session.country == _country &&
      IdentityRoleRouter.decide(
        applicationRole: _applicationRole,
        grantedRoles: authentication.roles,
      ).isAllowed;

  IdentitySessionState _emit(IdentitySessionState next) {
    if (next.authentication == null ||
        _proof(next.authentication!) != _interactiveProof) {
      _interactiveProof = null;
    }
    _state = next;
    if (!_states.isClosed) _states.add(next);
    return next;
  }

  Future<void> dispose() {
    _disposed = true;
    _epoch++;
    return _states.close();
  }
}

DateTime _utcNow() => DateTime.now().toUtc();
