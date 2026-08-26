/// Deployment environments supported by every Planext4u application.
enum AppEnvironment { development, staging, production }

/// Typed, secret-free compile-time configuration.
///
/// Secrets must never be supplied through Dart defines because those values are
/// recoverable from a mobile binary. Only public endpoints and non-sensitive
/// feature bootstrap values belong here.
final class AppConfig {
  const AppConfig({required this.environment, required this.apiBaseUrl});

  /// Parses the public compile-time values used by an application build.
  factory AppConfig.fromCompileTime() => AppConfig.parse(
    rawEnvironment: const String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    ),
    rawApiBaseUrl: const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:8080',
    ),
  );

  /// Parses and validates a configuration without reading process state.
  factory AppConfig.parse({
    required String rawEnvironment,
    required String rawApiBaseUrl,
  }) {
    final environment = switch (rawEnvironment.trim().toLowerCase()) {
      'development' || 'dev' => AppEnvironment.development,
      'staging' => AppEnvironment.staging,
      'production' || 'prod' => AppEnvironment.production,
      final value => throw FormatException('Unsupported APP_ENV: $value'),
    };
    final apiBaseUrl = Uri.parse(rawApiBaseUrl.trim());
    if (!apiBaseUrl.hasScheme || apiBaseUrl.host.isEmpty) {
      throw const FormatException('API_BASE_URL must be an absolute URL.');
    }
    if (environment != AppEnvironment.development &&
        apiBaseUrl.scheme != 'https') {
      throw const FormatException(
        'Staging and production API_BASE_URL values must use HTTPS.',
      );
    }
    return AppConfig(environment: environment, apiBaseUrl: apiBaseUrl);
  }

  final AppEnvironment environment;
  final Uri apiBaseUrl;

  String get environmentLabel => environment.name;

  bool get isProduction => environment == AppEnvironment.production;
}
