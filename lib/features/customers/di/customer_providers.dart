import 'package:ai_order_assistant/core/di/app_providers.dart';
import 'package:ai_order_assistant/features/customers/data/datasources/customer_remote_datasource.dart';
import 'package:ai_order_assistant/features/customers/data/repositories/customer_repository_impl.dart';
import 'package:ai_order_assistant/features/customers/domain/repositories/customer_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final customerRemoteDataSourceProvider = Provider<CustomerRemoteDataSource>((
  ref,
) {
  return CustomerRemoteDataSource(ref.watch(apiClientProvider));
});

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepositoryImpl(ref.watch(customerRemoteDataSourceProvider));
});
