class Order {
  const Order({
    required this.id,
    required this.code,
    required this.clientRequestId,
    required this.customerNameSnapshot,
    required this.subtotal,
    required this.total,
    required this.note,
    required this.createdAt,
    required this.items,
  });

  final String id;
  final String code;
  final String clientRequestId;
  final String customerNameSnapshot;
  final int subtotal;
  final int total;
  final String? note;
  final DateTime createdAt;
  final List<OrderItemEntry> items;
}

class OrderItemEntry {
  const OrderItemEntry({
    required this.id,
    required this.nameSnapshot,
    required this.unitSnapshot,
    required this.unitPriceSnapshot,
    required this.quantity,
    required this.lineTotal,
  });

  final String id;
  final String nameSnapshot;
  final String unitSnapshot;
  final int unitPriceSnapshot;
  final num quantity;
  final int lineTotal;
}

class ConfirmOrderItemInput {
  const ConfirmOrderItemInput({
    required this.productId,
    required this.quantity,
    this.rawText,
  });

  final String productId;
  final num quantity;
  final String? rawText;
}
