import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_experience/planext4u_experience.dart';

void main() {
  test(
    'adapter links and reauthenticates the existing user without signing in',
    () async {
      final auth = _Auth();
      final provider = FirebaseAccountLinkingProvider(auth);
      await provider.reauthenticate('owner', SignInMethod.google);
      await provider.link(
        'owner',
        SignInMethod.password,
        email: 'owner@example.test',
        password: 'secret',
      );
      expect(auth.user.actions, ['reauth:google.com', 'link:password']);
      expect(await provider.assertion('owner'), 'provider-token');
      expect(auth.user.actions, containsAllInOrder(['reload', 'token:true']));
      expect(
        () => provider.link('foreign', SignInMethod.google),
        throwsStateError,
      );
    },
  );

  test(
    'automatic phone callbacks never sign in or mutate credentials',
    () async {
      final auth = _Auth();
      final provider = FirebaseAccountLinkingProvider(auth);
      final request = provider.requestPhoneCode('owner', '+919876543210');
      auth.automatic!(
        PhoneAuthProvider.credential(
          verificationId: 'automatic',
          smsCode: '123456',
        ),
      );
      expect(auth.user.actions, isEmpty);
      auth.sent!('manual-challenge', null);
      await request;
      await provider.link('owner', SignInMethod.phone);
      expect(auth.user.actions, ['link:phone']);
      await expectLater(
        provider.link('owner', SignInMethod.phone, code: '123456'),
        throwsFormatException,
      );
      provider.cancel();
    },
  );

  test(
    'manual phone code remains single use without automatic verification',
    () async {
      final auth = _Auth();
      final provider = FirebaseAccountLinkingProvider(auth);
      final request = provider.requestPhoneCode('owner', '+919876543210');
      auth.sent!('manual-challenge', null);
      await request;
      await provider.link('owner', SignInMethod.phone, code: '123456');
      expect(auth.user.actions, ['link:phone']);
      await expectLater(
        provider.link('owner', SignInMethod.phone, code: '123456'),
        throwsFormatException,
      );
    },
  );

  test(
    'cancelled and foreign phone callbacks cannot retain a challenge',
    () async {
      final auth = _Auth();
      final provider = FirebaseAccountLinkingProvider(auth);
      final pending = provider.requestPhoneCode('owner', '+919876543210');
      final failure = expectLater(pending, throwsStateError);
      provider.cancel();
      auth.sent!('late-challenge', null);
      auth.automatic!(
        PhoneAuthProvider.credential(
          verificationId: 'late-automatic',
          smsCode: '123456',
        ),
      );
      await failure;
      await expectLater(
        provider.link('owner', SignInMethod.phone, code: '123456'),
        throwsFormatException,
      );
      expect(auth.user.actions, isEmpty);
    },
  );

  test(
    'a provider account switch during token reload denies the assertion',
    () async {
      final auth = _Auth();
      final provider = FirebaseAccountLinkingProvider(auth);
      auth.user.reloadHook = () {
        auth.current = null;
      };
      await expectLater(provider.assertion('owner'), throwsStateError);
      expect(auth.user.actions, ['reload']);
    },
  );

  test(
    'duplicate credentials propagate without an account merge fallback',
    () async {
      final auth = _Auth();
      final provider = FirebaseAccountLinkingProvider(auth);
      auth.user.failure = FirebaseAuthException(
        code: 'credential-already-in-use',
      );
      await expectLater(
        provider.link('owner', SignInMethod.google),
        throwsA(isA<FirebaseAuthException>()),
      );
      expect(auth.currentSubject, 'owner');
      expect(auth.user.actions, ['link:google.com']);
    },
  );
}

class _Auth extends Fake implements FirebaseAuth {
  _Auth() {
    current = user;
  }
  final user = _User();
  User? current;
  String? get currentSubject => current?.uid;
  PhoneCodeSent? sent;
  PhoneVerificationCompleted? automatic;
  @override
  User? get currentUser => current;
  @override
  Future<void> verifyPhoneNumber({
    String? phoneNumber,
    PhoneMultiFactorInfo? multiFactorInfo,
    required PhoneVerificationCompleted verificationCompleted,
    required PhoneVerificationFailed verificationFailed,
    required PhoneCodeSent codeSent,
    required PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout,
    String? autoRetrievedSmsCodeForTesting,
    Duration timeout = const Duration(seconds: 30),
    int? forceResendingToken,
    MultiFactorSession? multiFactorSession,
  }) async {
    sent = codeSent;
    automatic = verificationCompleted;
  }
}

class _User extends Fake implements User {
  final actions = <String>[];
  Object? failure;
  void Function()? reloadHook;
  @override
  String get uid => 'owner';
  @override
  Future<void> reload() async {
    actions.add('reload');
    reloadHook?.call();
  }

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    actions.add('token:$forceRefresh');
    return 'provider-token';
  }

  @override
  Future<UserCredential> reauthenticateWithProvider(
    AuthProvider provider,
  ) async {
    actions.add('reauth:${provider.providerId}');
    return _Result();
  }

  @override
  Future<UserCredential> linkWithProvider(AuthProvider provider) async {
    actions.add('link:${provider.providerId}');
    if (failure != null) throw failure!;
    return _Result();
  }

  @override
  Future<UserCredential> linkWithCredential(AuthCredential credential) async {
    actions.add('link:${credential.providerId}');
    return _Result();
  }
}

class _Result extends Fake implements UserCredential {}
