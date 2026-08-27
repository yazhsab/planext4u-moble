import 'identity_models.dart';

abstract interface class PhoneOtpProvider {
  Future<String> requestCode({required String phoneNumber});

  Future<ProviderAssertion> verifyCode({
    required String challengeId,
    required String code,
  });
}

abstract interface class EmailIdentityProvider {
  Future<ProviderAssertion> authenticate({
    required String email,
    required String secret,
  });
}

enum OAuthVendor { google, apple }

abstract interface class OAuthIdentityProvider {
  Future<ProviderAssertion> authenticate(OAuthVendor vendor);
}
