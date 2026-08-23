import 'package:ai_order_assistant/features/order_intake/di/order_intake_providers.dart';
import 'package:ai_order_assistant/features/order_intake/domain/entities/order_extraction.dart';
import 'package:ai_order_assistant/features/order_intake/domain/repositories/order_intake_repository.dart';
import 'package:ai_order_assistant/features/order_intake/services/order_image_picker.dart';
import 'package:ai_order_assistant/features/products/di/product_providers.dart';
import 'package:ai_order_assistant/features/products/domain/entities/product.dart';
import 'package:ai_order_assistant/features/products/domain/repositories/product_repository.dart';
import 'package:ai_order_assistant/features/products/presentation/pages/catalog_scan_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('prefills missing product fields and saves them in bulk', (
    tester,
  ) async {
    final products = _FakeProductRepository();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderImagePickerProvider.overrideWithValue(const _FakeImagePicker()),
          orderIntakeRepositoryProvider.overrideWithValue(
            const _FakeOrderIntakeRepository(),
          ),
          productRepositoryProvider.overrideWithValue(products),
        ],
        child: const MaterialApp(
          home: CatalogScanPage(source: OrderImageSource.gallery),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI QUÉT DANH MỤC'));
    await tester.pumpAndSettle();

    expect(find.text('Quét hàng từ đơn'), findsOneWidget);
    expect(find.text('Dầu Meizan 1 lít'), findsOneWidget);
    expect(find.text('Bò Húc ít đường'), findsNothing);
    expect(find.text('420000'), findsOneWidget);
    expect(find.text('THÊM 1 SẢN PHẨM'), findsOneWidget);

    await tester.tap(find.text('THÊM 1 SẢN PHẨM'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Đã thêm vào danh mục'), findsOneWidget);
    expect(products.created.single.name, 'Dầu Meizan 1 lít');
    expect(products.created.single.unit, 'thùng');
    expect(products.created.single.price, 420000);
  });
}

class _FakeImagePicker implements OrderImagePicker {
  const _FakeImagePicker();

  @override
  Future<String?> pickAndCompress(OrderImageSource source) async =>
      '/tmp/non-existent-scan.jpg';
}

class _FakeOrderIntakeRepository implements OrderIntakeRepository {
  const _FakeOrderIntakeRepository();

  @override
  OrderAnalysisOperation analyzeImage({
    required String imagePath,
    required UploadProgress onProgress,
  }) {
    onProgress(1);
    return const _CompletedOperation(_scanResult);
  }

  @override
  Future<OrderExtraction> resolveOrder(OrderExtraction extraction) async =>
      extraction;
}

class _CompletedOperation implements OrderAnalysisOperation {
  const _CompletedOperation(this.value);

  final OrderExtraction value;

  @override
  Future<OrderExtraction> get result => Future.value(value);

  @override
  void cancel() {}
}

class _FakeProductRepository implements ProductRepository {
  final created = <NewProductInput>[];

  @override
  Future<List<Product>> createProducts(List<NewProductInput> products) async {
    created.addAll(products);
    return products
        .map(
          (item) => Product(
            id: 'created-${created.indexOf(item)}',
            name: item.name,
            unit: item.unit,
            price: item.price,
          ),
        )
        .toList();
  }

  @override
  Future<Product> createProduct({
    required String name,
    required String unit,
    required int price,
  }) => throw UnimplementedError();

  @override
  Future<void> deleteProduct(String id) => throw UnimplementedError();

  @override
  Future<List<Product>> getProducts({String query = ''}) async => const [];

  @override
  Future<Product> updateProduct({
    required String id,
    required String name,
    required String unit,
    required int price,
  }) => throw UnimplementedError();
}

const _scanResult = OrderExtraction(
  items: [
    ExtractedOrderItem(
      rawText: '2 thùng bò húc ít đường',
      rawProductName: 'Bò Húc ít đường',
      quantity: 2,
      unit: 'thùng',
      note: null,
      needsReview: false,
      uncertaintyReason: null,
      matchStatus: CatalogMatchStatus.matched,
      matchedProduct: CatalogProductSummary(
        id: 'existing-1',
        name: 'Bò Húc ít đường',
        unit: 'thùng',
        price: 260000,
      ),
      candidates: [],
      lineTotal: 520000,
      selectedProductId: 'existing-1',
    ),
    ExtractedOrderItem(
      rawText: '1 thùng dầu Meizan 1 lít 420.000đ',
      rawProductName: 'Dầu Meizan 1 lít',
      quantity: 1,
      unit: 'thùng',
      extractedUnitPrice: 420000,
      note: null,
      needsReview: false,
      uncertaintyReason: null,
      matchStatus: CatalogMatchStatus.missing,
      matchedProduct: null,
      candidates: [],
      lineTotal: null,
      selectedProductId: null,
    ),
  ],
  imageQuality: 'good',
  generalNote: null,
  allMatched: false,
  invoiceTotal: 520000,
);
