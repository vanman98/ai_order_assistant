import 'package:ai_order_assistant/core/network/api_client.dart';
import 'package:ai_order_assistant/features/debts/data/models/customer_debt_model.dart';

class DebtsRemoteDataSource {
  const DebtsRemoteDataSource(this._client);

  final ApiClient _client;

  Future<List<CustomerDebtModel>> getCustomerDebts() {
    return _client.get<List<CustomerDebtModel>>(
      '/customers/debts',
      decode: (data) => (data as List<dynamic>)
          .map(
            (item) => CustomerDebtModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
    );
  }
}
