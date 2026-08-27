import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final baseUrl = _argument(arguments, '--base-url=');
  final allowInsecureLocal =
      _argument(arguments, '--allow-insecure-local=', fallback: 'false') ==
      'true';
  final origin = baseUrl == null ? null : Uri.tryParse(baseUrl);
  final secureOrigin =
      origin != null && origin.scheme == 'https' && origin.host.isNotEmpty;
  final permittedLocalOrigin =
      allowInsecureLocal &&
      origin != null &&
      origin.scheme == 'http' &&
      (origin.host == '127.0.0.1' || origin.host == 'localhost');
  if (!secureOrigin && !permittedLocalOrigin) {
    stderr.writeln(
      'Usage: dart run tool/staging_smoke.dart '
      '--base-url=https://host [--allow-insecure-local=true]',
    );
    exitCode = 64;
    return;
  }

  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 8)
    ..idleTimeout = const Duration(seconds: 8)
    ..maxConnectionsPerHost = 2;
  try {
    await _request(
      client,
      origin,
      'GET',
      '/health/ready',
      step: 'ready',
      assertion: (body) => body['status'] == 'ok',
    );
    final authentication = await _request(
      client,
      origin,
      'POST',
      '/v1/auth/exchange',
      step: 'login',
      expectedStatus: HttpStatus.created,
      jsonBody: const {
        'provider': 'local',
        'provider_token': 'synthetic-customer',
        'device_id': 'device-mobile-staging-smoke-001',
        'country': 'IN',
      },
      assertion: (body) => body['identity_id'] == 'customer-synthetic-001',
    );
    final tokens = authentication['tokens'];
    final accessToken = tokens is Map<String, Object?>
        ? tokens['access_token']
        : null;
    if (accessToken is! String || !accessToken.startsWith('p4us_v1.')) {
      throw const FormatException('Synthetic login token contract failed.');
    }

    await _request(
      client,
      origin,
      'POST',
      '/v1/serviceability/check',
      step: 'location',
      bearerToken: accessToken,
      jsonBody: {
        'latitude': 13.08,
        'longitude': 80.27,
        'accuracy_metres': 12,
        'captured_at': DateTime.now().toUtc().toIso8601String(),
        'purpose': 'LOCATION_SERVICEABILITY',
      },
      assertion: (body) =>
          body['serviceable'] == true && body['locality'] == 'Chennai',
    );
    await _request(
      client,
      origin,
      'GET',
      '/v1/bootstrap?platform=android&app_version=0.1.0&locale=en',
      step: 'bootstrap',
      bearerToken: accessToken,
      assertion: (body) {
        final flags = body['flags'];
        return flags is Map<String, Object?> &&
            flags['customer_home'] == true &&
            flags['catalog_read'] == true;
      },
    );
    await _request(
      client,
      origin,
      'GET',
      '/v1/home',
      step: 'home',
      bearerToken: accessToken,
      assertion: (body) =>
          _containsNamed(body['categories'], 'Daily needs') &&
          _containsNamed(body['featured_items'], 'Fresh milk'),
    );
    await _request(
      client,
      origin,
      'GET',
      '/v1/catalog/items?category_id=daily-needs',
      step: 'catalog',
      bearerToken: accessToken,
      assertion: (body) {
        final items = body['items'];
        return items is List<Object?> &&
            items.length >= 2 &&
            items.every((item) {
              if (item is! Map<String, Object?>) return false;
              final price = item['price'];
              return price is Map<String, Object?> &&
                  price['currency'] == 'INR';
            });
      },
    );
    stdout.writeln(
      'MOB-E2E-001 staging slice passed: login -> location -> home -> catalog.',
    );
  } finally {
    client.close(force: true);
  }
}

Future<Map<String, Object?>> _request(
  HttpClient client,
  Uri origin,
  String method,
  String path, {
  required String step,
  required bool Function(Map<String, Object?> body) assertion,
  int expectedStatus = HttpStatus.ok,
  String? bearerToken,
  Map<String, Object?>? jsonBody,
}) async {
  final correlation = 'mobile-staging-$step-001';
  final request = await client.openUrl(method, origin.resolve(path));
  request
    ..followRedirects = false
    ..headers.set(HttpHeaders.acceptHeader, 'application/json')
    ..headers.set('X-Correlation-ID', correlation)
    ..headers.set(
      'traceparent',
      '00-11111111111111111111111111111111-2222222222222222-01',
    );
  if (bearerToken != null) {
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $bearerToken');
  }
  if (jsonBody != null) {
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(jsonBody));
  }
  final response = await request.close().timeout(const Duration(seconds: 15));
  final bytes = await response.fold<List<int>>(<int>[], (buffer, chunk) {
    if (buffer.length + chunk.length > 1024 * 1024) {
      throw const FormatException('Smoke response exceeded one MiB.');
    }
    return buffer..addAll(chunk);
  });
  if (response.statusCode != expectedStatus) {
    throw HttpException(
      'Smoke endpoint returned HTTP ${response.statusCode} at $step.',
      uri: origin.resolve(path).replace(query: ''),
    );
  }
  if (response.headers.value('X-Correlation-ID') != correlation) {
    throw FormatException('Correlation contract failed at $step.');
  }
  final decoded = jsonDecode(utf8.decode(bytes));
  if (decoded is! Map<String, Object?> || !assertion(decoded)) {
    throw FormatException('Smoke response contract failed at $step.');
  }
  return decoded;
}

bool _containsNamed(Object? values, String expected) =>
    values is List<Object?> &&
    values.any(
      (value) => value is Map<String, Object?> && value['name'] == expected,
    );

String? _argument(List<String> arguments, String prefix, {String? fallback}) =>
    arguments
        .where((value) => value.startsWith(prefix))
        .firstOrNull
        ?.substring(prefix.length) ??
    fallback;
