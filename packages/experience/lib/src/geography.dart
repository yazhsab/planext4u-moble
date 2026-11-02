import 'package:flutter/foundation.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';

const geographyKinds = ['COUNTRY', 'STATE', 'DISTRICT', 'CITY', 'AREA'];
final _geographyId = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);
Map<String, Object?> _geoObject(Object? value) {
  if (value is! Map<String, Object?>) {
    throw const FormatException('Invalid geography response.');
  }
  return value;
}

String _geoText(Map<String, Object?> json, String key, int maximum) {
  final value = json[key];
  if (value is! String ||
      value.isEmpty ||
      value.trim() != value ||
      value.runes.length > maximum ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
    throw const FormatException('Invalid geography text.');
  }
  return value;
}

final class GeographyReference {
  const GeographyReference({
    required this.id,
    required this.country,
    required this.kind,
    required this.code,
    required this.nameEN,
    required this.nameTA,
    required this.masterRevision,
    this.parentID,
  });
  factory GeographyReference.fromJson(Object? value) {
    final json = _geoObject(value);
    final id = _geoText(json, 'id', 36),
        country = _geoText(json, 'country', 2),
        kind = _geoText(json, 'kind', 16),
        code = _geoText(json, 'code', 64);
    final parent = json['parent_id'], revision = json['master_revision'];
    if (!_geographyId.hasMatch(id) ||
        !RegExp(r'^[A-Z]{2}$').hasMatch(country) ||
        !geographyKinds.contains(kind) ||
        !RegExp(r'^[A-Z][A-Z0-9_]{0,63}$').hasMatch(code) ||
        revision is! int ||
        revision < 1 ||
        (kind == 'COUNTRY'
            ? parent != null || code != country
            : parent is! String || !_geographyId.hasMatch(parent))) {
      throw const FormatException('Invalid geography reference.');
    }
    return GeographyReference(
      id: id,
      country: country,
      kind: kind,
      code: code,
      parentID: parent as String?,
      nameEN: _geoText(json, 'name_en', 128),
      nameTA: _geoText(json, 'name_ta', 128),
      masterRevision: revision,
    );
  }
  final String id, country, kind, code, nameEN, nameTA;
  final String? parentID;
  final int masterRevision;
  String label(String locale) => locale.startsWith('ta') ? nameTA : nameEN;
  Map<String, Object?> toJson() => {
    'id': id,
    'country': country,
    'kind': kind,
    'code': code,
    'parent_id': parentID,
    'name_en': nameEN,
    'name_ta': nameTA,
    'master_revision': masterRevision,
  };
}

final class AddressGeography {
  AddressGeography({
    required this.areaID,
    required List<GeographyReference> path,
  }) : path = List.unmodifiable(path) {
    if (!_geographyId.hasMatch(areaID) ||
        path.length != 5 ||
        path.last.id != areaID ||
        path.map((e) => e.id).toSet().length != 5) {
      throw const FormatException('Invalid address geography.');
    }
    for (var i = 0; i < path.length; i++) {
      if (path[i].kind != geographyKinds[i] ||
          path[i].country != path.first.country ||
          (i == 0
              ? path[i].parentID != null
              : path[i].parentID != path[i - 1].id)) {
        throw const FormatException('Invalid address geography ancestry.');
      }
    }
  }
  factory AddressGeography.fromJson(Object? value) {
    final json = _geoObject(value), rows = _geoObject(value)['path'];
    if (rows is! List || rows.length != 5) {
      throw const FormatException('Invalid address geography path.');
    }
    return AddressGeography(
      areaID: _geoText(json, 'area_id', 36),
      path: rows.map(GeographyReference.fromJson).toList(),
    );
  }
  final String areaID;
  final List<GeographyReference> path;
  String get country => path.first.country;
  String label(String locale) =>
      path.skip(1).map((e) => e.label(locale)).join(' / ');
  Map<String, Object?> toJson() => {
    'area_id': areaID,
    'path': path.map((e) => e.toJson()).toList(),
  };
}

