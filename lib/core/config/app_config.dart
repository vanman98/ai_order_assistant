class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.enableLogging,
  });

  final String environment;
  final String apiBaseUrl;
  final bool enableLogging;

  bool get isDevelopment => environment == 'dev';
  bool get isProduction => environment == 'prod';
}

abstract final class EnvConfig {
  static const environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.197:3000/api',
  );

  static const enableLogging = bool.fromEnvironment(
    'ENABLE_LOGGING',
    defaultValue: true,
  );

  static const current = AppConfig(
    environment: environment,
    apiBaseUrl: apiBaseUrl,
    enableLogging: enableLogging,
  );
}
