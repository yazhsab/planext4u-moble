import 'dart:convert';
import 'dart:math';

enum ApiReplayPolicy { never, safe, idempotent }

final class ApiRequest {
  ApiRequest({
    required this.operation,
    required this.method,
    required this.path,
    Map<String, List<String>> query = const {},
    Object? body,
    Map<String, String> headers = const {},
    this.authRequired = true,
    ApiReplayPolicy? replayPolicy,
    this.idempotencyKey,
  }) : query = Map<String, List<String>>.unmodifiable({
         for (final entry in query.entries)
           entry.key: List<String>.unmodifiable(entry.value),
       }),
       headers = Map<String, String>.unmodifiable(headers),
       _encodedBody = body == null
           ? null
           : List<int>.unmodifiable(utf8.encode(jsonEncode(body))),
       replayPolicy = replayPolicy ?? _defaultReplayPolicy(method) {
    _validate();
  }

  factory ApiRequest.get({
    required String operation,
    required String path,
    Map<String, List<String>> query = const {},
    Map<String, String> headers = const {},
    bool authRequired = true,
  }) => ApiRequest(
    operation: operation,
    method: 'GET',
    path: path,
    query: query,
    headers: headers,
    authRequired: authRequired,
  );

  factory ApiRequest.command({
    required String operation,
    required String method,
    required String path,
    required Object? body,
    String? idempotencyKey,
    Map<String, List<String>> query = const {},
    Map<String, String> headers = const {},
  }) => ApiRequest(
    operation: operation,
    method: method,
    path: path,
    query: query,
    body: body,
    headers: headers,
    replayPolicy: ApiReplayPolicy.idempotent,
    idempotencyKey: idempotencyKey ?? IdempotencyKey.generate(),
  );

  final String operation;
  final String method;
  final String path;
  final Map<String, List<String>> query;
  final Map<String, String> headers;
  final bool authRequired;
  final ApiReplayPolicy replayPolicy;
  final String? idempotencyKey;
  final List<int>? _encodedBody;

  bool get canReplay => replayPolicy != ApiReplayPolicy.never;

  List<int>? encodeBody() => _encodedBody;

  void _validate() {
    if (!_operationPattern.hasMatch(operation)) {
      throw const FormatException(
        'Operation must be a stable safe identifier.',
      );
    }
    if (!_supportedMethods.contains(method) || !path.startsWith('/')) {
      throw const FormatException('Request method or path is invalid.');
    }
    if ((method == 'GET' || method == 'HEAD') && _encodedBody != null) {
      throw const FormatException(
        'GET and HEAD requests cannot include a body.',
      );
    }
    final parsedPath = Uri.parse(path);
    if (parsedPath.isAbsolute ||
        parsedPath.hasQuery ||
        parsedPath.hasFragment) {
      throw const FormatException(
        'Request path must be an absolute-path reference without query or fragment.',
      );
    }
    for (final entry in query.entries) {
      if (entry.key.isEmpty ||
          entry.value.any((value) => value.length > 2048)) {
        throw const FormatException('Request query is invalid.');
      }
    }
    for (final entry in headers.entries) {
      if (!_headerNamePattern.hasMatch(entry.key) ||
          !_validHeaderValue(entry.value)) {
        throw const FormatException('Request header is invalid.');
      }
      if (_reservedHeaders.contains(entry.key.toLowerCase())) {
        throw FormatException('${entry.key} is managed by the API client.');
      }
    }
    if (replayPolicy == ApiReplayPolicy.idempotent) {
      if (method == 'GET' || method == 'HEAD') {
        throw const FormatException(
          'Safe reads cannot use the idempotent command policy.',
        );
      }
      if (idempotencyKey == null || !IdempotencyKey.isValid(idempotencyKey!)) {
        throw const FormatException(
          'Idempotent requests require a valid idempotency key.',
        );
      }
    } else if (idempotencyKey != null) {
      throw const FormatException(
        'Idempotency keys require the idempotent replay policy.',
      );
    }
    if (replayPolicy == ApiReplayPolicy.safe &&
        method != 'GET' &&
        method != 'HEAD') {
      throw const FormatException(
        'Only GET and HEAD can use the safe replay policy.',
      );
    }
  }
}

abstract final class IdempotencyKey {
  static final Random _random = Random.secure();

  static String generate() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static bool isValid(String value) =>
      value.length >= 16 &&
      value.length <= 128 &&
      _idempotencyPattern.hasMatch(value);
}

ApiReplayPolicy _defaultReplayPolicy(String method) =>
    method == 'GET' || method == 'HEAD'
    ? ApiReplayPolicy.safe
    : ApiReplayPolicy.never;

bool _validHeaderValue(String value) {
  if (value.length > 2048) return false;
  return value.runes.every(
    (character) =>
        character == 0x09 || (character >= 0x20 && character <= 0x7e),
  );
}

const _supportedMethods = {'GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE'};
const _reservedHeaders = {
  'authorization',
  'cookie',
  'idempotency-key',
  'x-correlation-id',
  'content-length',
  'host',
};
final _operationPattern = RegExp(r'^[a-z][a-z0-9_.-]{2,79}$');
final _headerNamePattern = RegExp(r"^[!#\$%&'*+.^_`|~0-9A-Za-z-]+$");
final _idempotencyPattern = RegExp(r'^[A-Za-z0-9._:-]+$');
