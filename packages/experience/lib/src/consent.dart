import 'package:flutter/foundation.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';

import 'consent_journal.dart';

enum ConsentPurpose {
  analytics('ANALYTICS'),
  marketing('MARKETING'),
  locationServiceability('LOCATION_SERVICEABILITY'),
  locationDelivery('LOCATION_DELIVERY'),
  contactMatching('CONTACT_MATCHING');

  const ConsentPurpose(this.wireValue);
  final String wireValue;
}

final class ConsentEvidence {
  const ConsentEvidence({
    required this.evidenceId,
    required this.purpose,
    required this.granted,
    required this.policyVersion,
    required this.recordedAt,
    required this.version,
  });

  factory ConsentEvidence.fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const FormatException('Consent evidence must be an object.');
    }
    final purpose = ConsentPurpose.values.where(
      (item) => item.wireValue == value['purpose'],
    );
    final recordedAt = DateTime.tryParse(value['recorded_at'] as String? ?? '');
    if (purpose.length != 1 ||
        value['evidence_id'] is! String ||
        value['granted'] is! bool ||
        value['policy_version'] is! String ||
        recordedAt == null ||
        !recordedAt.isUtc ||
        value['version'] is! int) {
      throw const FormatException('Consent evidence contract is invalid.');
    }
    return ConsentEvidence(
      evidenceId: value['evidence_id']! as String,
      purpose: purpose.single,
      granted: value['granted']! as bool,
      policyVersion: value['policy_version']! as String,
      recordedAt: recordedAt,
      version: value['version']! as int,
    );
  }

  final String evidenceId;
  final ConsentPurpose purpose;
  final bool granted;
  final String policyVersion;
  final DateTime recordedAt;
  final int version;
}

abstract interface class ConsentRemote {
  Future<List<ConsentEvidence>> list();
  Future<ConsentEvidence> record({
    int? expectedVersion,
    required ConsentPurpose purpose,
    required bool granted,
    required String policyVersion,
  });
}

final class ConsentApi implements ConsentRemote {
  const ConsentApi(this._client);
  final ApiClient _client;

  @override
  Future<List<ConsentEvidence>> list() async {
    final response = await _client.send(
      ApiRequest.get(
        operation: 'identity.list_current_consents',
        path: '/v1/me/consents',
      ),
      (json) {
        if (json is! Map<String, Object?> ||
            json['consents'] is! List<Object?>) {
          throw const FormatException('Consent list contract is invalid.');
        }
        return List<ConsentEvidence>.unmodifiable(
          (json['consents']! as List<Object?>).map(ConsentEvidence.fromJson),
        );
      },
    );
    return response.value;
  }

  @override
  Future<ConsentEvidence> record({
    int? expectedVersion,
    required ConsentPurpose purpose,
    required bool granted,
    required String policyVersion,
  }) async {
    final response = await _client.send(
      ApiRequest.command(
        operation: 'identity.record_consent_evidence',
        method: 'PUT',
        path: '/v1/me/consents/${purpose.wireValue}',
        body: {
          'granted': granted,
          'policy_version': policyVersion,
          if (granted) 'expected_version': expectedVersion,
        },
      ),
      ConsentEvidence.fromJson,
    );
    return response.value;
  }
}

final class ConsentController extends ChangeNotifier {
  ConsentController(this._remote, {ConsentJournal? journal})
    : _journal = journal;
  final ConsentRemote _remote;
  final ConsentJournal? _journal;
  Future<void>? _initialization;
  bool _journalReady = false;
  final Map<ConsentPurpose, ConsentDenial> _denials = {};

  Future<void> _initialize() async {
    if (_journal == null) {
      _journalReady = true;
      return;
    }
    await (_initialization ??= (() async {
      final saved = await _journal.read();
      if (_disposed) return;
      _denials.addAll(saved);
      _unconfirmed.addAll(
        saved.entries
            .where((entry) => entry.value.unconfirmed)
            .map((entry) => entry.key),
      );
      _journalReady = true;
    })()).catchError((Object error) {
      _initialization = null;
      throw error;
    });
  }

  Map<ConsentPurpose, ConsentEvidence> _evidence = const {};
  bool _loading = false;
  bool _disposed = false;
  int _revision = 0;
  int _loadGeneration = 0;
  Future<void> _writeTail = Future.value();
  Future<void> _journalTail = Future.value();
  final Map<ConsentPurpose, int> _intents = {};
  final Set<ConsentPurpose> _unconfirmed = {};

