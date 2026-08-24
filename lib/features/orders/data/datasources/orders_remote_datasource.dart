import 'package:ai_order_assistant/core/network/api_client.dart';
import 'package:ai_order_assistant/features/orders/data/models/order_model.dart';
import 'package:ai_order_assistant/features/orders/domain/entities/order.dart';

class OrdersRemoteDataSource {
  const OrdersRemoteDataSource(this._client);

  final ApiClient _client;

  Future<OrderModel> confirmOrder({
    required String clientRequestId,
    required List<ConfirmOrderItemInput> items,
    String? customerId,
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
        'customerId': ?customerId,
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

  Future<void> createPayment({
    required String orderId,
    required String clientRequestId,
    required int amount,
    required String method,
    String? note,
  }) {
    return _client.post<void>(
      '/orders/$orderId/payments',
      data: {
        'clientRequestId': clientRequestId,
        'amount': amount,
        'method': method,
        'note': ?note,
      },
      decode: (_) {},
    );
  }
}
