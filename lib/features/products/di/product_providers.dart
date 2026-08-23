import 'package:ai_order_assistant/core/di/app_providers.dart';
import 'package:ai_order_assistant/features/products/data/datasources/product_remote_datasource.dart';
import 'package:ai_order_assistant/features/products/data/repositories/product_repository_impl.dart';
import 'package:ai_order_assistant/features/products/domain/repositories/product_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final productRemoteDataSourceProvider = Provider<ProductRemoteDataSource>((
  ref,
) {
  return ProductRemoteDataSource(ref.watch(apiClientProvider));
});

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepositoryImpl(ref.watch(productRemoteDataSourceProvider));
});
