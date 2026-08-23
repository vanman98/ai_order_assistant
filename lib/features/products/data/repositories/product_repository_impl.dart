import 'package:ai_order_assistant/features/products/data/datasources/product_remote_datasource.dart';
import 'package:ai_order_assistant/features/products/domain/entities/product.dart';
import 'package:ai_order_assistant/features/products/domain/repositories/product_repository.dart';

class ProductRepositoryImpl implements ProductRepository {
  const ProductRepositoryImpl(this._remoteDataSource);

  final ProductRemoteDataSource _remoteDataSource;

  @override
  Future<List<Product>> getProducts({String query = ''}) async {
    final models = await _remoteDataSource.getProducts(query: query);
    return models.map((model) => model.toEntity()).toList();
  }

  @override
  Future<Product> createProduct({
    required String name,
    required String unit,
    required int price,
  }) async {
    final model = await _remoteDataSource.createProduct(
      name: name,
      unit: unit,
      price: price,
    );
    return model.toEntity();
  }

  @override
  Future<List<Product>> createProducts(List<NewProductInput> products) async {
    final models = await _remoteDataSource.createProducts(products);
    return models.map((model) => model.toEntity()).toList(growable: false);
  }

  @override
  Future<Product> updateProduct({
    required String id,
    required String name,
    required String unit,
    required int price,
  }) async {
    final model = await _remoteDataSource.updateProduct(
      id: id,
      name: name,
      unit: unit,
      price: price,
    );
    return model.toEntity();
  }

  @override
  Future<void> deleteProduct(String id) {
    return _remoteDataSource.deleteProduct(id);
  }
}
