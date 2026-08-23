import 'package:dio/dio.dart';

typedef ResponseDecoder<T> = T Function(dynamic data);

class ApiClient {
  ApiClient({
    required String baseUrl,
    required bool enableLogging,
    Interceptor? authInterceptor,
  }) : _dio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: const Duration(seconds: 15),
           sendTimeout: const Duration(seconds: 30),
           receiveTimeout: const Duration(seconds: 30),
           headers: const {'Accept': 'application/json'},
         ),
       ) {
    if (authInterceptor != null) {
      _dio.interceptors.add(authInterceptor);
    }

    if (enableLogging) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: false,
          responseBody: true,
          requestHeader: false,
        ),
      );
    }
  }

  final Dio _dio;

  Dio get rawDio => _dio;

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    required ResponseDecoder<T> decode,
  }) async {
    final response = await _dio.get<dynamic>(
      path,
      queryParameters: queryParameters,
    );
    return decode(response.data);
  }

  Future<T> post<T>(
    String path, {
    Object? data,
    required ResponseDecoder<T> decode,
  }) async {
    final response = await _dio.post<dynamic>(path, data: data);
    return decode(response.data);
  }

  Future<T> patch<T>(
    String path, {
    Object? data,
    required ResponseDecoder<T> decode,
  }) async {
    final response = await _dio.patch<dynamic>(path, data: data);
    return decode(response.data);
  }

  Future<T> delete<T>(
    String path, {
    Object? data,
    required ResponseDecoder<T> decode,
  }) async {
    final response = await _dio.delete<dynamic>(path, data: data);
    return decode(response.data);
  }

  Future<T> uploadFile<T>(
    String path, {
    required String filePath,
    String fileField = 'image',
    Map<String, dynamic> fields = const {},
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
    required ResponseDecoder<T> decode,
  }) async {
    final formData = FormData.fromMap({
      ...fields,
      fileField: await MultipartFile.fromFile(filePath),
    });

    final response = await _dio.post<dynamic>(
      path,
      data: formData,
      onSendProgress: onSendProgress,
      cancelToken: cancelToken,
      options: Options(
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 90),
      ),
    );
    return decode(response.data);
  }
}
