enum PaymentMethod { cash, bankTransfer, other }

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
    required this.paidTotal,
    required this.remaining,
    required this.payments,
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
  final int paidTotal;
  final int remaining;
  final List<PaymentEntry> payments;

  bool get isFullyPaid => remaining <= 0;
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

class PaymentEntry {
  const PaymentEntry({
    required this.id,
    required this.amount,
    required this.method,
    required this.note,
    required this.createdAt,
  });

  final String id;
  final int amount;
  final PaymentMethod method;
  final String? note;
  final DateTime createdAt;
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
