import 'package:ai_order_assistant/features/customers/domain/entities/customer.dart';

abstract interface class CustomerRepository {
  Future<List<Customer>> getCustomers({String query = ''});

  Future<Customer> createCustomer({
    required String name,
    String phone = '',
    String note = '',
  });

  Future<Customer> updateCustomer({
    required String id,
    required String name,
    String phone = '',
    String note = '',
  });

  Future<void> deleteCustomer(String id);
}