  Map<ConsentPurpose, ConsentEvidence> get evidence => _evidence;
  bool get loading => _loading;
  bool hasUnconfirmedChange(ConsentPurpose purpose) =>
      _unconfirmed.contains(purpose);
  bool granted(ConsentPurpose purpose, String policyVersion) {
    if (_disposed ||
        (_journal != null && !_journalReady) ||
        _denials.containsKey(purpose) ||
        _unconfirmed.contains(purpose)) {
      return false;
    }
    final value = _evidence[purpose];
    return value?.granted == true && value?.policyVersion == policyVersion;
  }

  Future<void> load() async {
    if (_disposed) return;
    final revision = _revision;
    final generation = ++_loadGeneration;
    _loading = true;
    notifyListeners();
    try {
      await _initialize();
      if (_disposed) return;
      // Replay only withdrawals. No grant is ever replayed after a restart.
      for (final entry in Map.of(_denials).entries) {
        if (entry.value.retryWithdrawal) {
          await _retryWithdrawal(entry.key, entry.value);
        }
      }
      final values = await _remote.list();
      if (_disposed || generation != _loadGeneration || revision != _revision) {
        return;
      }
      _evidence = Map.unmodifiable({
        for (final value in values) value.purpose: value,
      });
    } finally {
      if (!_disposed && generation == _loadGeneration) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> setConsent({
    required ConsentPurpose purpose,
    required bool granted,
    required String policyVersion,
  }) {
    if (_disposed) return Future.value();
    final expectedVersion = _evidence[purpose]?.version ?? 0;
    final intent = ++_revision;
    _intents[purpose] = intent;
    // Stop local use immediately, including when withdrawal cannot reach the
    // server. A failed write remains visibly unconfirmed and never grants use.
    _unconfirmed.add(purpose);
    notifyListeners();
    final persistence = _journalTail.then((_) async {
      await _initialize();
      final denial = await _journal?.begin(purpose, policyVersion, granted);
      if (denial != null && !_disposed && _intents[purpose] == intent) {
        _denials[purpose] = denial;
      }
      return denial;
    });
    _journalTail = persistence.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    final operation = _writeTail.then((_) async {
      // Persist an already requested withdrawal even if sign-out disposed this
      // controller while it was queued. Its namespace belongs to that account.
      if (_disposed && granted) return;
      try {
        final denial = await persistence;
        if (_disposed) return;
        final recorded = await _remote.record(
          expectedVersion: granted ? expectedVersion : null,
          purpose: purpose,
          granted: granted,
          policyVersion: policyVersion,
        );
        if (_disposed) return;
        ++_revision;
        if (recorded.purpose != purpose ||
            recorded.granted != granted ||
            recorded.policyVersion != policyVersion ||
            recorded.version < 1 ||
            recorded.evidenceId.isEmpty) {
          throw const FormatException(
            'Consent response does not match the requested change.',
          );
        }
        if (_intents[purpose] == intent) {
          final confirmed =
              denial == null ||
              await _journal!.confirm(purpose, denial.token, granted);
          if (_disposed || _intents[purpose] != intent || !confirmed) return;
          if (granted) {
            _denials.remove(purpose);
          } else if (denial != null) {
            _denials[purpose] = ConsentDenial(
              token: denial.token,
              policyVersion: denial.policyVersion,
              unconfirmed: false,
              retryWithdrawal: false,
            );
          }
          _evidence = Map.unmodifiable({..._evidence, purpose: recorded});
          _unconfirmed.remove(purpose);
        }
      } finally {
        if (!_disposed) {
          ++_revision;
          notifyListeners();
        }
      }
    });
    _writeTail = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return operation;
  }

  Future<void> _retryWithdrawal(
    ConsentPurpose purpose,
    ConsentDenial denial,
  ) async {
    final expectedIntent = _intents[purpose];
    final operation = _writeTail.then((_) async {
      if (_disposed ||
          _intents[purpose] != expectedIntent ||
          _denials[purpose]?.token != denial.token) {
        return;
      }
      final recorded = await _remote.record(
        purpose: purpose,
        granted: false,
        policyVersion: denial.policyVersion,
      );
      if (_disposed || _intents[purpose] != expectedIntent) return;
      if (recorded.purpose != purpose ||
          recorded.granted ||
          recorded.policyVersion != denial.policyVersion ||
          recorded.version < 1 ||
          recorded.evidenceId.isEmpty) {
        throw const FormatException('Withdrawal response is invalid.');
      }
      if (await _journal!.confirm(purpose, denial.token, false)) {
        if (_disposed || _intents[purpose] != expectedIntent) return;
        _denials[purpose] = ConsentDenial(
          token: denial.token,
          policyVersion: denial.policyVersion,
          unconfirmed: false,
          retryWithdrawal: false,
        );
        _unconfirmed.remove(purpose);
      }
    });
    _writeTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    await operation;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_revision;
    ++_loadGeneration;
    _evidence = const {};
    _unconfirmed.clear();
    super.dispose();
  }
}
