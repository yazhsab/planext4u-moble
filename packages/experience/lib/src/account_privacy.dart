import 'package:flutter/foundation.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';

import 'phase5.dart';

enum AccountPrivacyStatus { idle, submitting, ready, failure }

final class AccountPrivacyState {
  const AccountPrivacyState({
    this.status = AccountPrivacyStatus.idle,
    this.message,
  });

  final AccountPrivacyStatus status;
  final String? message;

  bool get busy => status == AccountPrivacyStatus.submitting;
}

final class AccountPrivacyController extends ChangeNotifier {
  AccountPrivacyController(this._remote);

  final AccountPrivacyRemote _remote;
  AccountPrivacyState _state = const AccountPrivacyState();

  AccountPrivacyState get state => _state;

  Future<AccountDataExport?> exportAccountData() async {
    if (_state.busy) return null;
    _set(const AccountPrivacyState(status: AccountPrivacyStatus.submitting));
    try {
      final result = await _remote.exportAccountData();
      _set(
        const AccountPrivacyState(
          status: AccountPrivacyStatus.ready,
          message: 'Account data export generated.',
        ),
      );
      return result;
    } catch (error) {
      _fail(error, 'Your account data could not be exported.');
      return null;
    }
  }

  Future<AccountDeletionRequest?> requestAccountDeletion(String reason) async {
    if (_state.busy) return null;
    _set(const AccountPrivacyState(status: AccountPrivacyStatus.submitting));
    try {
      final result = await _remote.requestAccountDeletion(reason.trim());
      _set(
        const AccountPrivacyState(
          status: AccountPrivacyStatus.ready,
          message: 'Account deletion scheduled.',
        ),
      );
      return result;
    } catch (error) {
      _fail(error, 'Your account deletion request could not be scheduled.');
      return null;
    }
  }

  void clearMessage() {
    if (_state.message == null) return;
    _set(const AccountPrivacyState());
  }

  void _fail(Object error, String fallback) {
    _set(
      AccountPrivacyState(
        status: AccountPrivacyStatus.failure,
        message: error is ApiFailure ? error.message : fallback,
      ),
    );
  }

  void _set(AccountPrivacyState value) {
    _state = value;
    notifyListeners();
  }
}
