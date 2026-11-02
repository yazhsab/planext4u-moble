import 'package:flutter/foundation.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';

import 'phase5.dart' show AccountDeletionRequest;

final class AccountLifecycleInfo {
  const AccountLifecycleInfo({required this.status, this.deletion});
  factory AccountLifecycleInfo.fromJson(Object? value) {
    if (value is! Map<String, Object?> ||
        !const {'ACTIVE', 'DELETION_SCHEDULED'}.contains(value['status'])) {
      throw const FormatException('Account lifecycle is invalid.');
    }
    final status = value['status']! as String;
    final rawDeletion = value['deletion'];
    if ((status == 'ACTIVE' && rawDeletion != null) ||
        (status == 'DELETION_SCHEDULED' && rawDeletion == null)) {
      throw const FormatException('Account lifecycle is invalid.');
    }
    return AccountLifecycleInfo(
      status: status,
      deletion: rawDeletion == null
          ? null
          : AccountDeletionRequest.fromJson(rawDeletion),
    );
  }
  final String status;
  final AccountDeletionRequest? deletion;
}

abstract interface class AccountLifecycleRemote {
  Future<AccountLifecycleInfo> getLifecycle();
  Future<void> deactivate();
  Future<void> cancelDeletion(String requestId);
}

final class AccountLifecycleApi implements AccountLifecycleRemote {
  const AccountLifecycleApi(this._client);
  final ApiClient _client;
  @override
  Future<AccountLifecycleInfo> getLifecycle() async => (await _client.send(
    ApiRequest.get(operation: 'identity.lifecycle', path: '/v1/me/lifecycle'),
    AccountLifecycleInfo.fromJson,
  )).value;
  @override
  Future<void> deactivate() async {
    await _client.send<void>(
      ApiRequest(
        operation: 'identity.deactivate_account',
        method: 'POST',
        path: '/v1/me/deactivation',
        body: const {'confirmation': 'DEACTIVATE MY ACCOUNT'},
        replayPolicy: ApiReplayPolicy.never,
      ),
      (_) {},
    );
  }

  @override
  Future<void> cancelDeletion(String requestId) async {
    if (!RegExp(r'^[A-Za-z0-9._:-]{1,128}$').hasMatch(requestId)) {
      throw const FormatException('Deletion reference is invalid.');
    }
    await _client.send<void>(
      ApiRequest(
        operation: 'identity.cancel_deletion',
        method: 'POST',
        path: '/v1/me/deletion-requests/$requestId/cancel',
        body: const {'confirmation': 'CANCEL DELETION'},
        replayPolicy: ApiReplayPolicy.never,
      ),
      (_) {},
    );
  }
}

final class AccountLifecycleController extends ChangeNotifier {
  AccountLifecycleController(
    this._remote, {
    Future<void> Function()? onDeactivated,
  }) : _onDeactivated = onDeactivated;
  final AccountLifecycleRemote _remote;
  final Future<void> Function()? _onDeactivated;
  AccountLifecycleInfo? _info;
  String? _message;
  bool _busy = false;
  bool _disposed = false;
  AccountLifecycleInfo? get info => _info;
  String? get message => _message;
  bool get busy => _busy;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void scheduled(AccountDeletionRequest deletion) {
    _info = AccountLifecycleInfo(
      status: 'DELETION_SCHEDULED',
      deletion: deletion,
    );
    _notify();
  }

  Future<void> load() async {
    if (_busy || _disposed) return;
    _busy = true;
    _message = null;
    _notify();
    try {
      final value = await _remote.getLifecycle();
      if (!_disposed) _info = value;
    } catch (error) {
      _message = error is ApiFailure
          ? error.message
          : 'Account status could not be loaded.';
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<void> cancelDeletion() async {
    final deletion = _info?.deletion;
    if (_busy || _disposed || deletion == null) return;
    _busy = true;
    _message = null;
    _notify();
    try {
      await _remote.cancelDeletion(deletion.id);
      if (_disposed) return;
      _info = const AccountLifecycleInfo(status: 'ACTIVE');
      _message = 'Account deletion cancelled.';
    } catch (error) {
      _message = error is ApiFailure
          ? error.message
          : 'Account deletion could not be cancelled.';
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<void> deactivate() async {
    if (_busy || _disposed) return;
    _busy = true;
    _message = null;
    _notify();
    try {
      await _remote.deactivate();
    } catch (error) {
      _busy = false;
      _message = error is ApiFailure
          ? error.message
          : 'Use a fresh sign-in and retry account deactivation.';
      _notify();
      return;
    }
    if (_disposed) return;
    _busy = false;
    _message = 'Account deactivated.';
    _notify();
    await _onDeactivated?.call();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
