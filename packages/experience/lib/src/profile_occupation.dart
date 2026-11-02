import 'package:flutter/foundation.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';

final _occupationId = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);
Map<String, Object?> _object(Object? value) {
  if (value is! Map<String, Object?>) {
    throw const FormatException('Invalid occupation response.');
  }
  return value;
}

String _text(Map<String, Object?> json, String key, int maximum) {
  final value = json[key];
  if (value is! String ||
      value.isEmpty ||
      value.trim() != value ||
      value.runes.length > maximum ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
    throw const FormatException('Invalid occupation text.');
  }
  return value;
}

final class ProfileOccupation {
  const ProfileOccupation({
    required this.id,
    required this.code,
    required this.country,
    required this.nameEN,
    required this.nameTA,
    required this.masterRevision,
  });
  factory ProfileOccupation.fromJson(Object? value, {String? country}) {
    final json = _object(value);
    final id = _text(json, 'id', 36), code = _text(json, 'code', 64);
    final region = country ?? _text(json, 'country', 2);
    final revision = json['master_revision'];
    if (!_occupationId.hasMatch(id) ||
        !RegExp(r'^[A-Z][A-Z0-9_]{0,63}$').hasMatch(code) ||
        !RegExp(r'^[A-Z]{2}$').hasMatch(region) ||
        revision is! int ||
        revision < 1) {
      throw const FormatException('Invalid occupation reference.');
    }
    return ProfileOccupation(
      id: id,
      code: code,
      country: region,
      nameEN: _text(json, 'name_en', 128),
      nameTA: _text(json, 'name_ta', 128),
      masterRevision: revision,
    );
  }
  final String id, code, country, nameEN, nameTA;
  final int masterRevision;
  String label(String locale) => locale.startsWith('ta') ? nameTA : nameEN;
  Map<String, Object?> toJson() => {
    'id': id,
    'code': code,
    'country': country,
    'name_en': nameEN,
    'name_ta': nameTA,
    'master_revision': masterRevision,
  };
}

final class ProfileOccupationSelection {
  const ProfileOccupationSelection({
    required this.country,
    required this.revision,
    this.occupation,
    this.updatedAt,
  });
  factory ProfileOccupationSelection.fromJson(Object? value) {
    final json = _object(value);
    final country = _text(json, 'country', 2);
    final revision = json['revision'];
    final updated = json['updated_at'];
    final date = updated is String ? DateTime.tryParse(updated) : null;
    final occupation = json['occupation'] == null
        ? null
        : ProfileOccupation.fromJson(json['occupation']);
    if (!json.containsKey('occupation') ||
        !RegExp(r'^[A-Z]{2}$').hasMatch(country) ||
        revision is! int ||
        revision < 0 ||
        revision == 0 && (occupation != null || updated != null) ||
        revision > 0 &&
            (date == null ||
                updated is! String ||
                !RegExp(r'(Z|[+-][0-9]{2}:[0-9]{2})$').hasMatch(updated)) ||
        occupation != null && occupation.country != country) {
      throw const FormatException('Invalid occupation selection.');
    }
    return ProfileOccupationSelection(
      country: country,
      revision: revision,
      occupation: occupation,
      updatedAt: date?.toUtc(),
    );
  }
  final String country;
  final int revision;
  final ProfileOccupation? occupation;
  final DateTime? updatedAt;
  Map<String, Object?> toJson() => {
    'country': country,
    'occupation': occupation?.toJson(),
    'revision': revision,
    if (updatedAt case final date?)
      'updated_at': date.toUtc().toIso8601String(),
  };
}

final class ProfileOccupationPage {
  const ProfileOccupationPage({
    required this.country,
    required this.items,
    this.nextAfter,
  });
  factory ProfileOccupationPage.fromJson(Object? value) {
    final json = _object(value), country = _text(_object(value), 'country', 2);
    final rows = json['items'], after = json['next_after'];
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(country) ||
        rows is! List ||
        rows.length > 50 ||
        after != null && (after is! String || !_occupationId.hasMatch(after))) {
      throw const FormatException('Invalid occupation page.');
    }
    final items = rows
        .map((row) => ProfileOccupation.fromJson(row, country: country))
        .toList(growable: false);
    if (items.map((item) => item.id).toSet().length != items.length ||
        after != null && (items.isEmpty || items.last.id != after)) {
      throw const FormatException('Invalid occupation pagination.');
    }
    return ProfileOccupationPage(
      country: country,
      items: List.unmodifiable(items),
      nextAfter: after as String?,
    );
  }
  final String country;
  final List<ProfileOccupation> items;
  final String? nextAfter;
}

abstract interface class ProfileOccupationRemote {
  Future<ProfileOccupationSelection> current();
  Future<ProfileOccupationPage> search(String term, {String? after});
  Future<ProfileOccupationSelection> save(String? id, int revision);
}

