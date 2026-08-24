import 'package:ai_order_assistant/core/network/api_client.dart';
import 'package:ai_order_assistant/features/customers/data/models/customer_model.dart';

class CustomerRemoteDataSource {
  const CustomerRemoteDataSource(this._client);

  final ApiClient _client;

  Future<List<CustomerModel>> getCustomers({String query = ''}) {
    return _client.get<List<CustomerModel>>(
      '/customers',
      queryParameters: query.trim().isEmpty ? null : {'q': query.trim()},
      decode: (data) {
        final list = data as List<dynamic>;
        return list
            .map(
              (item) => CustomerModel.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
      },
    );
  }

  // Ghi chu: phone/note luon duoc gui len (co the la chuoi rong) thay vi bi
  // bo qua khi rong, de dam bao xoa trang so dien thoai/ghi chu cu cung hoat
  // dong dung khi sua (backend coi '' la "khong co" va luu thanh null).
  Future<CustomerModel> createCustomer({
    required String name,
    String phone = '',
    String note = '',
  }) {
    return _client.post<CustomerModel>(
      '/customers',
      data: {'name': name, 'phone': phone, 'note': note},
      decode: _decodeCustomer,
    );
  }

  Future<CustomerModel> updateCustomer({
    required String id,
    required String name,
    String phone = '',
    String note = '',
  }) {
    return _client.patch<CustomerModel>(
      '/customers/$id',
      data: {'name': name, 'phone': phone, 'note': note},
      decode: _decodeCustomer,
    );
  }

  Future<void> deleteCustomer(String id) {
    return _client.delete<void>('/customers/$id', decode: (_) {});
  }

  CustomerModel _decodeCustomer(dynamic data) {
    return CustomerModel.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
