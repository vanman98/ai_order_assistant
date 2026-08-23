import 'package:ai_order_assistant/core/di/app_providers.dart';
import 'package:ai_order_assistant/features/order_intake/data/datasources/order_intake_remote_datasource.dart';
import 'package:ai_order_assistant/features/order_intake/data/repositories/order_intake_repository_impl.dart';
import 'package:ai_order_assistant/features/order_intake/domain/repositories/order_intake_repository.dart';
import 'package:ai_order_assistant/features/order_intake/services/order_image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

final orderImagePickerProvider = Provider<OrderImagePicker>((ref) {
  return OrderImagePickerImpl(ImagePicker());
});

final orderIntakeRemoteDataSourceProvider =
    Provider<OrderIntakeRemoteDataSource>(
      (ref) => OrderIntakeRemoteDataSource(ref.watch(apiClientProvider)),
    );

final orderIntakeRepositoryProvider = Provider<OrderIntakeRepository>((ref) {
  return OrderIntakeRepositoryImpl(
    ref.watch(orderIntakeRemoteDataSourceProvider),
  );
});
