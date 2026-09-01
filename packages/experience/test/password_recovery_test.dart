import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_experience/planext4u_experience.dart';
import 'package:planext4u_identity/planext4u_identity.dart';

void main() {
  test('password recovery policy rejects malformed addresses', () {
    expect(PasswordRecoveryPolicy.isValidEmail(''), isFalse);
    expect(PasswordRecoveryPolicy.isValidEmail('rider@localhost'), isFalse);
    expect(PasswordRecoveryPolicy.isValidEmail('rider @example.com'), isFalse);
    expect(PasswordRecoveryPolicy.isValidEmail('rider@example.com'), isTrue);
  });

  testWidgets('password recovery validates and sends enumeration-safe copy', (
    tester,
  ) async {
    final email = TextEditingController();
    final provider = _RecoveryProvider();
    addTearDown(email.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PasswordRecoveryButton(
            emailController: email,
            provider: provider,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('forgot-password')));
    await tester.pump();
    expect(find.text('Enter a valid email address first.'), findsOneWidget);
    expect(provider.emails, isEmpty);

    email.text = 'rider@example.com';
    await tester.tap(find.byKey(const ValueKey('forgot-password')));
    await tester.pumpAndSettle();

    expect(provider.emails, ['rider@example.com']);
    expect(
      find.text(
        'If an account exists for that email, recovery instructions have been sent.',
      ),
      findsOneWidget,
    );
  });

  test('phone OTP policy requires E.164 numbers and bounded numeric codes', () {
    expect(PhoneOtpPolicy.isValidPhoneNumber('9876543210'), isFalse);
    expect(PhoneOtpPolicy.isValidPhoneNumber('+919876543210'), isTrue);
    expect(PhoneOtpPolicy.isValidCode('123'), isFalse);
    expect(PhoneOtpPolicy.isValidCode('123456'), isTrue);
  });

  testWidgets('phone OTP control requests and verifies one challenge', (
    tester,
  ) async {
    final provider = _PhoneProvider();
    final verifications = <(String, String)>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhoneOtpSignInControl(
            provider: provider,
            onVerify: (challenge, code) async {
              verifications.add((challenge, code));
            },
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('role-phone')),
      '+919876543210',
    );
    await tester.tap(find.byKey(const ValueKey('role-request-otp')));
    await tester.pumpAndSettle();
    expect(provider.phoneNumbers, ['+919876543210']);
    expect(find.text('Verification code sent.'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('role-otp')), '123456');
    await tester.tap(find.byKey(const ValueKey('role-verify-otp')));
    await tester.pumpAndSettle();
    expect(verifications, [('challenge-001', '123456')]);
  });
}

final class _RecoveryProvider implements PasswordRecoveryProvider {
  final List<String> emails = [];

  @override
  Future<void> requestPasswordReset({required String email}) async {
    emails.add(email);
  }
}

final class _PhoneProvider implements PhoneOtpProvider {
  final List<String> phoneNumbers = [];

  @override
  Future<String> requestCode({required String phoneNumber}) async {
    phoneNumbers.add(phoneNumber);
    return 'challenge-001';
  }

  @override
  Future<ProviderAssertion> verifyCode({
    required String challengeId,
    required String code,
  }) async => ProviderAssertion(
    provider: IdentityProviderKind.firebase,
    token: 'firebase-token-001',
  );
}
