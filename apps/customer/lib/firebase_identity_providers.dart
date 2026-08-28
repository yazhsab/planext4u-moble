import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:planext4u_identity/planext4u_identity.dart';

final class FirebaseEmailProvider implements EmailIdentityProvider {
  FirebaseEmailProvider(this._auth);
  final FirebaseAuth _auth;

  @override
  Future<ProviderAssertion> authenticate({
    required String email,
    required String secret,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: secret,
    );
    return _assertion(credential.user);
  }

  Future<void> register({required String email, required String secret}) async {
    await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: secret,
    );
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());
}

final class FirebasePhoneProvider implements PhoneOtpProvider {
  FirebasePhoneProvider(this._auth);
  final FirebaseAuth _auth;
  final Map<String, String> _verificationIds = {};

  @override
  Future<String> requestCode({required String phoneNumber}) async {
    final result = Completer<String>();
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber.trim(),
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        try {
          final authenticated = await _auth.signInWithCredential(credential);
          final assertion = await _assertion(authenticated.user);
          final challenge =
              'automatic-${DateTime.now().microsecondsSinceEpoch}';
          _verificationIds[challenge] = 'assertion:${assertion.token}';
          if (!result.isCompleted) result.complete(challenge);
        } catch (error, stackTrace) {
          if (!result.isCompleted) result.completeError(error, stackTrace);
        }
      },
      verificationFailed: (error) {
        if (!result.isCompleted) result.completeError(error);
      },
      codeSent: (verificationId, _) {
        final challenge = 'phone-${DateTime.now().microsecondsSinceEpoch}';
        _verificationIds[challenge] = verificationId;
        if (!result.isCompleted) result.complete(challenge);
      },
      codeAutoRetrievalTimeout: (_) {
        if (!result.isCompleted) {
          result.completeError(
            TimeoutException('The verification code timed out.'),
          );
        }
      },
    );
    return result.future.timeout(const Duration(seconds: 75));
  }

  @override
  Future<ProviderAssertion> verifyCode({
    required String challengeId,
    required String code,
  }) async {
    final verification = _verificationIds.remove(challengeId);
    if (verification == null) {
      throw const FormatException('The phone verification has expired.');
    }
    if (verification.startsWith('assertion:')) {
      return ProviderAssertion(
        provider: IdentityProviderKind.firebase,
        token: verification.substring('assertion:'.length),
      );
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: verification,
      smsCode: code.trim(),
    );
    final authenticated = await _auth.signInWithCredential(credential);
    return _assertion(authenticated.user);
  }
}

final class FirebaseOAuthProvider implements OAuthIdentityProvider {
  FirebaseOAuthProvider(this._auth);
  final FirebaseAuth _auth;

  @override
  Future<ProviderAssertion> authenticate(OAuthVendor vendor) async {
    final provider = switch (vendor) {
      OAuthVendor.google => GoogleAuthProvider(),
      OAuthVendor.apple => AppleAuthProvider(),
    };
    final credential = await _auth.signInWithProvider(provider);
    return _assertion(credential.user);
  }
}

Future<ProviderAssertion> _assertion(User? user) async {
  final token = await user?.getIdToken(true);
  if (token == null || token.length < 8) {
    throw const FormatException('Firebase did not return an identity token.');
  }
  return ProviderAssertion(
    provider: IdentityProviderKind.firebase,
    token: token,
  );
}
