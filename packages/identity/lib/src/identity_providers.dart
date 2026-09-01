import 'identity_models.dart';

abstract interface class PhoneOtpProvider {
  Future<String> requestCode({required String phoneNumber});

  Future<ProviderAssertion> verifyCode({
    required String challengeId,
    required String code,
  });
}

abstract final class PhoneOtpPolicy {
  static bool isValidPhoneNumber(String value) =>
      RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(value.trim());

  static bool isValidCode(String value) =>
      RegExp(r'^[0-9]{4,8}$').hasMatch(value.trim());
}

abstract interface class EmailIdentityProvider {
  Future<ProviderAssertion> authenticate({
    required String email,
    required String secret,
  });
}

/// Provider-owned password recovery boundary.
///
/// Keeping recovery separate from [EmailIdentityProvider] lets applications
/// offer email sign-in without claiming password-reset support when the
/// configured identity provider cannot deliver it.
abstract interface class PasswordRecoveryProvider {
  Future<void> requestPasswordReset({required String email});
}

abstract final class PasswordRecoveryPolicy {
  static bool isValidEmail(String value) {
    final email = value.trim();
    if (email.isEmpty || email.length > 254 || email.contains(RegExp(r'\s'))) {
      return false;
    }
    final separator = email.indexOf('@');
    if (separator < 1 || separator != email.lastIndexOf('@')) return false;
    final domain = email.substring(separator + 1);
    return domain.length >= 3 &&
        domain.contains('.') &&
        !domain.startsWith('.') &&
        !domain.endsWith('.');
  }
}

enum OAuthVendor { google, apple }

abstract interface class OAuthIdentityProvider {
  Future<ProviderAssertion> authenticate(OAuthVendor vendor);
}
