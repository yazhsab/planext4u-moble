import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_config/planext4u_config.dart';

void main() {
  test('private uploads require an explicit trusted production origin', () {
    final production = AppConfig.parse(
      rawEnvironment: 'production',
      rawApiBaseUrl: 'https://api.example',
    );
    expect(production.privateUploadOrigin, isNull);
    expect(
      AppConfig.fromPublicDefines({
        'APP_ENV': 'production',
        'API_BASE_URL': 'https://api.example',
        'PRIVATE_UPLOAD_ORIGIN': 'https://uploads.example',
      }).privateUploadOrigin,
      Uri.parse('https://uploads.example'),
    );
    for (final origin in [
      'http://uploads.example',
      'https://uploads.example/path',
      'https://user:secret@uploads.example',
    ]) {
      expect(
        () => AppConfig.parse(
          rawEnvironment: 'production',
          rawApiBaseUrl: 'https://api.example',
          rawPrivateUploadOrigin: origin,
        ),
        throwsFormatException,
      );
    }
    expect(
      () => AppConfig.parse(
        rawEnvironment: 'development',
        rawApiBaseUrl: 'http://localhost:8082',
        rawPrivateUploadOrigin: 'http://remote.example',
      ),
      throwsFormatException,
    );
  });
  test('accepts local HTTP only for development', () {
    final config = AppConfig.parse(
      rawEnvironment: 'dev',
      rawApiBaseUrl: 'http://localhost:8080',
    );

    expect(config.environment, AppEnvironment.development);
    expect(config.apiBaseUrl, Uri.parse('http://localhost:8080'));
    expect(config.webBaseUrl, Uri.parse('http://localhost:3000'));
    expect(config.deepLinkHost, 'dev.planext4u.net');
    expect(config.countryCode, 'IN');
    expect(config.isProduction, isFalse);
  });
  test(
    'public country scope is validated before startup and authentication',
    () {
      expect(
        AppConfig.fromPublicDefines({
          'APP_ENV': 'production',
          'DEFAULT_COUNTRY_CODE': 'NG',
        }).countryCode,
        'NG',
      );
      for (final country in ['', 'ng', 'NGA', 'N1', ' NG', 'NG ']) {
        expect(
          () => AppConfig.parse(
            rawEnvironment: 'production',
            rawApiBaseUrl: '',
            rawCountryCode: country,
          ),
          throwsFormatException,
        );
      }
    },
  );

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

  test('environment defaults are safe and deterministic', () {
    final staging = AppConfig.parse(
      rawEnvironment: 'staging',
      rawApiBaseUrl: '',
    );
    expect(staging.apiBaseUrl, Uri.parse('https://api.staging.planext4u.net'));
    expect(staging.deepLinkOrigin, Uri.parse('https://staging.planext4u.net'));

    final production = AppConfig.parse(
      rawEnvironment: 'production',
      rawApiBaseUrl: '',
    );
    expect(production.webBaseUrl, Uri.parse('https://planext4u.net'));
    expect(
      production.allowsWebDeepLink(Uri.parse('https://planext4u.net/app')),
      isTrue,
    );
    expect(
      production.allowsWebDeepLink(
        Uri.parse('https://staging.planext4u.net/app'),
      ),
      isFalse,
    );
  });

  test('public defines reject unknown and secret-shaped keys', () {
    expect(
      () => AppConfig.fromPublicDefines({
        'APP_ENV': 'production',
        'CLIENT_SECRET': 'must-not-enter-a-binary',
      }),
      throwsFormatException,
    );
  });

  test('public URLs reject credentials, queries and fragments', () {
    for (final url in [
      'https://user:password@api.planext4u.net',
      'https://api.planext4u.net?token=value',
      'https://api.planext4u.net#secret',
    ]) {
      expect(
        () => AppConfig.parse(rawEnvironment: 'production', rawApiBaseUrl: url),
        throwsFormatException,
      );
    }
  });

  test('all application identities remain unique in every environment', () {
    final identifiers = <String>{};
    for (final environment in AppEnvironment.values) {
      for (final application in Planext4uApplication.values) {
        final identity = AppIdentity.forBuild(
          application: application,
          environment: environment,
        );
        expect(identifiers.add(identity.bundleIdentifier), isTrue);
        expect(identity.deepLinkHost, isNotEmpty);
        expect(identity.customScheme, startsWith('planext4u-'));
        expect(identity.deepLinkPathPrefix, startsWith('/'));
      }
    }
    expect(identifiers, hasLength(9));
  });
}
