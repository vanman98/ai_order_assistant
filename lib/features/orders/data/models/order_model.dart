import 'package:ai_order_assistant/features/orders/domain/entities/order.dart';

class OrderModel {
  const OrderModel({
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
  final List<OrderItemEntryModel> items;
  final int paidTotal;
  final int remaining;
  final List<PaymentEntryModel> payments;

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    final rawPayments = json['payments'] as List<dynamic>? ?? const [];
    final total = json['total'] as int;
    return OrderModel(
      id: json['id'] as String,
      code: json['code'] as String,
      clientRequestId: json['clientRequestId'] as String,
      customerNameSnapshot: json['customerNameSnapshot'] as String? ?? 'Khách lẻ',
      subtotal: json['subtotal'] as int,
      total: total,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      items: rawItems
          .map(
            (item) => OrderItemEntryModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      // Backend luon tra ve paidTotal/remaining (tinh tu payments), nhung
      // van co fallback o day de an toan neu goi 1 endpoint cu chua co 2
      // truong nay.
      paidTotal: json['paidTotal'] as int? ?? 0,
      remaining: json['remaining'] as int? ?? total,
      payments: rawPayments
          .map(
            (item) => PaymentEntryModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
    );
  }

  Order toEntity() {
    return Order(
      id: id,
      code: code,
      clientRequestId: clientRequestId,
      customerNameSnapshot: customerNameSnapshot,
      subtotal: subtotal,
      total: total,
      note: note,
      createdAt: createdAt,
      items: items.map((item) => item.toEntity()).toList(growable: false),
      paidTotal: paidTotal,
      remaining: remaining,
      payments: payments.map((p) => p.toEntity()).toList(growable: false),
    );
  }
}

class OrderItemEntryModel {
  const OrderItemEntryModel({
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

  factory OrderItemEntryModel.fromJson(Map<String, dynamic> json) {
    return OrderItemEntryModel(
      id: json['id'] as String,
      nameSnapshot: json['nameSnapshot'] as String,
      unitSnapshot: json['unitSnapshot'] as String,
      unitPriceSnapshot: json['unitPriceSnapshot'] as int,
      quantity: json['quantity'] as num,
      lineTotal: json['lineTotal'] as int,
    );
  }

  OrderItemEntry toEntity() {
    return OrderItemEntry(
      id: id,
      nameSnapshot: nameSnapshot,
      unitSnapshot: unitSnapshot,
      unitPriceSnapshot: unitPriceSnapshot,
      quantity: quantity,
      lineTotal: lineTotal,
    );
  }
}

class PaymentEntryModel {
  const PaymentEntryModel({
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

  factory PaymentEntryModel.fromJson(Map<String, dynamic> json) {
    return PaymentEntryModel(
      id: json['id'] as String,
      amount: json['amount'] as int,
      method: paymentMethodFromApi(json['method'] as String?),
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  PaymentEntry toEntity() {
    return PaymentEntry(
      id: id,
      amount: amount,
      method: method,
      note: note,
      createdAt: createdAt,
    );
  }
}

/// Chuyen doi qua lai giua enum PaymentMethod cua app va chuoi enum
/// PaymentMethod ben backend (Prisma) - 'CASH' | 'BANK_TRANSFER' | 'OTHER'.
PaymentMethod paymentMethodFromApi(String? value) {
  switch (value) {
    case 'BANK_TRANSFER':
      return PaymentMethod.bankTransfer;
    case 'OTHER':
      return PaymentMethod.other;
    case 'CASH':
    default:
      return PaymentMethod.cash;
  }
}

String paymentMethodToApi(PaymentMethod method) {
  switch (method) {
    case PaymentMethod.bankTransfer:
      return 'BANK_TRANSFER';
    case PaymentMethod.other:
      return 'OTHER';
    case PaymentMethod.cash:
      return 'CASH';
  }
}
