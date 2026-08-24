import 'package:ai_order_assistant/core/errors/error_handler.dart';
import 'package:ai_order_assistant/features/customers/di/customer_providers.dart';
import 'package:ai_order_assistant/features/customers/domain/entities/customer.dart';
import 'package:ai_order_assistant/features/customers/domain/repositories/customer_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final customerListProvider =
    AsyncNotifierProvider<CustomerListNotifier, List<Customer>>(
      CustomerListNotifier.new,
    );

class CustomerListNotifier extends AsyncNotifier<List<Customer>> {
  String _query = '';

  CustomerRepository get _repository => ref.read(customerRepositoryProvider);

  @override
  Future<List<Customer>> build() {
    return _repository.getCustomers();
  }

  Future<void> search(String query) async {
    _query = query.trim();
    await _loadCurrentQuery();
  }

  Future<void> refresh() => _loadCurrentQuery();

  Future<bool> createCustomer({
    required String name,
    String phone = '',
    String note = '',
  }) {
    return _mutate(
      () =>
          _repository.createCustomer(name: name, phone: phone, note: note),
    );
  }

  Future<bool> updateCustomer({
    required String id,
    required String name,
    String phone = '',
    String note = '',
  }) {
    return _mutate(
      () => _repository.updateCustomer(
        id: id,
        name: name,
        phone: phone,
        note: note,
      ),
    );
  }

  Future<bool> deleteCustomer(String id) {
    return _mutate(() => _repository.deleteCustomer(id));
  }

  Future<void> _loadCurrentQuery() async {
    state = const AsyncLoading();
    try {
      final customers = await _repository.getCustomers(query: _query);
      state = AsyncData(customers);
    } catch (error, stackTrace) {
      state = AsyncError(ErrorHandler.from(error), stackTrace);
    }
  }

  Future<bool> _mutate(Future<Object?> Function() action) async {
    state = const AsyncLoading();
    try {
      await action();
      final customers = await _repository.getCustomers(query: _query);
      state = AsyncData(customers);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(ErrorHandler.from(error), stackTrace);
      return false;
    }
  }
}
