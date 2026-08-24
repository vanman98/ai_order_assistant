import 'package:ai_order_assistant/features/customers/domain/entities/customer.dart';

class CustomerModel {
  const CustomerModel({
    required this.id,
    required this.name,
    this.phone,
    this.note,
  });

  final String id;
  final String name;
  final String? phone;
  final String? note;

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      note: json['note'] as String?,
    );
  }

  Customer toEntity() {
    return Customer(id: id, name: name, phone: phone, note: note);
  }
}
