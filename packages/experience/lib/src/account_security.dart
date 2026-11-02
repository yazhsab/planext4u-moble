import 'package:flutter/foundation.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';

enum SignInMethod { password, google, phone }

final class VerifiedSignInMethods {
  VerifiedSignInMethods({
    required this.subject,
    required Set<String> methods,
    required this.emailVerified,
  }) : methods = Set.unmodifiable(methods);

  final String subject;
  final Set<String> methods;
  final bool emailVerified;

  factory VerifiedSignInMethods.fromJson(Object? value) {
    if (value is! Map<String, Object?> ||
        value['provider_subject'] is! String ||
        value['methods'] is! List ||
        value['email_verified'] is! bool) {
      throw const FormatException('Invalid sign-in methods response.');
    }
    final subject = value['provider_subject']! as String;
    final methods = value['methods']! as List;
    const allowed = {'password', 'google.com', 'phone', 'apple.com'};
    if (!RegExp(r'^[\x21-\x7E]{1,128}$').hasMatch(subject) ||
        methods.isEmpty ||
        methods.length > 4 ||
        methods.any((item) => !allowed.contains(item)) ||
        methods.toSet().length != methods.length) {
      throw const FormatException('Invalid sign-in methods response.');
    }
    return VerifiedSignInMethods(
      subject: subject,
      methods: methods.cast<String>().toSet(),
      emailVerified: value['email_verified']! as bool,
    );
  }
}

abstract interface class AccountSecurityRemote {
  Future<VerifiedSignInMethods> verify(
    String providerToken, {
    bool requireFresh = true,
  });
}

final class AccountSecurityApi implements AccountSecurityRemote {
  const AccountSecurityApi(this._client);
  final ApiClient _client;

  @override
  Future<VerifiedSignInMethods> verify(
    String providerToken, {
    bool requireFresh = true,
  }) async => (await _client.send(
    ApiRequest(
      operation: 'identity.verify_sign_in_methods',
      method: 'POST',
      path: requireFresh
          ? '/v1/me/sign-in-methods/verify'
          : '/v1/me/sign-in-methods/binding',
      body: {'provider_token': providerToken},
      replayPolicy: ApiReplayPolicy.never,
    ),
    VerifiedSignInMethods.fromJson,
  )).value;
}

/// Mutations must use the existing provider user, never a sign-in exchange.
abstract interface class AccountLinkingProvider {
  String? get currentSubject;
  Future<String> assertion(String expectedSubject);
  Future<void> reauthenticate(
    String subject,
    SignInMethod method, {
    String email = '',
    String password = '',
    String code = '',
  });
  Future<void> link(
    String subject,
    SignInMethod method, {
    String email = '',
    String password = '',
    String code = '',
  });
  Future<void> requestPhoneCode(String subject, String phone);
  Future<void> sendEmailVerification(String subject);
  void cancel();
}

enum AccountSecurityStatus {
  locked,
  busy,
  ready,
  confirmationRequired,
  failure,
}

final class AccountSecurityController extends ChangeNotifier {
  AccountSecurityController({
    required AccountSecurityRemote remote,
    required AccountLinkingProvider provider,
    required bool Function() scopeIsCurrent,
    DateTime Function()? clock,
  }) : _remote = remote,
       _provider = provider,
       _scopeIsCurrent = scopeIsCurrent,
       _clock = clock ?? DateTime.now;

  final AccountSecurityRemote _remote;
  final AccountLinkingProvider _provider;
  final bool Function() _scopeIsCurrent;
  final DateTime Function() _clock;
  AccountSecurityStatus status = AccountSecurityStatus.locked;
  VerifiedSignInMethods? verified;
  String? message;
  String? _subject;
  DateTime? _verifiedAt;
  bool _disposed = false;
  int _epoch = 0;

  bool get busy => status == AccountSecurityStatus.busy;
  bool get unlocked =>
      verified != null &&
      _verifiedAt != null &&
      _clock().difference(_verifiedAt!) < const Duration(minutes: 4) &&
      !_clock().isBefore(_verifiedAt!) &&
      _scopeIsCurrent() &&
      _provider.currentSubject == _subject;

  void _guard(int epoch) {
    if (_disposed || epoch != _epoch || !_scopeIsCurrent()) {
      throw StateError('Account session changed.');
    }
    if (_subject == null || _provider.currentSubject != _subject) {
      throw StateError('Provider account changed.');
    }
  }

