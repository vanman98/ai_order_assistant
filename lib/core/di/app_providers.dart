import 'package:ai_order_assistant/core/config/app_config.dart';
import 'package:ai_order_assistant/core/network/api_client.dart';
import 'package:ai_order_assistant/core/network/auth_interceptor.dart';
import 'package:ai_order_assistant/core/storage/secure_storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final appConfigProvider = Provider<AppConfig>((ref) => EnvConfig.current);

final flutterSecureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService(ref.watch(flutterSecureStorageProvider));
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final secureStorage = ref.watch(secureStorageServiceProvider);

  return ApiClient(
    baseUrl: config.apiBaseUrl,
    enableLogging: config.enableLogging,
    authInterceptor: AuthInterceptor(secureStorage),
  );
});
