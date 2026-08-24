import 'package:ai_order_assistant/features/orders/data/datasources/orders_remote_datasource.dart';
import 'package:ai_order_assistant/features/orders/data/models/order_model.dart';
import 'package:ai_order_assistant/features/orders/domain/entities/order.dart';
import 'package:ai_order_assistant/features/orders/domain/repositories/orders_repository.dart';

class OrdersRepositoryImpl implements OrdersRepository {
  const OrdersRepositoryImpl(this._dataSource);

  final OrdersRemoteDataSource _dataSource;

  @override
  Future<Order> confirmOrder({
    required String clientRequestId,
    required List<ConfirmOrderItemInput> items,
    String? customerId,
    String? customerName,
    String? note,
  }) async {
    final model = await _dataSource.confirmOrder(
      clientRequestId: clientRequestId,
      items: items,
      customerId: customerId,
      customerName: customerName,
      note: note,
    );
    return model.toEntity();
  }

  @override
  Future<List<Order>> getTodayOrders() async {
    final models = await _dataSource.getTodayOrders();
    return models.map((model) => model.toEntity()).toList(growable: false);
  }

  @override
  Future<void> createPayment({
    required String orderId,
    required String clientRequestId,
    required int amount,
    PaymentMethod method = PaymentMethod.cash,
    String? note,
  }) {
    return _dataSource.createPayment(
      orderId: orderId,
      clientRequestId: clientRequestId,
      amount: amount,
      method: paymentMethodToApi(method),
      note: note,
    );
  }
}
