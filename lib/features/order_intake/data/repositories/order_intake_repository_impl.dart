import 'package:ai_order_assistant/features/order_intake/data/datasources/order_intake_remote_datasource.dart';
import 'package:ai_order_assistant/features/order_intake/domain/entities/order_extraction.dart';
import 'package:ai_order_assistant/features/order_intake/domain/repositories/order_intake_repository.dart';
import 'package:dio/dio.dart';

class OrderIntakeRepositoryImpl implements OrderIntakeRepository {
  const OrderIntakeRepositoryImpl(this._dataSource);

  final OrderIntakeRemoteDataSource _dataSource;

  @override
  OrderAnalysisOperation analyzeImage({
    required String imagePath,
    required UploadProgress onProgress,
  }) {
    final cancelToken = CancelToken();
    final result = _dataSource.analyzeImage(
      imagePath: imagePath,
      cancelToken: cancelToken,
      onSendProgress: (sent, total) {
        if (total > 0) onProgress((sent / total).clamp(0, 1));
      },
    );
    return _DioOrderAnalysisOperation(result, cancelToken);
  }

  @override
  Future<OrderExtraction> resolveOrder(OrderExtraction extraction) {
    return _dataSource.resolveOrder(extraction);
  }
}

class _DioOrderAnalysisOperation implements OrderAnalysisOperation {
  const _DioOrderAnalysisOperation(this.result, this._cancelToken);

  @override
  final Future<OrderExtraction> result;

  final CancelToken _cancelToken;

  @override
  void cancel() {
    if (!_cancelToken.isCancelled) {
      _cancelToken.cancel('Người dùng đã hủy tải ảnh.');
    }
  }
}
