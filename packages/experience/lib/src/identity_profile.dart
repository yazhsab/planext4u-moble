import 'package:flutter/foundation.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_core/planext4u_core.dart';
import 'package:planext4u_identity/planext4u_identity.dart';

enum IdentityProfileStatus {
  idle,
  loading,
  ready,
  saving,
  conflict,
  offline,
  failure,
}

final class IdentityProfileState {
  const IdentityProfileState({
    this.status = IdentityProfileStatus.idle,
    this.current,
    this.message,
  });

  final IdentityProfileStatus status;
  final CurrentIdentityProfile? current;
  final String? message;

  bool get busy =>
      status == IdentityProfileStatus.loading ||
      status == IdentityProfileStatus.saving;
}

final class IdentityProfileController extends ChangeNotifier {
  IdentityProfileController({
    required AppRole expectedRole,
    required IdentityProfileRemote remote,
  }) : _expectedRole = expectedRole,
       _remote = remote;

  final AppRole _expectedRole;
  final IdentityProfileRemote _remote;
  IdentityProfileState _state = const IdentityProfileState();

  AppRole get expectedRole => _expectedRole;
  IdentityProfileState get state => _state;

  Future<void> load() async {
    if (_state.busy) return;
    _set(
      IdentityProfileState(
        status: IdentityProfileStatus.loading,
        current: _state.current,
      ),
    );
    try {
      final current = await _remote.current();
      _validateScope(current);
      _set(
        IdentityProfileState(
          status: IdentityProfileStatus.ready,
          current: current,
        ),
      );
    } on ApiTransportFailure {
      _unavailable(
        IdentityProfileStatus.offline,
        'Reconnect to review your profile.',
      );
    } on ApiTimeoutFailure {
      _unavailable(
        IdentityProfileStatus.offline,
        'The profile request timed out. Check your connection.',
      );
    } catch (_) {
      _unavailable(
        IdentityProfileStatus.failure,
        'Your profile could not be loaded safely.',
      );
    }
  }

  Future<void> save({
    required String displayName,
    required String locale,
    required String timeZone,
  }) async {
    final current = _state.current;
    if (current == null || _state.busy) return;
    final name = displayName.trim();
    final localeCode = locale.trim();
    final zone = timeZone.trim();
    if (name.isEmpty ||
        name.length > 100 ||
        !isPlanext4uLocaleCode(localeCode) ||
        zone.isEmpty ||
        zone.length > 64 ||
        !RegExp(r'^[A-Za-z0-9._+\-/]+$').hasMatch(zone)) {
      throw const FormatException('Profile update is invalid.');
    }
    _set(
      IdentityProfileState(
        status: IdentityProfileStatus.saving,
        current: current,
      ),
    );
    try {
      final updated = await _remote.update(
        current: current.profile,
        displayName: name,
        locale: localeCode,
        timeZone: zone,
      );
      if (updated.displayName != name ||
          updated.locale != localeCode ||
          updated.timeZone != zone ||
          updated.version <= current.profile.version ||
          updated.email != current.profile.email ||
          updated.phone != current.profile.phone) {
        throw const FormatException('Updated profile contract is invalid.');
      }
      _set(
        IdentityProfileState(
          status: IdentityProfileStatus.ready,
          current: _withProfile(current, updated),
          message: 'Profile changes saved.',
        ),
      );
    } on ApiConflictFailure {
      await _recoverConflict(current);
    } on ApiTransportFailure {
      _unavailable(
        IdentityProfileStatus.offline,
        'The profile was not changed. Reconnect and try again.',
      );
    } on ApiTimeoutFailure {
      _unavailable(
        IdentityProfileStatus.offline,
        'The profile update timed out. Refresh before trying again.',
      );
    } catch (_) {
      _unavailable(
        IdentityProfileStatus.failure,
        'The profile was not changed. Refresh before trying again.',
      );
    }
  }

  void clearMessage() {
    if (_state.message == null) return;
    _set(IdentityProfileState(status: _state.status, current: _state.current));
  }

  Future<void> _recoverConflict(CurrentIdentityProfile previous) async {
    try {
      final current = await _remote.current();
      _validateScope(current);
      _set(
        IdentityProfileState(
          status: IdentityProfileStatus.conflict,
          current: current,
          message:
              'This profile changed on another device. Review the latest values before saving again.',
        ),
      );
    } catch (_) {
      _set(
        IdentityProfileState(
          status: IdentityProfileStatus.conflict,
          current: previous,
          message:
              'This profile changed on another device. Refresh before saving again.',
        ),
      );
    }
  }

  void _validateScope(CurrentIdentityProfile current) {
    if (!current.roles.contains(_expectedRole)) {
      throw const FormatException('Profile belongs to another role scope.');
    }
  }

  void _unavailable(IdentityProfileStatus status, String message) {
    _set(
      IdentityProfileState(
        status: status,
        current: _state.current,
        message: message,
      ),
    );
  }

  void _set(IdentityProfileState value) {
    _state = value;
    notifyListeners();
  }
}

CurrentIdentityProfile _withProfile(
  CurrentIdentityProfile current,
  IdentityProfile profile,
) => CurrentIdentityProfile(
  identityId: current.identityId,
  tenantId: current.tenantId,
  country: current.country,
  roles: current.roles,
  profile: profile,
);
