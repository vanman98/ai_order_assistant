import 'package:ai_order_assistant/app/app.dart';
import 'package:ai_order_assistant/features/products/di/product_providers.dart';
import 'package:ai_order_assistant/features/products/domain/entities/product.dart';
import 'package:ai_order_assistant/features/products/domain/repositories/product_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Home shows four main actions', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productRepositoryProvider.overrideWithValue(_FakeProductRepository()),
        ],
        child: const AiOrderAssistantApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CHỤP ĐƠN'), findsOneWidget);
    expect(find.text('CHỌN ẢNH TỪ MÁY'), findsOneWidget);
    expect(find.text('ĐƠN HÔM NAY'), findsOneWidget);
    expect(find.text('DANH MỤC HÀNG'), findsOneWidget);
  });

  testWidgets('Can load product catalog from Home', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productRepositoryProvider.overrideWithValue(_FakeProductRepository()),
        ],
        child: const AiOrderAssistantApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('DANH MỤC HÀNG'));
    await tester.pumpAndSettle();

    expect(find.text('Omo Matic nước giặt loại lớn 3.6kg'), findsOneWidget);
    expect(find.text('Tên hàng'), findsOneWidget);
    expect(find.text('Đơn vị'), findsOneWidget);
    expect(find.text('Giá bán'), findsOneWidget);
    expect(find.text('Thao tác'), findsOneWidget);
    expect(find.text('525.000 ₫'), findsOneWidget);
    expect(find.text('SỬA'), findsOneWidget);
    expect(find.text('XÓA'), findsOneWidget);
    expect(find.text('Trạng thái'), findsNothing);
    expect(find.text('NHẬP EXCEL'), findsNothing);
    expect(find.text('QUÉT ĐƠN AI'), findsOneWidget);
    expect(find.text('THÊM HÀNG'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      ),
      findsNothing,
    );

    await tester.tap(find.text('XÓA'));
    await tester.pumpAndSettle();
    expect(find.text('Xóa sản phẩm?'), findsOneWidget);
    expect(find.textContaining('không thể hoàn tác'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'XÓA'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có sản phẩm'), findsOneWidget);
  });
}

class _FakeProductRepository implements ProductRepository {
  final products = <Product>[
    const Product(
      id: 'product-1',
      name: 'Omo Matic nước giặt loại lớn 3.6kg',
      unit: 'gói',
      price: 525000,
    ),
  ];

  @override
  Future<List<Product>> getProducts({String query = ''}) async {
    if (query.isEmpty) return List.unmodifiable(products);
    return products
        .where(
          (product) => product.name.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
  }

  @override
  Future<Product> createProduct({
    required String name,
    required String unit,
    required int price,
  }) async {
    final product = Product(
      id: 'product-${products.length + 1}',
      name: name,
      unit: unit,
      price: price,
    );
    products.add(product);
    return product;
  }

  @override
  Future<List<Product>> createProducts(List<NewProductInput> inputs) async {
    final created = <Product>[];
    for (final input in inputs) {
      created.add(
        await createProduct(
          name: input.name,
          unit: input.unit,
          price: input.price,
        ),
      );
    }
    return created;
  }

  @override
  Future<Product> updateProduct({
    required String id,
    required String name,
    required String unit,
    required int price,
  }) async {
    final index = products.indexWhere((product) => product.id == id);
    final product = Product(id: id, name: name, unit: unit, price: price);
    products[index] = product;
    return product;
  }

  @override
  Future<void> deleteProduct(String id) async {
    products.removeWhere((product) => product.id == id);
  }
}
