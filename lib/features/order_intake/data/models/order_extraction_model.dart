import 'package:ai_order_assistant/features/order_intake/domain/entities/order_extraction.dart';

class OrderExtractionModel extends OrderExtraction {
  const OrderExtractionModel({
    required super.items,
    required super.imageQuality,
    required super.generalNote,
    required super.allMatched,
    required super.invoiceTotal,
  });

  factory OrderExtractionModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    return OrderExtractionModel(
      items: rawItems
          .map(
            (item) => ExtractedOrderItemModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      imageQuality: json['imageQuality'] as String? ?? 'poor',
      generalNote: json['generalNote'] as String?,
      allMatched: json['allMatched'] as bool? ?? false,
      invoiceTotal: json['invoiceTotal'] as int? ?? 0,
    );
  }
}

class ExtractedOrderItemModel extends ExtractedOrderItem {
  const ExtractedOrderItemModel({
    required super.rawText,
    required super.rawProductName,
    required super.quantity,
    required super.unit,
    super.extractedUnitPrice,
    required super.note,
    required super.needsReview,
    required super.uncertaintyReason,
    required super.matchStatus,
    required super.matchedProduct,
    required super.candidates,
    required super.lineTotal,
    required super.selectedProductId,
  });

  factory ExtractedOrderItemModel.fromJson(Map<String, dynamic> json) {
    return ExtractedOrderItemModel(
      rawText: json['rawText'] as String? ?? '',
      rawProductName: json['rawProductName'] as String? ?? '',
      quantity: json['quantity'] as num?,
      unit: json['unit'] as String?,
      extractedUnitPrice: json['unitPrice'] as int?,
      note: json['note'] as String?,
      needsReview: json['needsReview'] as bool? ?? true,
      uncertaintyReason: json['uncertaintyReason'] as String?,
      matchStatus: _parseMatchStatus(json['matchStatus'] as String?),
      matchedProduct: json['matchedProduct'] == null
          ? null
          : _productSummary(
              Map<String, dynamic>.from(json['matchedProduct'] as Map),
            ),
      candidates: (json['candidates'] as List<dynamic>? ?? const [])
          .map(
            (candidate) =>
                _candidate(Map<String, dynamic>.from(candidate as Map)),
          )
          .toList(growable: false),
      lineTotal: json['lineTotal'] as int?,
      selectedProductId: json['selectedProductId'] as String?,
    );
  }

  static CatalogMatchStatus _parseMatchStatus(String? value) {
    return switch (value) {
      'matched' => CatalogMatchStatus.matched,
      'review' => CatalogMatchStatus.review,
      _ => CatalogMatchStatus.missing,
    };
  }

  static CatalogProductSummary _productSummary(Map<String, dynamic> json) {
    return CatalogProductSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      unit: json['unit'] as String,
      price: json['price'] as int,
    );
  }

  static CatalogProductCandidate _candidate(Map<String, dynamic> json) {
    return CatalogProductCandidate(
      id: json['id'] as String,
      name: json['name'] as String,
      unit: json['unit'] as String,
      price: json['price'] as int,
      score: (json['score'] as num).toDouble(),
    );
  }
}
