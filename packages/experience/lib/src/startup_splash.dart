import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:planext4u_api_client/planext4u_api_client.dart';
import 'package:planext4u_storage/planext4u_storage.dart';
import 'package:planext4u_core/planext4u_core.dart';

final class PublicStartupDocument {
  const PublicStartupDocument({
    required this.revision,
    required this.publishedAt,
    required this.country,
    required this.role,
    required this.locale,
    this.version,
    this.title,
    this.message,
    this.visual,
  });
  factory PublicStartupDocument.decode(
    Object? value, {
    required String country,
    required String role,
  }) {
    if (value is! Map<String, Object?> ||
        value.length != 6 ||
        value.keys.any(
          (key) => !{
            'revision',
            'published_at',
            'country',
            'role',
            'locale',
            'splash',
          }.contains(key),
        ) ||
        value['revision'] is! int ||
        (value['revision']! as int) < 1 ||
        value['country'] != country ||
        value['role'] != role ||
        value['locale'] is! String ||
        !isPlanext4uLocaleCode(value['locale']! as String) ||
        value['published_at'] is! String) {
      throw const FormatException('Invalid public startup scope.');
    }
    final published = DateTime.tryParse(value['published_at']! as String);
    if (published == null || !published.isAfter(DateTime.utc(2000))) {
      throw const FormatException('Invalid public startup revision.');
    }
    String? version, title, message, visual;
    final splash = value['splash'];
    if (splash != null) {
      if (splash is! Map<String, Object?> ||
          (splash.length != 3 && splash.length != 4) ||
          splash['version'] is! String ||
          !RegExp(
            r'^[A-Za-z0-9._-]{1,32}$',
          ).hasMatch(splash['version']! as String) ||
          splash['title'] is! String ||
          splash['message'] is! String) {
        throw const FormatException('Invalid public startup content.');
      }
      version = splash['version']! as String;
      title = splash['title']! as String;
      message = splash['message']! as String;
      if (splash.length == 4) {
        final requestedVisual = splash['visual'];
        if (requestedVisual is! String ||
            !const {
              'brand',
              'shopping',
              'services',
              'community',
              'vendor',
            }.contains(requestedVisual)) {
          throw const FormatException('Invalid public startup visual.');
        }
        visual = requestedVisual;
      }
      if (title.trim().isEmpty ||
          title.runes.length > 120 ||
          message.trim().isEmpty ||
          message.runes.length > 1000) {
        throw const FormatException('Public startup text exceeds its bounds.');
      }
    }
    return PublicStartupDocument(
      revision: value['revision']! as int,
      publishedAt: published.toUtc(),
      country: country,
      role: role,
      locale: value['locale']! as String,
      version: version,
      title: title,
      message: message,
      visual: visual,
    );
  }
  final int revision;
  final DateTime publishedAt;
  final String country, role, locale;
  final String? version, title, message, visual;
  Map<String, Object?> toJson() => {
    'revision': revision,
    'published_at': publishedAt.toUtc().toIso8601String(),
    'country': country,
    'role': role,
    'locale': locale,
    'splash': version == null
        ? null
        : {
            'version': version,
            'title': title,
            'message': message,
            if (visual != null) 'visual': visual,
          },
  };
}

abstract interface class PublicStartupRemote {
  Future<PublicStartupDocument> fetch({
    required String country,
    required String role,
    required String locale,
    required ApiCancellationToken cancellation,
  });
}

final class PublicStartupApi implements PublicStartupRemote {
  const PublicStartupApi(this.client);
  final ApiClient client;
  @override
  Future<PublicStartupDocument> fetch({
    required String country,
    required String role,
    required String locale,
    required ApiCancellationToken cancellation,
  }) async => (await client.send(
    ApiRequest.get(
      operation: 'configuration.get_public_startup',
      path: '/v1/startup',
      authRequired: false,
      query: {
        'country': [country],
        'role': [role],
        'locale': [locale],
      },
    ),
    (value) =>
        PublicStartupDocument.decode(value, country: country, role: role),
    cancellationToken: cancellation,
  )).value;
}

abstract interface class PublicStartupStore {
  Future<PublicStartupDocument?> read();
  Future<void> save(PublicStartupDocument document);
}

