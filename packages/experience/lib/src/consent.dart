import 'package:flutter/foundation.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';

enum ConsentPurpose {
  analytics('ANALYTICS'),
  marketing('MARKETING'),
  locationServiceability('LOCATION_SERVICEABILITY'),
  locationDelivery('LOCATION_DELIVERY');

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
    required ConsentPurpose purpose,
    required bool granted,
    required String policyVersion,
  }) async {
    final response = await _client.send(
      ApiRequest.command(
        operation: 'identity.record_consent_evidence',
        method: 'PUT',
        path: '/v1/me/consents/${purpose.wireValue}',
        body: {'granted': granted, 'policy_version': policyVersion},
      ),
      ConsentEvidence.fromJson,
    );
    return response.value;
  }
}

final class ConsentController extends ChangeNotifier {
  ConsentController(this._remote);
  final ConsentRemote _remote;
  Map<ConsentPurpose, ConsentEvidence> _evidence = const {};
  bool _loading = false;

  Map<ConsentPurpose, ConsentEvidence> get evidence => _evidence;
  bool get loading => _loading;
  bool granted(ConsentPurpose purpose, String policyVersion) {
    final value = _evidence[purpose];
    return value?.granted == true && value?.policyVersion == policyVersion;
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      final values = await _remote.list();
      _evidence = Map.unmodifiable({
        for (final value in values) value.purpose: value,
      });
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> setConsent({
    required ConsentPurpose purpose,
    required bool granted,
    required String policyVersion,
  }) async {
    final recorded = await _remote.record(
      purpose: purpose,
      granted: granted,
      policyVersion: policyVersion,
    );
    _evidence = Map.unmodifiable({..._evidence, purpose: recorded});
    notifyListeners();
  }
}
