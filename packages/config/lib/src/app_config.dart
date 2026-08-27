/// Deployment environments supported by every Planext4u application.
enum AppEnvironment { development, staging, production }

/// Independently distributed Planext4u mobile products.
enum Planext4uApplication { customer, vendor, rider }

/// Store identity and deep-link boundaries for one role-specific application.
final class AppIdentity {
  const AppIdentity._({required this.application, required this.environment});

  factory AppIdentity.forBuild({
    required Planext4uApplication application,
    required AppEnvironment environment,
  }) => AppIdentity._(application: application, environment: environment);

  final Planext4uApplication application;
  final AppEnvironment environment;

  String get baseIdentifier => 'net.planext4u.${application.name}';

  String get bundleIdentifier => switch (environment) {
    AppEnvironment.development => '$baseIdentifier.dev',
    AppEnvironment.staging => '$baseIdentifier.staging',
    AppEnvironment.production => baseIdentifier,
  };

  String get displayName {
    final role = switch (application) {
      Planext4uApplication.customer => 'Customer',
      Planext4uApplication.vendor => 'Vendor',
      Planext4uApplication.rider => 'Rider',
    };
    return switch (environment) {
      AppEnvironment.development => 'Planext4u $role Dev',
      AppEnvironment.staging => 'Planext4u $role Staging',
      AppEnvironment.production => 'Planext4u $role',
    };
  }

  String get deepLinkHost => switch (environment) {
    AppEnvironment.development => 'dev.planext4u.net',
    AppEnvironment.staging => 'staging.planext4u.net',
    AppEnvironment.production => 'planext4u.net',
  };

  String get deepLinkPathPrefix => switch (application) {
    Planext4uApplication.customer => '/app',
    Planext4uApplication.vendor => '/vendor',
    Planext4uApplication.rider => '/rider',
  };

  String get customScheme {
    final base = 'planext4u-${application.name}';
    return switch (environment) {
      AppEnvironment.development => '$base-dev',
      AppEnvironment.staging => '$base-staging',
      AppEnvironment.production => base,
    };
  }
}

/// Typed, secret-free compile-time configuration.
///
/// Secrets must never be supplied through Dart defines because those values are
/// recoverable from a mobile binary. Only public endpoints and non-sensitive
/// feature bootstrap values belong here.
final class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.webBaseUrl,
    required this.deepLinkHost,
  });

  static const publicDefineKeys = <String>{
    'APP_ENV',
    'API_BASE_URL',
    'WEB_BASE_URL',
    'DEEP_LINK_HOST',
  };

  /// Parses the public compile-time values used by an application build.
  factory AppConfig.fromCompileTime() => AppConfig.parse(
    rawEnvironment: const String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    ),
    rawApiBaseUrl: const String.fromEnvironment('API_BASE_URL'),
    rawWebBaseUrl: const String.fromEnvironment('WEB_BASE_URL'),
    rawDeepLinkHost: const String.fromEnvironment('DEEP_LINK_HOST'),
  );

  /// Parses an explicit public configuration map and rejects unknown keys.
  /// This prevents secret-shaped values from being accidentally promoted into
  /// recoverable Dart defines.
  factory AppConfig.fromPublicDefines(Map<String, String> defines) {
    final unknownKeys = defines.keys.toSet().difference(publicDefineKeys);
    if (unknownKeys.isNotEmpty) {
      throw FormatException(
        'Unsupported public define keys: ${unknownKeys.toList()..sort()}',
      );
    }
    return AppConfig.parse(
      rawEnvironment: defines['APP_ENV'] ?? 'development',
      rawApiBaseUrl: defines['API_BASE_URL'] ?? '',
      rawWebBaseUrl: defines['WEB_BASE_URL'] ?? '',
      rawDeepLinkHost: defines['DEEP_LINK_HOST'] ?? '',
    );
  }

  /// Parses and validates a configuration without reading process state.
  factory AppConfig.parse({
    required String rawEnvironment,
    required String rawApiBaseUrl,
    String rawWebBaseUrl = '',
    String rawDeepLinkHost = '',
  }) {
    final environment = switch (rawEnvironment.trim().toLowerCase()) {
      'development' || 'dev' => AppEnvironment.development,
      'staging' => AppEnvironment.staging,
      'production' || 'prod' => AppEnvironment.production,
      final value => throw FormatException('Unsupported APP_ENV: $value'),
    };
    final defaults = _EnvironmentDefaults.forEnvironment(environment);
    final apiBaseUrl = _validatedPublicUrl(
      key: 'API_BASE_URL',
      rawValue: rawApiBaseUrl,
      fallback: defaults.apiBaseUrl,
      environment: environment,
    );
    final webBaseUrl = _validatedPublicUrl(
      key: 'WEB_BASE_URL',
      rawValue: rawWebBaseUrl,
      fallback: defaults.webBaseUrl,
      environment: environment,
    );
    final deepLinkHost = rawDeepLinkHost.trim().isEmpty
        ? defaults.deepLinkHost
        : rawDeepLinkHost.trim().toLowerCase();
    if (!_isValidHost(deepLinkHost)) {
      throw const FormatException('DEEP_LINK_HOST must be a hostname.');
    }
    return AppConfig(
      environment: environment,
      apiBaseUrl: apiBaseUrl,
      webBaseUrl: webBaseUrl,
      deepLinkHost: deepLinkHost,
    );
  }

  final AppEnvironment environment;
  final Uri apiBaseUrl;
  final Uri webBaseUrl;
  final String deepLinkHost;

  String get environmentLabel => environment.name;

  bool get isProduction => environment == AppEnvironment.production;

  Uri get deepLinkOrigin => Uri(scheme: 'https', host: deepLinkHost);

  bool allowsWebDeepLink(Uri uri) =>
      uri.scheme == 'https' && uri.host.toLowerCase() == deepLinkHost;
}

