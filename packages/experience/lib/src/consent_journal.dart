import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'consent.dart';

final class ConsentDenial {
  const ConsentDenial({
    required this.token,
    required this.policyVersion,
    required this.unconfirmed,
    required this.retryWithdrawal,
  });
  final String token;
  final String policyVersion;
  final bool unconfirmed;
  final bool retryWithdrawal;
}

/// Denials have no expiry. A failed/corrupt read must never become a grant.
/// Only an explicit acknowledged grant can remove a matching intent.
abstract interface class ConsentJournal {
  Future<Map<ConsentPurpose, ConsentDenial>> read();
  Future<ConsentDenial> begin(
    ConsentPurpose purpose,
    String policy,
    bool grant,
  );
  Future<bool> confirm(ConsentPurpose purpose, String token, bool grant);
}

final class SecureConsentJournal implements ConsentJournal {
  SecureConsentJournal({
    required String tenantId,
    required String country,
    required String identityId,
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? platformStorage,
       _prefix =
           'planext4u.consent.v1.${sha256.convert(utf8.encode(jsonEncode([tenantId, country, identityId])))}';

  final FlutterSecureStorage _storage;
  // The SDK otherwise resets encrypted data after an error. A separate full
  // Android namespace also prevents another cache/session store's reset policy
  // from erasing this journal's denials, keys or algorithm markers.
  static const platformStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: false,
      storageNamespace: 'planext4u-consent-v1',
    ),
  );
  final String _prefix;
  static final Map<String, Future<void>> _tails = {};

  Future<T> _serialize<T>(Future<T> Function() work) {
    final operation = (_tails[_prefix] ?? Future<void>.value()).then(
      (_) => work(),
    );
    final tail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _tails[_prefix] = tail;
    unawaited(
      tail.whenComplete(() {
        if (identical(_tails[_prefix], tail)) _tails.remove(_prefix);
      }),
    );
    return operation;
  }

  String _key(ConsentPurpose purpose) => '$_prefix.${purpose.wireValue}';

  Future<ConsentDenial?> _read(ConsentPurpose purpose) async {
    final raw = await _storage.read(key: _key(purpose));
    if (raw == null) return null;
    final value = jsonDecode(raw);
    if (value is! Map<String, Object?> ||
        value['schema'] != 1 ||
        value['token'] is! String ||
        value['policy'] is! String ||
        value['unconfirmed'] is! bool ||
        value['retry'] is! bool ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(value['token']! as String) ||
        !RegExp(
          r'^[A-Za-z0-9._:-]{1,128}$',
        ).hasMatch(value['policy']! as String)) {
      throw const FormatException('Saved privacy choice is unavailable.');
    }
    return ConsentDenial(
      token: value['token']! as String,
      policyVersion: value['policy']! as String,
      unconfirmed: value['unconfirmed']! as bool,
      retryWithdrawal: value['retry']! as bool,
    );
  }

  Future<void> _write(ConsentPurpose purpose, ConsentDenial value) =>
      _storage.write(
        key: _key(purpose),
        value: jsonEncode({
          'schema': 1,
          'token': value.token,
          'policy': value.policyVersion,
          'unconfirmed': value.unconfirmed,
          'retry': value.retryWithdrawal,
        }),
      );

  @override
  Future<Map<ConsentPurpose, ConsentDenial>> read() => _serialize(
    () async => {
      for (final purpose in ConsentPurpose.values)
        if (await _read(purpose) case final ConsentDenial denial)
          purpose: denial,
    },
  );

  @override
  Future<ConsentDenial> begin(
    ConsentPurpose purpose,
    String policy,
    bool grant,
  ) => _serialize(() async {
    if (!RegExp(r'^[A-Za-z0-9._:-]{1,128}$').hasMatch(policy)) {
      throw const FormatException('Privacy policy version is invalid.');
    }
    final random = Random.secure();
    final value = ConsentDenial(
      token: List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join(),
      policyVersion: policy,
      unconfirmed: true,
      retryWithdrawal: !grant,
    );
    await _write(purpose, value);
    return value;
  });

  @override
  Future<bool> confirm(ConsentPurpose purpose, String token, bool grant) =>
      _serialize(() async {
        final current = await _read(purpose);
        if (current == null || current.token != token) return false;
        if (grant) {
          await _storage.delete(key: _key(purpose));
        } else {
          await _write(
            purpose,
            ConsentDenial(
              token: token,
              policyVersion: current.policyVersion,
              unconfirmed: false,
              retryWithdrawal: false,
            ),
          );
        }
        return true;
      });
}
