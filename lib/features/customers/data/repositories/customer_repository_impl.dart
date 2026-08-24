import 'package:ai_order_assistant/features/customers/data/datasources/customer_remote_datasource.dart';
import 'package:ai_order_assistant/features/customers/domain/entities/customer.dart';
import 'package:ai_order_assistant/features/customers/domain/repositories/customer_repository.dart';

class CustomerRepositoryImpl implements CustomerRepository {
  const CustomerRepositoryImpl(this._remoteDataSource);

  final CustomerRemoteDataSource _remoteDataSource;

  @override
  Future<List<Customer>> getCustomers({String query = ''}) async {
    final models = await _remoteDataSource.getCustomers(query: query);
    return models.map((model) => model.toEntity()).toList();
  }

  @override
  Future<Customer> createCustomer({
    required String name,
    String phone = '',
    String note = '',
  }) async {
    final model = await _remoteDataSource.createCustomer(
      name: name,
      phone: phone,
      note: note,
    );
    return model.toEntity();
  }

  @override
  Future<Customer> updateCustomer({
    required String id,
    required String name,
    String phone = '',
    String note = '',
  }) async {
    final model = await _remoteDataSource.updateCustomer(
      id: id,
      name: name,
      phone: phone,
      note: note,
    );
    return model.toEntity();
  }

  @override
  Future<void> deleteCustomer(String id) {
    return _remoteDataSource.deleteCustomer(id);
  }
}
