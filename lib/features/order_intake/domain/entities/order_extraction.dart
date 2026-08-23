class OrderExtraction {
  const OrderExtraction({
    required this.items,
    required this.imageQuality,
    required this.generalNote,
    required this.allMatched,
    required this.invoiceTotal,
  });

  final List<ExtractedOrderItem> items;
  final String imageQuality;
  final String? generalNote;
  final bool allMatched;
  final int invoiceTotal;

  OrderExtraction copyWith({List<ExtractedOrderItem>? items}) {
    return OrderExtraction(
      items: items ?? this.items,
      imageQuality: imageQuality,
      generalNote: generalNote,
      allMatched: allMatched,
      invoiceTotal: invoiceTotal,
    );
  }
}

enum CatalogMatchStatus { matched, review, missing }

class CatalogProductSummary {
  const CatalogProductSummary({
    required this.id,
    required this.name,
    required this.unit,
    required this.price,
  });

  final String id;
  final String name;
  final String unit;
  final int price;
}

class CatalogProductCandidate extends CatalogProductSummary {
  const CatalogProductCandidate({
    required super.id,
    required super.name,
    required super.unit,
    required super.price,
    required this.score,
  });

  final double score;
}

class ExtractedOrderItem {
  const ExtractedOrderItem({
    required this.rawText,
    required this.rawProductName,
    required this.quantity,
    required this.unit,
    this.extractedUnitPrice,
    required this.note,
    required this.needsReview,
    required this.uncertaintyReason,
    required this.matchStatus,
    required this.matchedProduct,
    required this.candidates,
    required this.lineTotal,
    required this.selectedProductId,
  });

  final String rawText;
  final String rawProductName;
  final num? quantity;
  final String? unit;
  final int? extractedUnitPrice;
  final String? note;
  final bool needsReview;
  final String? uncertaintyReason;
  final CatalogMatchStatus matchStatus;
  final CatalogProductSummary? matchedProduct;
  final List<CatalogProductCandidate> candidates;
  final int? lineTotal;
  final String? selectedProductId;

  String get displayName => matchedProduct?.name ?? rawProductName;
  String? get displayUnit => matchedProduct?.unit ?? unit;
  int? get unitPrice => matchedProduct?.price;

  ExtractedOrderItem copyWith({
    String? rawText,
    String? rawProductName,
    num? quantity,
    String? unit,
    bool? needsReview,
    Object? uncertaintyReason = _orderItemUnset,
    Object? selectedProductId = _orderItemUnset,
  }) {
    return ExtractedOrderItem(
      rawText: rawText ?? this.rawText,
      rawProductName: rawProductName ?? this.rawProductName,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      extractedUnitPrice: extractedUnitPrice,
      note: note,
      needsReview: needsReview ?? this.needsReview,
      uncertaintyReason: identical(uncertaintyReason, _orderItemUnset)
          ? this.uncertaintyReason
          : uncertaintyReason as String?,
      matchStatus: matchStatus,
      matchedProduct: matchedProduct,
      candidates: candidates,
      lineTotal: lineTotal,
      selectedProductId: identical(selectedProductId, _orderItemUnset)
          ? this.selectedProductId
          : selectedProductId as String?,
    );
  }
}

const _orderItemUnset = Object();
