import 'package:ai_order_assistant/core/errors/error_handler.dart';
import 'package:ai_order_assistant/features/orders/di/orders_providers.dart';
import 'package:ai_order_assistant/features/orders/domain/entities/order.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final todayOrdersProvider =
    AsyncNotifierProvider<TodayOrdersNotifier, List<Order>>(
      TodayOrdersNotifier.new,
    );

class TodayOrdersNotifier extends AsyncNotifier<List<Order>> {
  @override
  Future<List<Order>> build() {
    return ref.read(ordersRepositoryProvider).getTodayOrders();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(ordersRepositoryProvider).getTodayOrders(),
    );
  }
}

extension TodayOrdersFailure on AsyncValue<List<Order>> {
  String? get failureMessage {
    final error = this.error;
    if (error == null) return null;
    return ErrorHandler.from(error).message;
  }
}
