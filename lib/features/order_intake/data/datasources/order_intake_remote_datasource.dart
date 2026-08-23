import 'package:ai_order_assistant/core/network/api_client.dart';
import 'package:ai_order_assistant/features/order_intake/data/models/order_extraction_model.dart';
import 'package:ai_order_assistant/features/order_intake/domain/entities/order_extraction.dart';
import 'package:dio/dio.dart';

class OrderIntakeRemoteDataSource {
  const OrderIntakeRemoteDataSource(this._client);

  final ApiClient _client;

  Future<OrderExtractionModel> analyzeImage({
    required String imagePath,
    required ProgressCallback onSendProgress,
    required CancelToken cancelToken,
  }) {
    return _client.uploadFile<OrderExtractionModel>(
      '/order-intake/analyze',
      filePath: imagePath,
      onSendProgress: onSendProgress,
      cancelToken: cancelToken,
      decode: (data) =>
          OrderExtractionModel.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<OrderExtractionModel> resolveOrder(OrderExtraction extraction) {
    return _client.post<OrderExtractionModel>(
      '/order-intake/resolve',
      data: {
        'items': extraction.items
            .map(
              (item) => {
                'rawText': item.rawText,
                'rawProductName': item.rawProductName,
                'quantity': item.quantity,
                'unit': item.unit,
                'unitPrice': item.extractedUnitPrice,
                'note': item.note,
                'needsReview': item.needsReview,
                'uncertaintyReason': item.uncertaintyReason,
                if (item.selectedProductId != null)
                  'selectedProductId': item.selectedProductId,
              },
            )
            .toList(growable: false),
        'imageQuality': extraction.imageQuality,
        'generalNote': extraction.generalNote,
      },
      decode: (data) =>
          OrderExtractionModel.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }
}
