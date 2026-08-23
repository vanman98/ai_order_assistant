import 'package:ai_order_assistant/features/products/domain/entities/product.dart';

class ProductModel {
  const ProductModel({
    required this.id,
    required this.name,
    required this.unit,
    required this.price,
  });

  final String id;
  final String name;
  final String unit;
  final int price;

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      name: json['name'] as String,
      unit: json['unit'] as String,
      price: json['price'] as int,
    );
  }

  Product toEntity() {
    return Product(id: id, name: name, unit: unit, price: price);
  }
}
