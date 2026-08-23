import 'package:ai_order_assistant/core/errors/error_handler.dart';
import 'package:ai_order_assistant/features/products/di/product_providers.dart';
import 'package:ai_order_assistant/features/products/domain/entities/product.dart';
import 'package:ai_order_assistant/features/products/domain/repositories/product_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final productListProvider =
    AsyncNotifierProvider<ProductListNotifier, List<Product>>(
      ProductListNotifier.new,
    );

class ProductListNotifier extends AsyncNotifier<List<Product>> {
  String _query = '';

  ProductRepository get _repository => ref.read(productRepositoryProvider);

  @override
  Future<List<Product>> build() {
    return _repository.getProducts();
  }

  Future<void> search(String query) async {
    _query = query.trim();
    await _loadCurrentQuery();
  }

  Future<void> refresh() => _loadCurrentQuery();

  Future<bool> createProduct({
    required String name,
    required String unit,
    required int price,
  }) {
    return _mutate(
      () => _repository.createProduct(name: name, unit: unit, price: price),
    );
  }

  Future<bool> updateProduct({
    required String id,
    required String name,
    required String unit,
    required int price,
  }) {
    return _mutate(
      () => _repository.updateProduct(
        id: id,
        name: name,
        unit: unit,
        price: price,
      ),
    );
  }

  Future<bool> deleteProduct(String id) {
    return _mutate(() => _repository.deleteProduct(id));
  }

  Future<void> _loadCurrentQuery() async {
    state = const AsyncLoading();
    try {
      final products = await _repository.getProducts(query: _query);
      state = AsyncData(products);
    } catch (error, stackTrace) {
      state = AsyncError(ErrorHandler.from(error), stackTrace);
    }
  }

  Future<bool> _mutate(Future<Object?> Function() action) async {
    state = const AsyncLoading();
    try {
      await action();
      final products = await _repository.getProducts(query: _query);
      state = AsyncData(products);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(ErrorHandler.from(error), stackTrace);
      return false;
    }
  }
}