final class ProfileOccupationApi implements ProfileOccupationRemote {
  const ProfileOccupationApi(this._client, {required this.country});
  final ApiClient _client;
  final String country;
  @override
  Future<ProfileOccupationSelection> current() async {
    final value = (await _client.send(
      ApiRequest.get(
        operation: 'identity.occupation_current',
        path: '/v1/me/occupation',
      ),
      ProfileOccupationSelection.fromJson,
    )).value;
    if (value.country != country) {
      throw const FormatException('Occupation country mismatch.');
    }
    return value;
  }

  @override
  Future<ProfileOccupationPage> search(String term, {String? after}) async {
    if (term.runes.length > 128 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(term) ||
        after != null && !_occupationId.hasMatch(after)) {
      throw const FormatException('Invalid occupation search.');
    }
    final value = (await _client.send(
      ApiRequest.get(
        operation: 'configuration.occupation_search',
        path: '/v1/occupations',
        query: {
          'search': [term],
          if (after != null) 'after': [after],
        },
      ),
      ProfileOccupationPage.fromJson,
    )).value;
    if (value.country != country) {
      throw const FormatException('Occupation country mismatch.');
    }
    return value;
  }

  @override
  Future<ProfileOccupationSelection> save(String? id, int revision) async {
    if (revision < 0 || id != null && !_occupationId.hasMatch(id)) {
      throw const FormatException('Invalid occupation selection.');
    }
    final value = (await _client.send(
      ApiRequest(
        operation: 'identity.occupation_save',
        method: 'PUT',
        path: '/v1/me/occupation',
        body: {'occupation_id': id ?? '', 'expected_revision': revision},
        replayPolicy: ApiReplayPolicy.never,
      ),
      ProfileOccupationSelection.fromJson,
    )).value;
    if (value.country != country) {
      throw const FormatException('Occupation country mismatch.');
    }
    return value;
  }
}

final class ProfileOccupationState {
  const ProfileOccupationState({
    this.current,
    this.page,
    this.search = '',
    this.busy = false,
    this.failed = false,
    this.saved = false,
  });
  final ProfileOccupationSelection? current;
  final ProfileOccupationPage? page;
  final String search;
  final bool busy, failed, saved;
}

final class ProfileOccupationController extends ChangeNotifier {
  ProfileOccupationController(
    this._remote, {
    required bool Function() scopeIsCurrent,
  }) : _scopeIsCurrent = scopeIsCurrent;
  final ProfileOccupationRemote _remote;
  final bool Function() _scopeIsCurrent;
  ProfileOccupationState _state = const ProfileOccupationState();
  ProfileOccupationState get state => _state;
  bool _disposed = false;
  int _generation = 0;
  bool _valid(int generation) =>
      !_disposed && _scopeIsCurrent() && generation == _generation;
  void _set(ProfileOccupationState state) {
    if (!_disposed && _scopeIsCurrent()) {
      _state = state;
      notifyListeners();
    }
  }

  Future<void> load() async => search(_state.search, refresh: true);
  Future<void> search(
    String term, {
    String? after,
    bool refresh = false,
  }) async {
    if (_disposed || !_scopeIsCurrent() || _state.busy) return;
    final generation = ++_generation;
    _set(
      ProfileOccupationState(current: _state.current, search: term, busy: true),
    );
    try {
      final current = refresh || _state.current == null
          ? await _remote.current()
          : _state.current!;
      if (!_valid(generation)) return;
      final page = await _remote.search(term, after: after);
      if (!_valid(generation)) return;
      if (page.country != current.country) {
        throw const FormatException('Occupation country mismatch.');
      }
      _set(ProfileOccupationState(current: current, page: page, search: term));
    } catch (_) {
      if (_valid(generation)) {
        _set(
          ProfileOccupationState(
            current: _state.current,
            search: term,
            failed: true,
          ),
        );
      }
    }
  }

  Future<void> save(String? id) async {
    final current = _state.current;
    if (_disposed ||
        !_scopeIsCurrent() ||
        _state.busy ||
        _state.failed ||
        current == null) {
      return;
    }
    if (id != null &&
        id != current.occupation?.id &&
        !(_state.page?.items.any((item) => item.id == id) ?? false)) {
      throw const FormatException('Choose an available occupation.');
    }
    final generation = ++_generation, page = _state.page, term = _state.search;
    _set(
      ProfileOccupationState(
        current: current,
        page: page,
        search: term,
        busy: true,
      ),
    );
    try {
      final value = await _remote.save(id, current.revision);
      if (!_valid(generation)) return;
      if (value.country != current.country ||
          value.occupation?.id != id ||
          value.revision < current.revision ||
          value.revision == current.revision && id != current.occupation?.id) {
        throw const FormatException('Occupation save was not confirmed.');
      }
      _set(
        ProfileOccupationState(
          current: value,
          page: page,
          search: term,
          saved: true,
        ),
      );
    } catch (_) {
      if (_valid(generation)) {
        _set(
          ProfileOccupationState(
            current: current,
            page: page,
            search: term,
            failed: true,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _state = const ProfileOccupationState();
    super.dispose();
  }
}
