class CustomerDebt {
  const CustomerDebt({
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
  final List<DebtOrder> orders;
}

class DebtOrder {
  const DebtOrder({
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
}