final class _EnvironmentDefaults {
  const _EnvironmentDefaults({
    required this.apiBaseUrl,
    required this.webBaseUrl,
    required this.deepLinkHost,
  });

  factory _EnvironmentDefaults.forEnvironment(AppEnvironment environment) =>
      switch (environment) {
        AppEnvironment.development => const _EnvironmentDefaults(
          apiBaseUrl: 'http://localhost:8080',
          webBaseUrl: 'http://localhost:3000',
          deepLinkHost: 'dev.planext4u.net',
        ),
        AppEnvironment.staging => const _EnvironmentDefaults(
          apiBaseUrl: 'https://api.staging.planext4u.net',
          webBaseUrl: 'https://staging.planext4u.net',
          deepLinkHost: 'staging.planext4u.net',
        ),
        AppEnvironment.production => const _EnvironmentDefaults(
          apiBaseUrl: 'https://api.planext4u.net',
          webBaseUrl: 'https://planext4u.net',
          deepLinkHost: 'planext4u.net',
        ),
      };

  final String apiBaseUrl;
  final String webBaseUrl;
  final String deepLinkHost;
}

Uri _validatedPublicUrl({
  required String key,
  required String rawValue,
  required String fallback,
  required AppEnvironment environment,
}) {
  final value = rawValue.trim().isEmpty ? fallback : rawValue.trim();
  final uri = Uri.parse(value);
  if (!uri.hasScheme || uri.host.isEmpty) {
    throw FormatException('$key must be an absolute URL.');
  }
  if (uri.hasQuery || uri.hasFragment || uri.userInfo.isNotEmpty) {
    throw FormatException(
      '$key cannot include credentials, a query, or a fragment.',
    );
  }
  if (environment != AppEnvironment.development && uri.scheme != 'https') {
    throw FormatException('Staging and production $key values must use HTTPS.');
  }
  if (environment == AppEnvironment.development &&
      uri.scheme != 'http' &&
      uri.scheme != 'https') {
    throw FormatException('$key must use HTTP or HTTPS.');
  }
  return uri;
}

bool _isValidHost(String value) {
  if (value.isEmpty || value.length > 253 || value.contains('://')) {
    return false;
  }
  final labels = value.split('.');
  if (labels.length < 2) return false;
  final labelPattern = RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$');
  return labels.every(labelPattern.hasMatch);
}
