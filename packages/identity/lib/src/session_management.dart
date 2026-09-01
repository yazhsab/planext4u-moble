import 'package:flutter/foundation.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';

import 'identity_models.dart';

abstract interface class IdentitySessionManagementRemote {
  Future<List<IdentityDeviceSession>> sessions();

  Future<void> revokeSession(String sessionId);
}

final class IdentitySessionManagementApi
    implements IdentitySessionManagementRemote {
  const IdentitySessionManagementApi(this._client);

  final ApiClient _client;

  @override
  Future<List<IdentityDeviceSession>> sessions() async {
    final response = await _client.send(
      ApiRequest.get(
        operation: 'identity.list_current_sessions',
        path: '/v1/me/sessions',
      ),
      (value) {
        if (value is! Map<String, Object?> ||
            value['sessions'] is! List<Object?>) {
          throw const FormatException('Identity sessions contract is invalid.');
        }
        return List<IdentityDeviceSession>.unmodifiable(
          (value['sessions']! as List<Object?>).map(
            IdentityDeviceSession.fromJson,
          ),
        );
      },
    );
    return response.value;
  }

  @override
  Future<void> revokeSession(String sessionId) async {
    if (!_safeSessionId.hasMatch(sessionId)) {
      throw const FormatException('Identity session ID is invalid.');
    }
    await _client.send<void>(
      ApiRequest.command(
        operation: 'identity.revoke_owned_session',
        method: 'DELETE',
        path: '/v1/me/sessions/${Uri.encodeComponent(sessionId)}',
        body: null,
      ),
      (_) {},
    );
  }
}

enum IdentitySessionManagementStatus {
  idle,
  loading,
  ready,
  revoking,
  offline,
  failure,
}

final class IdentitySessionManagementState {
  const IdentitySessionManagementState({
    this.status = IdentitySessionManagementStatus.idle,
    this.sessions = const [],
    this.message,
  });

  final IdentitySessionManagementStatus status;
  final List<IdentityDeviceSession> sessions;
  final String? message;
}

final class IdentitySessionManagementController extends ChangeNotifier {
  IdentitySessionManagementController(this._remote);

  final IdentitySessionManagementRemote _remote;
  IdentitySessionManagementState _state =
      const IdentitySessionManagementState();

  IdentitySessionManagementState get state => _state;

  Future<void> load() async {
    if (_state.status == IdentitySessionManagementStatus.loading ||
        _state.status == IdentitySessionManagementStatus.revoking) {
      return;
    }
    _set(
      IdentitySessionManagementState(
        status: IdentitySessionManagementStatus.loading,
        sessions: _state.sessions,
      ),
    );
    try {
      final values = await _remote.sessions();
      _set(
        IdentitySessionManagementState(
          status: IdentitySessionManagementStatus.ready,
          sessions: List.unmodifiable(values),
        ),
      );
    } on ApiTransportFailure {
      _set(
        IdentitySessionManagementState(
          status: IdentitySessionManagementStatus.offline,
          sessions: _state.sessions,
          message: 'Reconnect to review signed-in devices.',
        ),
      );
    } catch (_) {
      _set(
        IdentitySessionManagementState(
          status: IdentitySessionManagementStatus.failure,
          sessions: _state.sessions,
          message: 'Signed-in devices could not be loaded safely.',
        ),
      );
    }
  }

  Future<void> revokeSession(IdentityDeviceSession session) async {
    if (session.current ||
        session.revokedAt != null ||
        !_safeSessionId.hasMatch(session.id) ||
        !_state.sessions.any((value) => value.id == session.id)) {
      throw const FormatException('This identity session cannot be revoked.');
    }
    if (_state.status == IdentitySessionManagementStatus.revoking) return;
    _set(
      IdentitySessionManagementState(
        status: IdentitySessionManagementStatus.revoking,
        sessions: _state.sessions,
      ),
    );
    try {
      await _remote.revokeSession(session.id);
      _set(
        IdentitySessionManagementState(
          status: IdentitySessionManagementStatus.ready,
          sessions: List.unmodifiable(
            _state.sessions.where((value) => value.id != session.id),
          ),
          message: 'The selected device session was signed out.',
        ),
      );
    } on ApiTransportFailure {
      _set(
        IdentitySessionManagementState(
          status: IdentitySessionManagementStatus.offline,
          sessions: _state.sessions,
          message: 'Reconnect before signing out another device.',
        ),
      );
    } catch (_) {
      _set(
        IdentitySessionManagementState(
          status: IdentitySessionManagementStatus.failure,
          sessions: _state.sessions,
          message: 'The selected device could not be signed out safely.',
        ),
      );
    }
  }

  void _set(IdentitySessionManagementState value) {
    _state = value;
    notifyListeners();
  }
}

final RegExp _safeSessionId = RegExp(r'^[A-Za-z0-9._:-]{1,128}$');
