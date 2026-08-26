import 'package:planext4u_config/planext4u_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts local HTTP only for development', () {
    final config = AppConfig.parse(
      rawEnvironment: 'dev',
      rawApiBaseUrl: 'http://localhost:8080',
    );

    expect(config.environment, AppEnvironment.development);
    expect(config.apiBaseUrl.host, 'localhost');
    expect(config.isProduction, isFalse);
  });

  test('requires HTTPS outside development', () {
    expect(
      () => AppConfig.parse(
        rawEnvironment: 'production',
        rawApiBaseUrl: 'http://api.planext4u.net',
      ),
      throwsFormatException,
    );
  });

  test('rejects unknown environments and relative URLs', () {
    expect(
      () => AppConfig.parse(
        rawEnvironment: 'preview',
        rawApiBaseUrl: 'https://api.planext4u.net',
      ),
      throwsFormatException,
    );
    expect(
      () =>
          AppConfig.parse(rawEnvironment: 'development', rawApiBaseUrl: '/v1'),
      throwsFormatException,
    );
  });
}
