import 'package:ai_order_assistant/core/network/api_client.dart';
import 'package:ai_order_assistant/features/orders/data/models/order_model.dart';
import 'package:ai_order_assistant/features/orders/domain/entities/order.dart';

class OrdersRemoteDataSource {
  const OrdersRemoteDataSource(this._client);

  final ApiClient _client;

  Future<OrderModel> confirmOrder({
    required String clientRequestId,
    required List<ConfirmOrderItemInput> items,
    String? customerName,
    String? note,
  }) {
    return _client.post<OrderModel>(
      '/orders',
      data: {
        'clientRequestId': clientRequestId,
        'items': items
            .map(
              (item) => {
                'productId': item.productId,
                'quantity': item.quantity,
                if (item.rawText != null) 'rawText': item.rawText,
              },
            )
            .toList(growable: false),
        'customerName': ?customerName,
        'note': ?note,
      },
      decode: (data) =>
          OrderModel.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<List<OrderModel>> getTodayOrders() {
    return _client.get<List<OrderModel>>(
      '/orders',
      decode: (data) => (data as List<dynamic>)
          .map(
            (item) =>
                OrderModel.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(growable: false),
    );
  }
}
