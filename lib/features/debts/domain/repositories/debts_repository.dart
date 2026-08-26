import 'package:ai_order_assistant/features/debts/domain/entities/customer_debt.dart';

abstract interface class DebtsRepository {
  Future<List<CustomerDebt>> getCustomerDebts();
}