final class EncryptedPublicStartupStore implements PublicStartupStore {
  EncryptedPublicStartupStore({
    required Uri endpoint,
    required this.country,
    required this.role,
    required String locale,
    EncryptedRecordStore? records,
    DateTime Function()? clock,
  }) : _key =
           'startup-${sha256.convert(utf8.encode(jsonEncode([endpoint.toString(), country, role, locale])))}',
       _clock = clock ?? (() => DateTime.now().toUtc()),
       _records =
           records ??
           EncryptedRecordStore(
             records: FileBinaryRecordStore(namespace: 'public-startup-v1'),
             keyProvider: PlatformCacheKeyProvider(
               namespace: 'planext4u.public.startup.v1',
             ),
             namespace: 'public-startup-v1',
             maxPlaintextBytes: 16384,
           ) {
    if (endpoint.userInfo.isNotEmpty ||
        endpoint.hasQuery ||
        endpoint.hasFragment ||
        !RegExp(r'^[A-Z]{2}$').hasMatch(country) ||
        !{'customer', 'vendor', 'rider'}.contains(role) ||
        !isPlanext4uLocaleCode(locale)) {
      throw const FormatException('Public startup cache scope is invalid.');
    }
  }
  final String country, role, _key;
  final EncryptedRecordStore _records;
  final DateTime Function() _clock;
  static final Map<String, Future<void>> _tails = {};
  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = (_tails[_key] ?? Future<void>.value()).then(
      (_) => operation(),
    );
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _tails[_key] = tail;
    unawaited(
      tail.whenComplete(() {
        if (identical(_tails[_key], tail)) _tails.remove(_key);
      }),
    );
    return result;
  }

  Future<PublicStartupDocument?> _read() async => (await _records.get(
    _key,
    (value) =>
        PublicStartupDocument.decode(value, country: country, role: role),
  )).value;
  @override
  Future<PublicStartupDocument?> read() => _serialize(_read);
  @override
  Future<void> save(PublicStartupDocument document) => _serialize(() async {
    // Never mix scopes or let a late old launch overwrite a newer publication.
    final safe = PublicStartupDocument.decode(
      document.toJson(),
      country: country,
      role: role,
    );
    final previous = await _read();
    if (previous != null && previous.revision > safe.revision) return;
    if (previous != null &&
        previous.revision == safe.revision &&
        jsonEncode(previous.toJson()) != jsonEncode(safe.toJson())) {
      throw const FormatException(
        'A startup revision changed without publication.',
      );
    }
    final expiry = _clock().add(const Duration(hours: 1));
    await _records.put(
      _key,
      safe.toJson(),
      expiresAt: expiry,
      staleUntil: expiry,
    );
  });
}

/// Public display content only. This controller never obtains identity proof,
/// registers devices, changes consent or blocks the real runtime on a network.
final class PublicStartupController extends ChangeNotifier {
  PublicStartupController({
    required PublicStartupRemote remote,
    required PublicStartupStore store,
    required this.country,
    required this.role,
    required this.locale,
  }) : _remote = remote,
       _store = store {
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(country) ||
        !{'customer', 'vendor', 'rider'}.contains(role) ||
        !isPlanext4uLocaleCode(locale)) {
      throw const FormatException('Public startup request scope is invalid.');
    }
  }
  final PublicStartupRemote _remote;
  final PublicStartupStore _store;
  final String country, role, locale;
  final ApiCancellationToken _cancellation = ApiCancellationToken();
  bool _closed = false, _started = false;
  bool loading = true, offline = false;
  PublicStartupDocument? document;
  Future<void> load() async {
    if (_closed || _started) return;
    _started = true;
    final cached = _readCached();
    try {
      final next = await Future.any<PublicStartupDocument>([
        _remote.fetch(
          country: country,
          role: role,
          locale: locale,
          cancellation: _cancellation,
        ),
        _cancellation.whenCancelled.then(
          (_) => throw const TransportCancelledException(),
        ),
      ]).timeout(const Duration(milliseconds: 1000));
      final previous = await cached;
      if (_closed) return;
      final safe = PublicStartupDocument.decode(
        next.toJson(),
        country: country,
        role: role,
      );
      if (previous != null &&
          (previous.revision > safe.revision ||
              previous.revision == safe.revision &&
                  jsonEncode(previous.toJson()) != jsonEncode(safe.toJson()))) {
        offline = true;
        return;
      }
      document = safe;
      offline = false;
      notifyListeners();
      unawaited(_store.save(safe).catchError((Object _) {}));
    } catch (_) {
      if (!_closed) offline = true;
    } finally {
      if (!_closed) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<PublicStartupDocument?> _readCached() async {
    try {
      final previous = await Future.any<PublicStartupDocument?>([
        _store.read(),
        _cancellation.whenCancelled.then((_) => null),
      ]).timeout(const Duration(milliseconds: 250));
      if (_closed || previous == null) return null;
      final safe = PublicStartupDocument.decode(
        previous.toJson(),
        country: country,
        role: role,
      );
      document = safe;
      notifyListeners();
      return safe;
    } catch (_) {
      return null;
    }
  }

  void stop() {
    if (_closed) return;
    _closed = true;
    _cancellation.cancel();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
