import 'package:flutter/foundation.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_device_access/planext4u_device_access.dart';

import 'consent.dart';

/// Keeps match names only in the active account screen. The address book is
/// read only inside sync(), after current purpose consent and Android access.
final class ContactMatchingController extends ChangeNotifier {
  ContactMatchingController({
    required ContactMatchingApi api,
    required ConsentController consent,
    required String? Function() policyVersion,
    required Future<String> Function() freshProviderToken,
    required bool Function() scopeIsCurrent,
    DeviceAccessPlatform permissions = const AndroidDeviceAccess(),
    ContactPhonesPlatform phones = const AndroidContactPhones(),
  }) : _api = api,
       _consent = consent,
       _policyVersion = policyVersion,
       _freshProviderToken = freshProviderToken,
       _scopeIsCurrent = scopeIsCurrent,
       _permissions = permissions,
       _phones = phones {
    _consent.addListener(_consentChanged);
  }

  final ContactMatchingApi _api;
  final ConsentController _consent;
  final String? Function() _policyVersion;
  final Future<String> Function() _freshProviderToken;
  final bool Function() _scopeIsCurrent;
  final DeviceAccessPlatform _permissions;
  final ContactPhonesPlatform _phones;
  bool _disposed = false;
  bool busy = false;
  String? message;
  ContactMatchingState? state;
  List<ContactMatch> matches = const [];
  String? nextCursor;
  int skipped = 0;
  bool get isActive => !_disposed && _scopeIsCurrent() && _api.isActive;
  bool get hasPublishedPolicy => _policyVersion() != null;

  bool get consentGranted {
    final policy = _policyVersion();
    return isActive &&
        policy != null &&
        _consent.granted(ConsentPurpose.contactMatching, policy);
  }

  void _clearMatches() {
    matches = const [];
    nextCursor = null;
  }

  void _consentChanged() {
    if (_disposed) return;
    if (!consentGranted) {
      _clearMatches();
      state = null;
    }
    notifyListeners();
  }

  Future<void> load() async {
    if (!isActive || busy) return;
    busy = true;
    message = null;
    _clearMatches();
    notifyListeners();
    try {
      final value = await _api.state();
      if (!isActive) return;
      state = value;
      if (value.status == 'UNAVAILABLE') {
        message = 'Contact matching is unavailable for this account.';
      } else if (!hasPublishedPolicy) {
        message = 'The contact matching privacy policy is unavailable.';
      }
    } catch (_) {
      if (isActive) message = 'Could not refresh contact matching. Try again.';
    } finally {
      if (isActive) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> grant() async {
    final policy = _policyVersion();
    if (!isActive || busy || policy == null || state?.status == 'UNAVAILABLE') {
      return;
    }
    busy = true;
    message = null;
    notifyListeners();
    try {
      await _consent.setConsent(
        purpose: ConsentPurpose.contactMatching,
        granted: true,
        policyVersion: policy,
      );
      if (!isActive || _policyVersion() != policy || !consentGranted) {
        throw StateError('Contact consent was not confirmed.');
      }
      state = await _api.state();
      if (!isActive) return;
      message = 'Choice saved. Select Sync contacts when you are ready.';
    } catch (_) {
      if (isActive) {
        message = 'Contact choice was not confirmed. Refresh and retry.';
      }
    } finally {
      if (isActive) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> sync() async {
    final policy = _policyVersion();
    if (!isActive ||
        busy ||
        policy == null ||
        !consentGranted ||
        state == null ||
        state!.status == 'UNAVAILABLE') {
      return;
    }
    busy = true;
    message = null;
    _clearMatches();
    notifyListeners();
    try {
      var permission = await _permissions.read();
      if (!isActive || !consentGranted || _policyVersion() != policy) return;
      if (permission.permissions[DevicePermission.contacts] !=
          DeviceAccess.allowed) {
        permission = await _permissions.request(DevicePermission.contacts);
      }
      if (!isActive || !consentGranted || _policyVersion() != policy) return;
      if (permission.permissions[DevicePermission.contacts] !=
          DeviceAccess.allowed) {
        message = 'Android contacts access was not allowed.';
        return;
      }
      // The native reader returns only normalized E.164 phone numbers and a
      // skipped count. It never reads display names or stores the address book.
      final captured = await _phones.readPhones(maximum: state!.maxContacts);
      if (!isActive || !consentGranted || _policyVersion() != policy) return;
      final token = await _freshProviderToken();
      if (!isActive || !consentGranted || _policyVersion() != policy) return;
      final value = await _api.sync(
        providerToken: token,
        policyVersion: policy,
        expectedRevision: state!.revision,
        phones: captured.phones,
      );
      if (!isActive || !consentGranted || _policyVersion() != policy) return;
      state = value;
      skipped = captured.skipped;
      message = value.ready
          ? 'Contacts synced. $skipped numbers without an international format were skipped.'
          : 'Contact sync needs a fresh privacy choice or sign-in.';
    } catch (_) {
      if (isActive) {
        message =
            'Contacts could not be synced. No partial list was saved on this device.';
      }
    } finally {
      if (isActive) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMatches() async {
    final policy = _policyVersion();
    if (!isActive ||
        busy ||
        !consentGranted ||
        policy == null ||
        state?.ready != true) {
      return;
    }
    busy = true;
    message = null;
    notifyListeners();
    try {
      final current = await _api.state();
      if (!isActive || !consentGranted || _policyVersion() != policy) return;
      if (!current.ready ||
          current.revision != state!.revision ||
          current.policyVersion != policy) {
        _clearMatches();
        state = current;
        message = 'Contacts changed. Sync again to see current matches.';
        return;
      }
      final page = await _api.matches(
        revision: current.revision,
        cursor: nextCursor,
      );
      if (!isActive || !consentGranted || _policyVersion() != policy) return;
      matches = List.unmodifiable([...matches, ...page.items]);
      nextCursor = page.nextCursor;
    } catch (_) {
      if (isActive) {
        _clearMatches();
        message =
            'Matches could not be refreshed. Retry to check current consent.';
      }
    } finally {
      if (isActive) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _clearMatches();
    state = null;
    _consent.removeListener(_consentChanged);
    _api.dispose();
    super.dispose();
  }
}
