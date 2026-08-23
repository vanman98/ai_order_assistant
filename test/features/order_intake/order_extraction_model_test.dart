import 'package:ai_order_assistant/features/order_intake/data/models/order_extraction_model.dart';
import 'package:ai_order_assistant/features/order_intake/domain/entities/order_extraction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses extraction, catalog match and invoice fields', () {
    final result = OrderExtractionModel.fromJson({
      'items': [
        {
          'rawText': 'Omo 3k6 x2 giao sáng',
          'rawProductName': 'Omo 3k6',
          'quantity': 2,
          'unit': 'gói',
          'unitPrice': 118000,
          'note': 'giao sáng',
          'needsReview': true,
          'uncertaintyReason': 'Tên viết tắt trong ảnh',
          'matchStatus': 'matched',
          'matchedProduct': {
            'id': 'product-1',
            'name': 'Omo 3k6',
            'unit': 'gói',
            'price': 120000,
          },
          'candidates': [],
          'lineTotal': 240000,
          'selectedProductId': 'product-1',
        },
      ],
      'imageQuality': 'readable',
      'generalNote': 'Góc ảnh hơi tối',
      'allMatched': true,
      'invoiceTotal': 240000,
      'meta': {'model': 'gpt-5.6', 'mimeType': 'image/jpeg', 'sizeBytes': 1200},
    });

    expect(result.items, hasLength(1));
    expect(result.items.single.rawProductName, 'Omo 3k6');
    expect(result.items.single.quantity, 2);
    expect(result.items.single.unit, 'gói');
    expect(result.items.single.extractedUnitPrice, 118000);
    expect(result.items.single.note, 'giao sáng');
    expect(result.items.single.needsReview, isTrue);
    expect(result.items.single.uncertaintyReason, 'Tên viết tắt trong ảnh');
    expect(result.items.single.matchStatus, CatalogMatchStatus.matched);
    expect(result.items.single.matchedProduct?.unit, 'gói');
    expect(result.items.single.lineTotal, 240000);
    expect(result.allMatched, isTrue);
    expect(result.invoiceTotal, 240000);
    expect(result.imageQuality, 'readable');
    expect(result.generalNote, 'Góc ảnh hơi tối');
  });
}
