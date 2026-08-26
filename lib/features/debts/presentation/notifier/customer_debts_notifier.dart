import 'package:ai_order_assistant/core/errors/error_handler.dart';
import 'package:ai_order_assistant/features/debts/di/debts_providers.dart';
import 'package:ai_order_assistant/features/debts/domain/entities/customer_debt.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final customerDebtsProvider =
    AsyncNotifierProvider<CustomerDebtsNotifier, List<CustomerDebt>>(
      CustomerDebtsNotifier.new,
    );

class CustomerDebtsNotifier extends AsyncNotifier<List<CustomerDebt>> {
  @override
  Future<List<CustomerDebt>> build() {
    return ref.read(debtsRepositoryProvider).getCustomerDebts();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(debtsRepositoryProvider).getCustomerDebts(),
    );
  }
}

extension CustomerDebtsFailure on AsyncValue<List<CustomerDebt>> {
  String? get failureMessage {
    final error = this.error;
    if (error == null) return null;
    return ErrorHandler.from(error).message;
  }
}
