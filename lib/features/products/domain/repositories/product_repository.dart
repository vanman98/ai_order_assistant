import 'package:ai_order_assistant/features/products/domain/entities/product.dart';

class NewProductInput {
  const NewProductInput({
    required this.name,
    required this.unit,
    required this.price,
  });

  final String name;
  final String unit;
  final int price;
}

abstract interface class ProductRepository {
  Future<List<Product>> getProducts({String query = ''});

  Future<Product> createProduct({
    required String name,
    required String unit,
    required int price,
  });

  Future<List<Product>> createProducts(List<NewProductInput> products);

  Future<Product> updateProduct({
    required String id,
    required String name,
    required String unit,
    required int price,
  });

  Future<void> deleteProduct(String id);
}
