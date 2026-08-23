import 'package:ai_order_assistant/features/order_intake/domain/entities/order_extraction.dart';

typedef UploadProgress = void Function(double progress);

abstract interface class OrderAnalysisOperation {
  Future<OrderExtraction> get result;

  void cancel();
}

abstract interface class OrderIntakeRepository {
  OrderAnalysisOperation analyzeImage({
    required String imagePath,
    required UploadProgress onProgress,
  });

  Future<OrderExtraction> resolveOrder(OrderExtraction extraction);
}
