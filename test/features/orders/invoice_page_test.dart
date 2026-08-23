import 'package:ai_order_assistant/features/order_intake/domain/entities/order_extraction.dart';
import 'package:ai_order_assistant/features/orders/presentation/pages/invoice_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows a complete customer invoice that fits phone width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: InvoicePage(
          result: _invoice,
          createdAt: DateTime(2026, 8, 23, 15, 15),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('HÓA ĐƠN BÁN HÀNG'), findsOneWidget);
    expect(find.text('Mặt hàng'), findsOneWidget);
    expect(find.text('SL/ĐV'), findsOneWidget);
    expect(find.text('Đơn giá'), findsOneWidget);
    expect(find.text('Thành tiền'), findsOneWidget);
    expect(find.text('Bò Húc ít đường'), findsOneWidget);
    expect(find.text('13.000 ₫'), findsOneWidget);
    expect(find.text('26.000 ₫'), findsNWidgets(2));
    expect(find.text('CHIA SẺ ẢNH'), findsOneWidget);
    expect(find.text('Trạng thái'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      ),
      findsNothing,
    );

    expect(find.text('SAO CHÉP'), findsOneWidget);
  });
}

const _invoice = OrderExtraction(
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
