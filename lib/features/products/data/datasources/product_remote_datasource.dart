import 'package:ai_order_assistant/core/network/api_client.dart';
import 'package:ai_order_assistant/features/products/data/models/product_model.dart';
import 'package:ai_order_assistant/features/products/domain/repositories/product_repository.dart';

class ProductRemoteDataSource {
  const ProductRemoteDataSource(this._client);

  final ApiClient _client;

  Future<List<ProductModel>> getProducts({String query = ''}) {
    return _client.get<List<ProductModel>>(
      '/products',
      queryParameters: query.trim().isEmpty ? null : {'q': query.trim()},
      decode: (data) {
        final list = data as List<dynamic>;
        return list
            .map(
              (item) =>
                  ProductModel.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList();
      },
    );
  }

  Future<ProductModel> createProduct({
    required String name,
    required String unit,
    required int price,
  }) {
    return _client.post<ProductModel>(
      '/products',
      data: {'name': name, 'unit': unit, 'price': price},
      decode: _decodeProduct,
    );
  }

  Future<List<ProductModel>> createProducts(List<NewProductInput> products) {
    return _client.post<List<ProductModel>>(
      '/products/bulk',
      data: {
        'items': products
            .map(
              (product) => {
                'name': product.name,
                'unit': product.unit,
                'price': product.price,
              },
            )
            .toList(growable: false),
      },
      decode: (data) => (data as List<dynamic>)
          .map(
            (item) =>
                ProductModel.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(growable: false),
    );
  }

  Future<ProductModel> updateProduct({
    required String id,
    required String name,
    required String unit,
    required int price,
  }) {
    return _client.patch<ProductModel>(
      '/products/$id',
      data: {'name': name, 'unit': unit, 'price': price},
      decode: _decodeProduct,
    );
  }

  Future<void> deleteProduct(String id) {
    return _client.delete<void>('/products/$id', decode: (_) {});
  }

  ProductModel _decodeProduct(dynamic data) {
    return ProductModel.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
