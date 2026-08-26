import 'package:ai_order_assistant/features/debts/domain/entities/customer_debt.dart';

class CustomerDebtModel {
  const CustomerDebtModel({
    required this.customerId,
    required this.customerName,
    required this.phone,
    required this.totalDebt,
    required this.unpaidOrderCount,
    required this.orders,
  });

  final String customerId;
  final String customerName;
  final String? phone;
  final int totalDebt;
  final int unpaidOrderCount;
  final List<DebtOrderModel> orders;

  factory CustomerDebtModel.fromJson(Map<String, dynamic> json) {
    final rawOrders = json['orders'] as List<dynamic>? ?? const [];
    return CustomerDebtModel(
      customerId: json['customerId'] as String,
      customerName: json['customerName'] as String? ?? 'Khách lẻ',
      phone: json['phone'] as String?,
      totalDebt: json['totalDebt'] as int? ?? 0,
      unpaidOrderCount: json['unpaidOrderCount'] as int? ?? 0,
      orders: rawOrders
          .map(
            (item) => DebtOrderModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
    );
  }

  CustomerDebt toEntity() {
    return CustomerDebt(
      customerId: customerId,
      customerName: customerName,
      phone: phone,
      totalDebt: totalDebt,
      unpaidOrderCount: unpaidOrderCount,
      orders: orders.map((order) => order.toEntity()).toList(growable: false),
    );
  }
}

class DebtOrderModel {
  const DebtOrderModel({
    required this.id,
    required this.code,
    required this.createdAt,
    required this.total,
    required this.paidTotal,
    required this.remaining,
  });

  final String id;
  final String code;
  final DateTime createdAt;
  final int total;
  final int paidTotal;
  final int remaining;

  factory DebtOrderModel.fromJson(Map<String, dynamic> json) {
    final total = json['total'] as int;
    final paidTotal = json['paidTotal'] as int? ?? 0;
    return DebtOrderModel(
      id: json['id'] as String,
      code: json['code'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      total: total,
      paidTotal: paidTotal,
      remaining: json['remaining'] as int? ?? (total - paidTotal),
    );
  }

  DebtOrder toEntity() {
    return DebtOrder(
      id: id,
      code: code,
      createdAt: createdAt,
      total: total,
      paidTotal: paidTotal,
      remaining: remaining,
    );
  }
}
