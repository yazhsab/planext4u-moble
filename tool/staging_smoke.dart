import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final baseUrl = _argument(arguments, '--base-url=');
  final requireAuth = _argument(
    arguments,
    '--require-auth=',
    fallback: 'false',
  );
  if (baseUrl == null || (requireAuth != 'true' && requireAuth != 'false')) {
    stderr.writeln(
      'Usage: dart run tool/staging_smoke.dart '
      '--base-url=https://host --require-auth=true|false',
    );
    exitCode = 64;
    return;
  }
  final origin = Uri.tryParse(baseUrl);
  if (origin == null || origin.scheme != 'https' || origin.host.isEmpty) {
    stderr.writeln('Staging smoke requires an HTTPS origin.');
    exitCode = 64;
    return;
  }

  final token = Platform.environment['STAGING_SYNTHETIC_ACCESS_TOKEN']?.trim();
  if (requireAuth == 'true' && (token == null || token.isEmpty)) {
    stderr.writeln('Protected staging synthetic-user token is not configured.');
    exitCode = 78;
    return;
  }

  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 8)
    ..idleTimeout = const Duration(seconds: 8)
    ..maxConnectionsPerHost = 2;
  try {
    await _probe(
      client,
      origin.resolve('/health/ready'),
      requiredKeys: const ['status'],
    );
    await _probe(
      client,
      origin.resolve(
        '/v1/bootstrap?application=CUSTOMER&platform=ANDROID&version=0.1.0&locale=en&country=IN',
      ),
      requiredKeys: const ['revision', 'supported_locales', 'flags'],
    );
    if (token != null && token.isNotEmpty) {
      await _probe(
        client,
        origin.resolve('/v1/home'),
        bearerToken: token,
        requiredKeys: const ['categories', 'featured_items'],
      );
    }
    stdout.writeln(
      token == null || token.isEmpty
          ? 'Staging public smoke passed; authenticated slice was skipped.'
          : 'Staging public and authenticated customer slice passed.',
    );
  } finally {
    client.close(force: true);
  }
}

Future<void> _probe(
  HttpClient client,
  Uri uri, {
  String? bearerToken,
  required List<String> requiredKeys,
}) async {
  final request = await client.getUrl(uri);
  request.headers
    ..set(HttpHeaders.acceptHeader, 'application/json')
    ..set('X-Correlation-ID', _correlationId());
  if (bearerToken != null) {
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $bearerToken');
  }
  final response = await request.close().timeout(const Duration(seconds: 10));
  final bytes = await response.fold<List<int>>(<int>[], (buffer, chunk) {
    if (buffer.length + chunk.length > 1024 * 1024) {
      throw const FormatException('Smoke response exceeded one MiB.');
    }
    return buffer..addAll(chunk);
  });
  if (response.statusCode != HttpStatus.ok) {
    throw HttpException(
      'Smoke endpoint returned HTTP ${response.statusCode}.',
      uri: uri.replace(query: ''),
    );
  }
  final decoded = jsonDecode(utf8.decode(bytes));
  if (decoded is! Map<String, Object?> ||
      requiredKeys.any((key) => !decoded.containsKey(key))) {
    throw FormatException('Smoke response contract failed for ${uri.path}.');
  }
}

String _correlationId() =>
    'mobile-smoke-${DateTime.now().toUtc().microsecondsSinceEpoch}';

String? _argument(List<String> arguments, String prefix, {String? fallback}) =>
    arguments
        .where((value) => value.startsWith(prefix))
        .firstOrNull
        ?.substring(prefix.length) ??
    fallback;
