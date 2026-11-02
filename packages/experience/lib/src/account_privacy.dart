import 'package:flutter/foundation.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_storage/planext4u_storage.dart';

import 'phase5.dart';
import 'account_lifecycle.dart';
import 'consent.dart';
import 'contact_matching.dart';
import 'local_app_lock.dart';

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
  AccountPrivacyController(
    this._remote, {
    this.lifecycle,
    this.consents,
    this.appLock,
    this.contacts,
    this.ownsConsents = true,
    DocumentExporter documentExporter = const PlatformDocumentExporter(),
  }) : _documentExporter = documentExporter {
    lifecycle?.addListener(notifyListeners);
  }

  final AccountPrivacyRemote _remote;
  final AccountLifecycleController? lifecycle;
  final ConsentController? consents;
  final LocalAppLockController? appLock;
  final ContactMatchingController? contacts;
  final bool ownsConsents;
  final DocumentExporter _documentExporter;
  AccountPrivacyState _state = const AccountPrivacyState();
  bool _disposed = false;
  AccountDataExport? _lastExport;

  AccountPrivacyState get state => _state;
  bool get isActive => !_disposed;

  Future<DocumentExportResult?> saveExport(AccountDataExport value) async {
    final document = value.document;
    if (_disposed ||
        _state.busy ||
        document == null ||
        !identical(value, _lastExport)) {
      return null;
    }
    _set(const AccountPrivacyState(status: AccountPrivacyStatus.submitting));
    final bytes = document.bytes;
    try {
      final result = await _documentExporter.save(
        fileName: document.fileName,
        bytes: bytes,
        isCurrent: () => !_disposed,
      );
      if (_disposed) return null;
      _set(
        AccountPrivacyState(
          status: AccountPrivacyStatus.ready,
          message: result == DocumentExportResult.saved
              ? 'Account export saved to your chosen location.'
              : 'Export cancelled. You can choose a destination again.',
        ),
      );
      return result;
    } catch (_) {
      _fail(
        StateError('Export destination unavailable'),
        'The export could not be saved. Choose a writable location and retry.',
      );
      return null;
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  Future<AccountDataExport?> exportAccountData() async {
    if (_disposed || _state.busy) return null;
    _lastExport = null;
    _set(const AccountPrivacyState(status: AccountPrivacyStatus.submitting));
    try {
      final result = await _remote.exportAccountData();
      if (_disposed) return null;
      _lastExport = result;
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
    if (_disposed || _state.busy) return null;
    _set(const AccountPrivacyState(status: AccountPrivacyStatus.submitting));
    try {
      final result = await _remote.requestAccountDeletion(reason.trim());
      if (_disposed) return null;
      if (!RegExp(r'^[A-Za-z0-9._:-]{1,128}$').hasMatch(result.id) ||
          result.status != 'SCHEDULED' ||
          !result.effectiveAt.isAfter(result.requestedAt)) {
        throw const FormatException('Account deletion response is invalid.');
      }
      lifecycle?.scheduled(result);
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
    if (_disposed) return;
    _state = value;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _lastExport = null;
    lifecycle?.removeListener(notifyListeners);
    lifecycle?.dispose();
    if (ownsConsents) consents?.dispose();
    appLock?.dispose();
    contacts?.dispose();
    super.dispose();
  }
}
