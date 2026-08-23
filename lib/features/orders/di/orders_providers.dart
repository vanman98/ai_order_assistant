import 'package:ai_order_assistant/core/di/app_providers.dart';
import 'package:ai_order_assistant/features/orders/data/datasources/orders_remote_datasource.dart';
import 'package:ai_order_assistant/features/orders/data/repositories/orders_repository_impl.dart';
import 'package:ai_order_assistant/features/orders/domain/repositories/orders_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final ordersRemoteDataSourceProvider = Provider<OrdersRemoteDataSource>((
  ref,
) {
  return OrdersRemoteDataSource(ref.watch(apiClientProvider));
});

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepositoryImpl(ref.watch(ordersRemoteDataSourceProvider));
});
