import 'package:ai_order_assistant/features/debts/data/datasources/debts_remote_datasource.dart';
import 'package:ai_order_assistant/features/debts/domain/entities/customer_debt.dart';
import 'package:ai_order_assistant/features/debts/domain/repositories/debts_repository.dart';

class DebtsRepositoryImpl implements DebtsRepository {
  const DebtsRepositoryImpl(this._remoteDataSource);

  final DebtsRemoteDataSource _remoteDataSource;

  @override
  Future<List<CustomerDebt>> getCustomerDebts() async {
    final models = await _remoteDataSource.getCustomerDebts();
    return models.map((model) => model.toEntity()).toList(growable: false);
  }
}
