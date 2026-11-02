import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import 'account_security.dart';

/// Firebase owns uniqueness and credential verification. These operations never
/// call signInWithCredential, createUser or a platform session exchange.
final class FirebaseAccountLinkingProvider implements AccountLinkingProvider {
  FirebaseAccountLinkingProvider(this._auth);
  final FirebaseAuth _auth;
  String? _verificationId;
  PhoneAuthCredential? _automaticCredential;
  String? _phoneSubject;
  DateTime? _phoneExpires;
  int _generation = 0;
  Completer<void>? _pendingPhone;

  @override
  String? get currentSubject => _auth.currentUser?.uid;

  User _user(String expected) {
    final user = _auth.currentUser;
    if (user == null || user.uid != expected) {
      throw StateError('Provider account changed.');
    }
    return user;
  }

  @override
  Future<String> assertion(String expectedSubject) async {
    final user = _user(expectedSubject);
    await user.reload();
    _user(expectedSubject);
    final token = await user.getIdToken(true);
    _user(expectedSubject);
    if (token == null || token.length < 8) {
      throw StateError('Provider token is unavailable.');
    }
    return token;
  }

  AuthCredential _credential(
    String subject,
    SignInMethod method,
    String email,
    String password,
    String code,
  ) {
    if (method == SignInMethod.password) {
      if (email.trim().length > 254 ||
          !email.trim().contains('@') ||
          password.isEmpty ||
          password.length > 4096) {
        throw const FormatException('Enter an email address and password.');
      }
      return EmailAuthProvider.credential(
        email: email.trim(),
        password: password,
      );
    }
    if (method != SignInMethod.phone ||
        (_verificationId == null && _automaticCredential == null) ||
        _phoneSubject != subject ||
        _phoneExpires == null ||
        !DateTime.now().isBefore(_phoneExpires!) ||
        _automaticCredential == null &&
            !RegExp(r'^\d{6}$').hasMatch(code.trim())) {
      throw const FormatException('Request a new phone verification code.');
    }
    final credential =
        _automaticCredential ??
        PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: code.trim(),
        );
    // A challenge is single use, including a failed submission.
    _verificationId = null;
    _automaticCredential = null;
    _phoneSubject = null;
    _phoneExpires = null;
    return credential;
  }

  @override
  Future<void> reauthenticate(
    String subject,
    SignInMethod method, {
    String email = '',
    String password = '',
    String code = '',
  }) async {
    final user = _user(subject);
    if (method == SignInMethod.google) {
      await user.reauthenticateWithProvider(GoogleAuthProvider());
    } else {
      await user.reauthenticateWithCredential(
        _credential(subject, method, email, password, code),
      );
    }
    _user(subject);
  }

  @override
  Future<void> link(
    String subject,
    SignInMethod method, {
    String email = '',
    String password = '',
    String code = '',
  }) async {
    final user = _user(subject);
    if (method == SignInMethod.google) {
      await user.linkWithProvider(GoogleAuthProvider());
    } else {
      await user.linkWithCredential(
        _credential(subject, method, email, password, code),
      );
    }
    _user(subject);
  }

  @override
  Future<void> sendEmailVerification(String subject) async {
    await _user(subject).sendEmailVerification();
    _user(subject);
  }

  @override
  Future<void> requestPhoneCode(String subject, String phone) async {
    _user(subject);
    if (!RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(phone.trim())) {
      throw const FormatException('Use an international phone number.');
    }
    cancel();
    final generation = _generation;
    final result = Completer<void>();
    _pendingPhone = result;
    bool active() => generation == _generation && currentSubject == subject;
    void fail(Object error) {
      if (!result.isCompleted) result.completeError(error);
    }

    // Attach the error listener before callbacks can synchronously complete.
    final waiting = result.future.timeout(const Duration(seconds: 75));
    unawaited(
      _auth
          .verifyPhoneNumber(
            phoneNumber: phone.trim(),
            timeout: const Duration(seconds: 60),
            // Instant Android verification may send no SMS. Retain only a
            // short-lived account-bound credential until an explicit Verify/
            // Add action; this callback never signs in or links by itself.
            verificationCompleted: (credential) {
              if (!active() || result.isCompleted) return;
              _automaticCredential = credential;
              _phoneSubject = subject;
              _phoneExpires = DateTime.now().add(const Duration(minutes: 2));
              result.complete();
            },
            verificationFailed: (error) {
              if (active()) fail(error);
            },
            codeSent: (id, _) {
              if (!active() || result.isCompleted) return;
              _verificationId = id;
              _phoneSubject = subject;
              _phoneExpires = DateTime.now().add(const Duration(minutes: 2));
              result.complete();
            },
            codeAutoRetrievalTimeout: (_) {
              if (active()) {
                fail(TimeoutException('Phone verification timed out.'));
              }
            },
          )
          .catchError((Object error) {
            if (active()) fail(error);
          }),
    );
    try {
      await waiting;
      if (!active()) throw StateError('Account session changed.');
    } finally {
      if (identical(_pendingPhone, result)) _pendingPhone = null;
      if (!result.isCompleted) {
        ++_generation;
        result.completeError(TimeoutException('Phone verification timed out.'));
      }
    }
  }

  @override
  void cancel() {
    ++_generation;
    _verificationId = null;
    _automaticCredential = null;
    _phoneSubject = null;
    _phoneExpires = null;
    final pending = _pendingPhone;
    _pendingPhone = null;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(StateError('Phone verification cancelled.'));
    }
  }
}