final class GeographyPage {
  GeographyPage({
    required this.country,
    required this.kind,
    required List<GeographyReference> items,
    this.parentID,
    this.nextAfter,
  }) : items = List.unmodifiable(items);
  factory GeographyPage.fromJson(Object? value) {
    final json = _geoObject(value), rows = _geoObject(value)['items'];
    final country = _geoText(json, 'country', 2),
        kind = _geoText(json, 'kind', 16);
    final parent = json['parent_id'], after = json['next_after'];
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(country) ||
        !geographyKinds.contains(kind) ||
        rows is! List ||
        rows.length > 50 ||
        (kind == 'COUNTRY'
            ? parent != null
            : parent is! String || !_geographyId.hasMatch(parent)) ||
        after != null && (after is! String || !_geographyId.hasMatch(after))) {
      throw const FormatException('Invalid geography page.');
    }
    final items = rows.map(GeographyReference.fromJson).toList();
    if (items.map((e) => e.id).toSet().length != items.length ||
        items.any(
          (e) => e.country != country || e.kind != kind || e.parentID != parent,
        ) ||
        after != null && (items.length != 50 || items.last.id != after)) {
      throw const FormatException('Invalid geography page scope.');
    }
    return GeographyPage(
      country: country,
      kind: kind,
      parentID: parent as String?,
      items: items,
      nextAfter: after as String?,
    );
  }
  final String country, kind;
  final String? parentID, nextAfter;
  final List<GeographyReference> items;
}

abstract interface class GeographyDirectory {
  Future<GeographyPage> search({
    required String kind,
    String? parentID,
    String query = '',
    String? after,
  });
}

final class GeographyApi implements GeographyDirectory {
  const GeographyApi(this.client, {required this.country});
  final ApiClient client;
  final String country;
  @override
  Future<GeographyPage> search({
    required String kind,
    String? parentID,
    String query = '',
    String? after,
  }) async {
    final response = await client.send(
      ApiRequest.get(
        operation: 'configuration.list_geography',
        path: '/v1/geography',
        query: {
          'kind': [kind],
          if (parentID != null) 'parent_id': [parentID],
          if (query.isNotEmpty) 'search': [query],
          if (after != null) 'after': [after],
        },
      ),
      GeographyPage.fromJson,
    );
    final page = response.value;
    if (page.country != country ||
        page.kind != kind ||
        page.parentID != parentID) {
      throw const FormatException('Geography response scope changed.');
    }
    return page;
  }
}

enum GeographyStatus { idle, loading, ready, failure }

final class GeographyController extends ChangeNotifier {
  GeographyController(
    this.directory, {
    required this.country,
    bool Function()? scopeIsCurrent,
  }) : _scopeIsCurrent = scopeIsCurrent ?? (() => true);
  final GeographyDirectory directory;
  final String country;
  final bool Function() _scopeIsCurrent;
  var _disposed = false;
  var _generation = 0;
  List<GeographyReference> _path = [];
  GeographyPage? _page;
  GeographyStatus _status = GeographyStatus.idle;
  String _query = '';
  List<GeographyReference> get path =>
      _current ? List.unmodifiable(_path) : const [];
  GeographyPage? get page => _current ? _page : null;
  GeographyStatus get status => _current ? _status : GeographyStatus.idle;
  String get kind => geographyKinds[_path.length.clamp(0, 4)];
  bool get _current => !_disposed && _scopeIsCurrent();
  AddressGeography? get selection => _current && _path.length == 5
      ? AddressGeography(areaID: _path.last.id, path: _path)
      : null;
  Future<void> load({String query = '', String? after}) async {
    if (!_current || _path.length == 5) return;
    final generation = ++_generation,
        requestedKind = kind,
        parent = _path.isEmpty ? null : _path.last.id;
    _query = query;
    _status = GeographyStatus.loading;
    _page = null;
    notifyListeners();
    try {
      final result = await directory.search(
        kind: requestedKind,
        parentID: parent,
        query: query,
        after: after,
      );
      if (!_current || generation != _generation) return;
      if (result.country != country ||
          result.kind != requestedKind ||
          result.parentID != parent) {
        throw const FormatException('Geography scope changed.');
      }
      _page = result;
      _status = GeographyStatus.ready;
    } catch (_) {
      if (!_current || generation != _generation) return;
      _status = GeographyStatus.failure;
    }
    if (_current) notifyListeners();
  }

  Future<bool> choose(GeographyReference reference) async {
    if (!_current ||
        _status != GeographyStatus.ready ||
        _page == null ||
        !_page!.items.any(
          (e) =>
              e.id == reference.id &&
              e.masterRevision == reference.masterRevision,
        )) {
      return false;
    }
    _path = [..._path, reference];
    ++_generation;
    _page = null;
    if (_path.length < 5) {
      await load();
    } else {
      _status = GeographyStatus.ready;
      notifyListeners();
    }
    return _current;
  }

  Future<void> back() async {
    if (!_current || _path.isEmpty) return;
    _path = _path.sublist(0, _path.length - 1);
    await load();
  }

  Future<void> retry() => load(query: _query);
  Future<void> next() => load(query: _query, after: _page?.nextAfter);
  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _path = [];
    _page = null;
    super.dispose();
  }
}
