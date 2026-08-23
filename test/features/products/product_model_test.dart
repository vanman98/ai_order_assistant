import 'package:ai_order_assistant/features/products/data/models/product_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps backend JSON to the domain entity', () {
    final model = ProductModel.fromJson({
      'id': 'product-1',
      'name': 'Omo Matic 3.6kg',
      'unit': 'gói',
      'price': 525000,
    });

    final entity = model.toEntity();
    expect(entity.id, 'product-1');
    expect(entity.name, 'Omo Matic 3.6kg');
    expect(entity.unit, 'gói');
    expect(entity.price, 525000);
  });
}
