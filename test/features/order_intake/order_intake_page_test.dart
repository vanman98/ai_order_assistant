import 'package:ai_order_assistant/features/order_intake/di/order_intake_providers.dart';
import 'package:ai_order_assistant/features/order_intake/domain/entities/order_extraction.dart';
import 'package:ai_order_assistant/features/order_intake/domain/repositories/order_intake_repository.dart';
import 'package:ai_order_assistant/features/order_intake/presentation/pages/order_intake_page.dart';
import 'package:ai_order_assistant/features/order_intake/services/order_image_picker.dart';
import 'package:ai_order_assistant/features/orders/di/orders_providers.dart';
import 'package:ai_order_assistant/features/orders/domain/entities/order.dart'
    as orders_domain;
import 'package:ai_order_assistant/features/orders/domain/repositories/orders_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the six-column order review UI without product images', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderImagePickerProvider.overrideWithValue(const _FakeImagePicker()),
          orderIntakeRepositoryProvider.overrideWithValue(
            const _FakeOrderIntakeRepository(),
          ),
        ],
        child: const MaterialApp(
          home: OrderIntakePage(source: OrderImageSource.gallery),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Ensure the asynchronous picker result has been rendered.
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -450));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ĐỌC NỘI DUNG ẢNH'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('Kiểm tra đơn hàng'), findsOneWidget);
    expect(find.text('Mặt hàng'), findsOneWidget);
    expect(find.text('SL'), findsOneWidget);
    expect(find.text('Đơn vị'), findsOneWidget);
    expect(find.text('Giá'), findsOneWidget);
    expect(find.text('Thành tiền'), findsOneWidget);
    expect(find.text('Trạng thái'), findsOneWidget);
    expect(find.text('Bò Húc ít đường'), findsOneWidget);
    expect(find.text('13.000 ₫'), findsOneWidget);
    expect(find.text('26.000 ₫'), findsNWidgets(2));
    expect(find.text('Đã khớp'), findsOneWidget);
    expect(find.text('Gợi ý sản phẩm phù hợp'), findsOneWidget);
    expect(find.text('DANH MỤC'), findsOneWidget);
    expect(find.text('Tạm tính (1 mặt hàng)'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      ),
      findsNothing,
    );
  });

  testWidgets('opens the customer invoice after confirming a matched order', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderImagePickerProvider.overrideWithValue(const _FakeImagePicker()),
          orderIntakeRepositoryProvider.overrideWithValue(
            const _FakeOrderIntakeRepository(_matchedResult),
          ),
          ordersRepositoryProvider.overrideWithValue(
            const _FakeOrdersRepository(),
          ),
        ],
        child: const MaterialApp(
          home: OrderIntakePage(source: OrderImageSource.gallery),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ĐỌC NỘI DUNG ẢNH'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('XÁC NHẬN'));
    await tester.pumpAndSettle();

    expect(find.text('Hóa đơn khách hàng'), findsOneWidget);
    expect(find.text('HÓA ĐƠN BÁN HÀNG'), findsOneWidget);
    expect(find.text('CHIA SẺ ẢNH'), findsOneWidget);
  });
}

class _FakeOrdersRepository implements OrdersRepository {
  const _FakeOrdersRepository();

  @override
  Future<orders_domain.Order> confirmOrder({
    required String clientRequestId,
    required List<orders_domain.ConfirmOrderItemInput> items,
    String? customerName,
    String? note,
  }) async {
    return orders_domain.Order(
      id: 'order-1',
      code: 'HD20260823-ABCDEF',
      clientRequestId: clientRequestId,
      customerNameSnapshot: customerName ?? 'Khách lẻ',
      subtotal: 26000,
      total: 26000,
      note: note,
      createdAt: DateTime(2026, 8, 23, 10),
      items: const [],
    );
  }

  @override
  Future<List<orders_domain.Order>> getTodayOrders() async => const [];
}

class _FakeImagePicker implements OrderImagePicker {
  const _FakeImagePicker();

  @override
  Future<String?> pickAndCompress(OrderImageSource source) async {
    return '/tmp/non-existent-preview.jpg';
  }
}

class _FakeOrderIntakeRepository implements OrderIntakeRepository {
  const _FakeOrderIntakeRepository([this.result = _result]);

  final OrderExtraction result;

  @override
  OrderAnalysisOperation analyzeImage({
    required String imagePath,
    required UploadProgress onProgress,
  }) {
    onProgress(1);
    return _CompletedOperation(result);
  }

  @override
  Future<OrderExtraction> resolveOrder(OrderExtraction extraction) async {
    return extraction;
  }
}

class _CompletedOperation implements OrderAnalysisOperation {
  const _CompletedOperation(this.value);

  final OrderExtraction value;

  @override
  Future<OrderExtraction> get result => Future.value(value);

  @override
  void cancel() {}
}

const _result = OrderExtraction(
  items: [
    ExtractedOrderItem(
      rawText: '2 lon Bò Húc ít đường',
      rawProductName: 'Bò Húc ít đường',
      quantity: 2,
      unit: 'lon',
      note: null,
      needsReview: false,
      uncertaintyReason: null,
      matchStatus: CatalogMatchStatus.matched,
      matchedProduct: CatalogProductSummary(
        id: 'product-1',
        name: 'Bò Húc ít đường',
        unit: 'lon',
        price: 13000,
      ),
      candidates: [],
      lineTotal: 26000,
      selectedProductId: 'product-1',
    ),
    ExtractedOrderItem(
      rawText: '2 bị Downy nắng mai',
      rawProductName: 'Downy nắng mai',
      quantity: 2,
      unit: 'bị',
      note: null,
      needsReview: true,
      uncertaintyReason: 'Chưa rõ dung tích',
      matchStatus: CatalogMatchStatus.review,
      matchedProduct: null,
      candidates: [
        CatalogProductCandidate(
          id: 'product-2',
          name: 'Nước xả Downy hương nắng mai 3.2L',
          unit: 'túi',
          price: 164000,
          score: 0.82,
        ),
      ],
      lineTotal: null,
      selectedProductId: null,
    ),
    ExtractedOrderItem(
      rawText: '2 bị Omo nước to',
      rawProductName: 'Bột giặt OMO nước to',
      quantity: 2,
      unit: 'bị',
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
  invoiceTotal: 26000,
);

const _matchedResult = OrderExtraction(
  items: [
    ExtractedOrderItem(
      rawText: '2 lon Bò Húc ít đường',
      rawProductName: 'Bò Húc ít đường',
      quantity: 2,
      unit: 'lon',
      note: null,
      needsReview: false,
      uncertaintyReason: null,
      matchStatus: CatalogMatchStatus.matched,
      matchedProduct: CatalogProductSummary(
        id: 'product-1',
        name: 'Bò Húc ít đường',
        unit: 'lon',
        price: 13000,
      ),
      candidates: [],
      lineTotal: 26000,
      selectedProductId: 'product-1',
    ),
  ],
  imageQuality: 'good',
  generalNote: null,
  allMatched: true,
  invoiceTotal: 26000,
);
