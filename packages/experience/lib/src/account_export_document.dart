import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'profile_occupation.dart';

/// A portable copy of the explicitly supported identity export fields. Unknown
/// server fields (including any accidentally added credential) are not copied.
final class AccountExportDocument {
  AccountExportDocument._(this.json, this.fileName, this.excluded);

  factory AccountExportDocument.fromJson(Map<String, Object?> source) {
    final version = source['schema_version'];
    if (version != 1 && version != 2 && version != 3 && version != 4) {
      throw const FormatException('Unsupported account export version.');
    }
    final generatedAt = DateTime.parse(
      source['generated_at']! as String,
    ).toUtc();
    final stamp = generatedAt
        .toIso8601String()
        .split('.')
        .first
        .replaceAll('-', '')
        .replaceAll(':', '');
    final coverage = _object(source['coverage']);
    final included = _strings(coverage['included']);
    final excluded = _strings(coverage['excluded']);
    final portable = _project(source, {
      'schema_version',
      'generated_at',
      'identity_id',
      'tenant_id',
      'country',
    });
    portable['roles'] = _strings(source['roles']);
    portable['coverage'] = {'included': included, 'excluded': excluded};
    portable['profile'] = _project(_object(source['profile']), {
      'display_name',
      'email',
      'phone',
      'locale',
      'time_zone',
      'version',
      'updated_at',
    });
    portable['sessions'] = _records(source['sessions'], {
      'id',
      'device_reference',
      'country',
      'authenticated_at',
      'last_seen_at',
      'expires_at',
      'revoked_at',
      'current',
    });
    const consentFields = {
      'evidence_id',
      'purpose',
      'granted',
      'policy_version',
      'recorded_at',
      'version',
    };
    portable['consents'] = _records(source['consents'], consentFields);
    portable['consent_history'] = _records(source['consent_history'], {
      ...consentFields,
      'country',
    });
    if (version == 2 || version == 3 || version == 4) {
      final snapshots = _records(source['contact_snapshots'], {
        'country',
        'revision',
        'contact_count',
        'policy_version',
        'expires_at',
      });
      for (final snapshot in snapshots) {
        final country = snapshot['country'];
        final revision = snapshot['revision'];
        final count = snapshot['contact_count'];
        final policy = snapshot['policy_version'];
        final expiry = snapshot['expires_at'];
        if (country is! String ||
            !RegExp(r'^[A-Z]{2}$').hasMatch(country) ||
            revision is! int ||
            revision < 1 ||
            count is! int ||
            count < 0 ||
            count > 10000 ||
            (policy != null && (policy is! String || policy.length > 64)) ||
            (expiry != null &&
                (expiry is! String || DateTime.tryParse(expiry) == null))) {
          throw const FormatException('Invalid contact snapshot metadata.');
        }
      }
      portable['contact_snapshots'] = snapshots;
    }
    if (version == 3 || version == 4) {
      final history = _records(source['deletion_history'], {
        'id',
        'status',
        'reason',
        'requested_at',
        'effective_at',
      });
      for (final request in history) {
        final id = request['id'];
        final status = request['status'];
        final reason = request['reason'];
        final requestedAt = request['requested_at'];
        final effectiveAt = request['effective_at'];
        final requested = requestedAt is String
            ? DateTime.tryParse(requestedAt)
            : null;
        final effective = effectiveAt is String
            ? DateTime.tryParse(effectiveAt)
            : null;
        if (id is! String ||
            !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id) ||
            status is! String ||
            !{'SCHEDULED', 'CANCELLED', 'COMPLETED'}.contains(status) ||
            reason is! String ||
            reason.runes.length > 500 ||
            requested == null ||
            effective == null ||
            effective.isBefore(requested)) {
          throw const FormatException('Invalid deletion request history.');
        }
      }
      portable['deletion_history'] = history;
      if (source.containsKey('occupation_references')) {
        final rows = source['occupation_references'];
        if (rows is! List || rows.length > 10000) {
          throw const FormatException('Invalid occupation export.');
        }
        final selections = rows
            .map(ProfileOccupationSelection.fromJson)
            .toList(growable: false);
        if (selections.map((item) => item.country).toSet().length !=
            selections.length) {
          throw const FormatException('Duplicate occupation export.');
        }
        portable['occupation_references'] = selections
            .map((item) => item.toJson())
            .toList(growable: false);
      }
    }
    if (version == 4) {
      final vendor = _records(source['vendor_applications'], {
        'country',
        'revision',
        'status',
        'business_name',
        'business_type',
        'contact_name',
        'created_at',
        'updated_at',
      });
      for (final application in vendor) {
        _validateParticipantRecord(application, {
          'business_name',
          'business_type',
          'contact_name',
        });
      }
      portable['vendor_applications'] = vendor;
      final rider = _records(source['rider_profiles'], {
        'country',
        'revision',
        'status',
        'full_name',
        'vehicle_type',
        'vehicle_number',
        'created_at',
        'updated_at',
      });
      final sourceRiders = source['rider_profiles']! as List;
      for (var i = 0; i < rider.length; i++) {
        final profile = rider[i];
        _validateParticipantRecord(profile, {
          'full_name',
          'vehicle_type',
          'vehicle_number',
        });
        final zones = _object(sourceRiders[i])['zones'];
        if (zones is! List ||
            zones.length > 20 ||
            zones.any(
              (zone) =>
                  zone is! String ||
                  !RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(zone),
            ) ||
            zones.toSet().length != zones.length) {
          throw const FormatException('Invalid rider service zones.');
        }
        profile['zones'] = List<String>.unmodifiable(zones.cast<String>());
      }
      portable['rider_profiles'] = rider;
    }
    final encoded = jsonEncode(portable);
    if (utf8.encode(encoded).length > 4 * 1024 * 1024) {
      throw const FormatException('The account export is too large.');
    }
    return AccountExportDocument._(
      encoded,
      'planext4u-account-${stamp}Z.json',
      List.unmodifiable(excluded),
    );
  }

  final String json;
  final String fileName;
  final List<String> excluded;
  Uint8List get bytes => Uint8List.fromList(utf8.encode(json));

  static Map<String, Object?> _object(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const FormatException('Invalid account export object.');
    }
    return value;
  }

  static List<String> _strings(Object? value) {
    if (value is! List || value.any((item) => item is! String)) {
      throw const FormatException('Invalid account export list.');
    }
    return value.cast<String>();
  }

  static List<Map<String, Object?>> _records(
    Object? value,
    Set<String> fields,
  ) {
    if (value is! List || value.length > 10000) {
      throw const FormatException('Invalid account export records.');
    }
    return value.map((item) => _project(_object(item), fields)).toList();
  }

  static Map<String, Object?> _project(
    Map<String, Object?> source,
    Set<String> fields,
  ) {
    final result = <String, Object?>{};
    for (final key in fields) {
      if (!source.containsKey(key)) continue;
      final value = source[key];
      if (value != null &&
          value is! String &&
          value is! num &&
          value is! bool) {
        throw const FormatException('Invalid account export field.');
      }
      result[key] = value;
    }
    return result;
  }

  static void _validateParticipantRecord(
    Map<String, Object?> row,
    Set<String> detailFields,
  ) {
    final country = row['country'];
    final revision = row['revision'];
    final status = row['status'];
    final created = row['created_at'];
    final updated = row['updated_at'];
    final createdAt = created is String ? DateTime.tryParse(created) : null;
    final updatedAt = updated is String ? DateTime.tryParse(updated) : null;
    if (country is! String ||
        !RegExp(r'^[A-Z]{2}$').hasMatch(country) ||
        revision is! int ||
        revision < 1 ||
        status is! String ||
        !RegExp(r'^[A-Z_]{1,64}$').hasMatch(status) ||
        createdAt == null ||
        updatedAt == null ||
        updatedAt.isBefore(createdAt) ||
        detailFields.any((field) {
          final value = row[field];
          return value is! String || value.isEmpty || value.runes.length > 120;
        })) {
      throw const FormatException('Invalid participant export record.');
    }
  }
}