  Future<bool> unlock(
    SignInMethod method, {
    String email = '',
    String password = '',
    String code = '',
  }) => _run((epoch) async {
    _subject ??= _provider.currentSubject;
    _guard(epoch);
    // Bind before reauthentication as well as before linking. A native SDK
    // session left behind by a different account cannot act on this profile.
    await _verify(epoch, fresh: false);
    _guard(epoch);
    await _provider.reauthenticate(
      _subject!,
      method,
      email: email,
      password: password,
      code: code,
    );
    _guard(epoch);
    await _verify(epoch);
    _verifiedAt = _clock();
    message = 'Account verified. You can add a sign-in method.';
  });

  Future<bool> link(
    SignInMethod method, {
    String email = '',
    String password = '',
    String code = '',
  }) => _run((epoch) async {
    _guard(epoch);
    if (!unlocked) throw StateError('Verify your account again.');
    await _verify(epoch);
    _guard(epoch);
    // From here a network failure may leave a provider change committed. The
    // UI must require a fresh confirmation, rather than reporting a rollback.
    _verifiedAt = null;
    await _provider.link(
      _subject!,
      method,
      email: email,
      password: password,
      code: code,
    );
    _guard(epoch);
    await _verify(epoch);
    _verifiedAt = _clock();
    message = method == SignInMethod.password && !verified!.emailVerified
        ? 'Email sign-in added. Verify your email to use it as a verified contact.'
        : 'Sign-in method added to this account.';
  }, mutation: true);

  Future<bool> requestPhoneCode(String phone) => _run((epoch) async {
    _subject ??= _provider.currentSubject;
    _guard(epoch);
    // Sending an OTP does not reauthenticate or switch the provider account.
    await _provider.requestPhoneCode(_subject!, phone);
    _guard(epoch);
    message =
        'Complete phone verification. Enter the code if one was sent; Android may verify the number automatically.';
  });

  Future<bool> refresh() => _run((epoch) async {
    _subject ??= _provider.currentSubject;
    _guard(epoch);
    await _verify(epoch, fresh: false);
    // Confirmation is useful after an interrupted link, but does not replace
    // explicit reauthentication before another credential mutation.
    _verifiedAt = null;
    message = 'Sign-in methods refreshed. Verify again before making changes.';
  });

  Future<bool> sendEmailVerification() => _run((epoch) async {
    _guard(epoch);
    await _verify(epoch, fresh: false);
    await _provider.sendEmailVerification(_subject!);
    _guard(epoch);
    message = 'Verification email requested. Check your inbox, then refresh.';
  });

  Future<void> _verify(int epoch, {bool fresh = true}) async {
    _guard(epoch);
    final token = await _provider.assertion(_subject!);
    _guard(epoch);
    final value = await _remote.verify(token, requireFresh: fresh);
    _guard(epoch);
    if (value.subject != _subject) {
      throw StateError('Account binding mismatch.');
    }
    verified = value;
  }

  Future<bool> _run(
    Future<void> Function(int epoch) operation, {
    bool mutation = false,
  }) async {
    if (_disposed || busy || !_scopeIsCurrent()) return false;
    final epoch = ++_epoch;
    status = AccountSecurityStatus.busy;
    message = null;
    notifyListeners();
    try {
      await operation(epoch);
      _guard(epoch);
      status = unlocked
          ? AccountSecurityStatus.ready
          : AccountSecurityStatus.locked;
      notifyListeners();
      return true;
    } catch (_) {
      if (_disposed || epoch != _epoch) return false;
      _verifiedAt = null;
      verified = null;
      status = mutation
          ? AccountSecurityStatus.confirmationRequired
          : AccountSecurityStatus.failure;
      message = mutation
          ? 'The change could not be confirmed. Refresh your methods before trying again. A credential used by another account cannot be merged.'
          : 'Account verification failed. Use an existing sign-in method, or sign in again if your session is old.';
      notifyListeners();
      return false;
    }
  }

  void lock() {
    if (_disposed) return;
    ++_epoch;
    _provider.cancel();
    _verifiedAt = null;
    verified = null;
    status = AccountSecurityStatus.locked;
    message = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_epoch;
    _provider.cancel();
    verified = null;
    _verifiedAt = null;
    super.dispose();
  }
}
