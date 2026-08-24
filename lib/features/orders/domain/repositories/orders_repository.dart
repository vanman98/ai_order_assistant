import 'package:ai_order_assistant/features/orders/domain/entities/order.dart';

abstract interface class OrdersRepository {
  Future<Order> confirmOrder({
    required String clientRequestId,
    required List<ConfirmOrderItemInput> items,
    String? customerId,
    String? customerName,
    String? note,
  });

  Future<List<Order>> getTodayOrders();

  Future<void> createPayment({
    required String orderId,
    required String clientRequestId,
    required int amount,
    PaymentMethod method = PaymentMethod.cash,
    String? note,
  });
}
