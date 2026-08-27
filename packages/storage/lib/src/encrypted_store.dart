import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

abstract interface class CacheKeyProvider {
  Future<SecretKey> getOrCreate();
  Future<void> destroy();
}

final class PlatformCacheKeyProvider implements CacheKeyProvider {
  PlatformCacheKeyProvider({
    FlutterSecureStorage? storage,
    String namespace = 'planext4u.cache.v1',
    AesGcm? algorithm,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _keyName = '$namespace.key',
       _algorithm = algorithm ?? AesGcm.with256bits();

  final FlutterSecureStorage _storage;
  final String _keyName;
  final AesGcm _algorithm;

  @override
  Future<SecretKey> getOrCreate() async {
    final encoded = await _storage.read(key: _keyName);
    if (encoded != null) {
      try {
        final bytes = base64Url.decode(encoded);
        if (bytes.length != 32) throw const FormatException('Invalid key.');
        return SecretKey(bytes);
      } catch (_) {
        await destroy();
      }
    }
    final key = await _algorithm.newSecretKey();
    final bytes = await key.extractBytes();
    await _storage.write(key: _keyName, value: base64UrlEncode(bytes));
    return key;
  }

  @override
  Future<void> destroy() => _storage.delete(key: _keyName);
}

final class MemoryCacheKeyProvider implements CacheKeyProvider {
  MemoryCacheKeyProvider([List<int>? bytes])
    : _bytes = bytes ?? List<int>.generate(32, (index) => index + 1);
  List<int>? _bytes;

  @override
  Future<SecretKey> getOrCreate() async {
    _bytes ??= List<int>.generate(32, (index) => 32 - index);
    return SecretKey(_bytes!);
  }

  @override
  Future<void> destroy() async => _bytes = null;
}

abstract interface class BinaryRecordStore {
  Future<Uint8List?> read(String key);
  Future<void> writeAtomic(String key, Uint8List value);
  Future<void> delete(String key);
  Future<void> clear();
}

final class FileBinaryRecordStore implements BinaryRecordStore {
  FileBinaryRecordStore({
    required this.namespace,
    Future<Directory> Function()? directory,
  }) : _directory = directory ?? getApplicationSupportDirectory {
    if (!_safeKey.hasMatch(namespace)) {
      throw const FormatException('Storage namespace is invalid.');
    }
  }

  final String namespace;
  final Future<Directory> Function() _directory;

  Future<Directory> _root() async {
    final support = await _directory();
    final root = Directory('${support.path}/planext4u/$namespace');
    if (!root.existsSync()) await root.create(recursive: true);
    return root;
  }

  @override
  Future<Uint8List?> read(String key) async {
    final file = await _file(key);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  @override
  Future<void> writeAtomic(String key, Uint8List value) async {
    final file = await _file(key);
    final temporary = File('${file.path}.pending');
    await temporary.writeAsBytes(value, flush: true);
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }

  @override
  Future<void> delete(String key) async {
    final file = await _file(key);
    if (await file.exists()) await file.delete();
    final temporary = File('${file.path}.pending');
    if (await temporary.exists()) await temporary.delete();
  }

  @override
  Future<void> clear() async {
    final root = await _root();
    if (await root.exists()) await root.delete(recursive: true);
  }

  Future<File> _file(String key) async {
    if (!_safeKey.hasMatch(key)) {
      throw const FormatException('Storage key is invalid.');
    }
    return File('${(await _root()).path}/$key.p4u');
  }
}

final class MemoryBinaryRecordStore implements BinaryRecordStore {
  final Map<String, Uint8List> _values = {};

  void corrupt(String key) => _values[key] = Uint8List.fromList([1, 2, 3]);
  bool contains(String key) => _values.containsKey(key);

  @override
  Future<void> clear() async => _values.clear();
  @override
  Future<void> delete(String key) async => _values.remove(key);
  @override
  Future<Uint8List?> read(String key) async {
    final value = _values[key];
    return value == null ? null : Uint8List.fromList(value);
  }

  @override
  Future<void> writeAtomic(String key, Uint8List value) async {
    _values[key] = Uint8List.fromList(value);
  }
}

enum CacheFreshness { missing, fresh, stale, expired, corrupt }

final class CacheRead<T> {
  const CacheRead({required this.freshness, this.value});
  final CacheFreshness freshness;
  final T? value;
}

typedef StorageClock = DateTime Function();

final class EncryptedRecordStore {
  EncryptedRecordStore({
    required BinaryRecordStore records,
    required CacheKeyProvider keyProvider,
    String namespace = 'mobile',
    AesGcm? algorithm,
    StorageClock clock = _utcNow,
    this.maxPlaintextBytes = 2 << 20,
  }) : _records = records,
       _keys = keyProvider,
       _namespace = namespace,
       _algorithm = algorithm ?? AesGcm.with256bits(),
       _clock = clock {
    if (!_safeKey.hasMatch(namespace) ||
        maxPlaintextBytes < 1 ||
        maxPlaintextBytes > 16 << 20) {
      throw const FormatException('Encrypted store configuration is invalid.');
    }
  }

  final BinaryRecordStore _records;
  final CacheKeyProvider _keys;
  final String _namespace;
  final AesGcm _algorithm;
  final StorageClock _clock;
  final int maxPlaintextBytes;

  Future<void> put(
    String key,
    Object? value, {
    required DateTime expiresAt,
    required DateTime staleUntil,
  }) async {
    _validateKey(key);
    final now = _clock().toUtc();
    if (!expiresAt.isUtc ||
        !staleUntil.isUtc ||
        !expiresAt.isAfter(now) ||
        staleUntil.isBefore(expiresAt)) {
      throw const FormatException('Cache lifetime is invalid.');
    }
    final plaintext = utf8.encode(
      jsonEncode({
        'schema': 1,
        'written_at': now.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'stale_until': staleUntil.toIso8601String(),
        'value': value,
      }),
    );
    if (plaintext.length > maxPlaintextBytes) {
      throw const FormatException('Cache value exceeds the size limit.');
    }
    final secretBox = await _algorithm.encrypt(
      plaintext,
      secretKey: await _keys.getOrCreate(),
      aad: _associatedData(key),
    );
    final envelope = utf8.encode(
      jsonEncode({
        'schema': 1,
        'nonce': base64UrlEncode(secretBox.nonce),
        'ciphertext': base64UrlEncode(secretBox.cipherText),
        'mac': base64UrlEncode(secretBox.mac.bytes),
      }),
    );
    await _records.writeAtomic(key, Uint8List.fromList(envelope));
  }

  Future<CacheRead<T>> get<T>(
    String key,
    T Function(Object? value) decode,
  ) async {
    _validateKey(key);
    final envelopeBytes = await _records.read(key);
    if (envelopeBytes == null) {
      return const CacheRead(freshness: CacheFreshness.missing);
    }
    try {
      final envelope = jsonDecode(utf8.decode(envelopeBytes));
      if (envelope is! Map<String, Object?> || envelope['schema'] != 1) {
        throw const FormatException('Encrypted envelope is invalid.');
      }
      final box = SecretBox(
        base64Url.decode(envelope['ciphertext']! as String),
        nonce: base64Url.decode(envelope['nonce']! as String),
        mac: Mac(base64Url.decode(envelope['mac']! as String)),
      );
      final plaintext = await _algorithm.decrypt(
        box,
        secretKey: await _keys.getOrCreate(),
        aad: _associatedData(key),
      );
      final decoded = jsonDecode(utf8.decode(plaintext));
      if (decoded is! Map<String, Object?> || decoded['schema'] != 1) {
        throw const FormatException('Cache record is invalid.');
      }
      final expiresAt = DateTime.parse(decoded['expires_at']! as String);
      final staleUntil = DateTime.parse(decoded['stale_until']! as String);
      final now = _clock().toUtc();
      if (!staleUntil.isAfter(now)) {
        await _records.delete(key);
        return const CacheRead(freshness: CacheFreshness.expired);
      }
      return CacheRead(
        freshness: expiresAt.isAfter(now)
            ? CacheFreshness.fresh
            : CacheFreshness.stale,
        value: decode(decoded['value']),
      );
    } catch (_) {
      await _records.delete(key);
      return const CacheRead(freshness: CacheFreshness.corrupt);
    }
  }

  Future<void> delete(String key) => _records.delete(key);

  Future<void> purge({bool destroyKey = false}) async {
    await _records.clear();
    if (destroyKey) await _keys.destroy();
  }

  List<int> _associatedData(String key) =>
      utf8.encode('planext4u|1|$_namespace|$key');

  void _validateKey(String key) {
    if (!_safeKey.hasMatch(key)) {
      throw const FormatException('Storage key is invalid.');
    }
  }
}

final _safeKey = RegExp(r'^[a-z][a-z0-9._-]{0,127}$');
DateTime _utcNow() => DateTime.now().toUtc();
