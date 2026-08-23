import 'package:ai_order_assistant/core/errors/failure.dart';
import 'package:dio/dio.dart';

abstract final class ErrorHandler {
  static Failure from(Object error) {
    if (error is! DioException) {
      return const UnexpectedFailure('Đã có lỗi xảy ra. Vui lòng thử lại.');
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.connectionError:
        return const NetworkFailure(
          'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng.',
        );
      case DioExceptionType.badResponse:
        return _fromResponse(error.response);
      case DioExceptionType.cancel:
        return const UnexpectedFailure('Yêu cầu đã bị hủy.');
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const UnexpectedFailure('Đã có lỗi xảy ra. Vui lòng thử lại.');
    }
  }

  static Failure _fromResponse(Response<dynamic>? response) {
    final statusCode = response?.statusCode;
    final message = _extractMessage(response?.data);

    return switch (statusCode) {
      400 || 413 || 415 || 422 => ValidationFailure(message),
      401 || 403 => UnauthorizedFailure(message),
      _ => ServerFailure(message, statusCode: statusCode),
    };
  }

  static String _extractMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is String && message.isNotEmpty) return message;
      if (message is List) return message.join('\n');

      final error = data['error'];
      if (error is String && error.isNotEmpty) return error;
    }

    return 'Máy chủ đang bận. Vui lòng thử lại.';
  }
}
