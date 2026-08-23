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

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    return OrderModel(
      id: json['id'] as String,
      code: json['code'] as String,
      clientRequestId: json['clientRequestId'] as String,
      customerNameSnapshot: json['customerNameSnapshot'] as String? ?? 'Khách lẻ',
      subtotal: json['subtotal'] as int,
      total: json['total'] as int,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      items: rawItems
          .map(
            (item) => OrderItemEntryModel.fromJson(
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
