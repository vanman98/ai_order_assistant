import 'package:ai_order_assistant/core/errors/error_handler.dart';
import 'package:ai_order_assistant/core/errors/failure.dart';
import 'package:ai_order_assistant/features/order_intake/di/order_intake_providers.dart';
import 'package:ai_order_assistant/features/order_intake/domain/entities/order_extraction.dart';
import 'package:ai_order_assistant/features/order_intake/domain/repositories/order_intake_repository.dart';
import 'package:ai_order_assistant/features/order_intake/services/order_image_picker.dart';
import 'package:ai_order_assistant/features/products/di/product_providers.dart';
import 'package:ai_order_assistant/features/products/presentation/notifier/product_list_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final orderIntakeProvider =
    NotifierProvider.autoDispose<OrderIntakeNotifier, OrderIntakeState>(
      OrderIntakeNotifier.new,
    );

class OrderIntakeNotifier extends Notifier<OrderIntakeState> {
  OrderAnalysisOperation? _operation;
  int _requestId = 0;

  @override
  OrderIntakeState build() {
    ref.onDispose(() => _operation?.cancel());
    return const OrderIntakeState();
  }

  Future<void> selectImage(OrderImageSource source) async {
    if (state.isUploading || state.isPreparing) return;
    state = state.copyWith(isPreparing: true, failure: null, result: null);
    try {
      final path = await ref
          .read(orderImagePickerProvider)
          .pickAndCompress(source);
      state = state.copyWith(
        imagePath: path ?? state.imagePath,
        isPreparing: false,
        uploadProgress: 0,
      );
    } on ImagePreparationException catch (error) {
      state = state.copyWith(
        isPreparing: false,
        failure: ValidationFailure(error.message),
      );
    } catch (_) {
      state = state.copyWith(
        isPreparing: false,
        failure: const UnexpectedFailure(
          'Không thể mở hoặc nén ảnh. Vui lòng thử lại.',
        ),
      );
    }
  }

  Future<void> analyze() async {
    final imagePath = state.imagePath;
    if (imagePath == null || state.isUploading) return;

    final requestId = ++_requestId;
    state = state.copyWith(
      isUploading: true,
      uploadProgress: 0,
      failure: null,
      result: null,
    );
    final operation = ref
        .read(orderIntakeRepositoryProvider)
        .analyzeImage(
          imagePath: imagePath,
          onProgress: (progress) {
            if (_requestId == requestId) {
              state = state.copyWith(uploadProgress: progress);
            }
          },
        );
    _operation = operation;

    try {
      final result = await operation.result;
      if (_requestId != requestId) return;
      state = state.copyWith(
        isUploading: false,
        uploadProgress: 1,
        result: result,
      );
    } catch (error) {
      if (_requestId != requestId) return;
      state = state.copyWith(
        isUploading: false,
        failure: ErrorHandler.from(error),
      );
    } finally {
      if (identical(_operation, operation)) _operation = null;
    }
  }

  Future<void> retry() => analyze();

  Future<void> selectCandidate({
    required int itemIndex,
    required CatalogProductCandidate candidate,
  }) async {
    final result = state.result;
    if (result == null || state.isUpdatingCatalog) return;

    final items = [...result.items];
    items[itemIndex] = items[itemIndex].copyWith(
      selectedProductId: candidate.id,
      needsReview: false,
      uncertaintyReason: null,
    );
    await _resolve(result.copyWith(items: items), itemIndex: itemIndex);
  }

  Future<bool> saveCatalogItem({
    required int itemIndex,
    required String name,
    required num quantity,
    required String unit,
    required int price,
  }) async {
    final result = state.result;
    if (result == null || state.isUpdatingCatalog) return false;

    state = state.copyWith(
      isUpdatingCatalog: true,
      updatingItemIndex: itemIndex,
      failure: null,
    );
    try {
      final item = result.items[itemIndex];
      final products = ref.read(productRepositoryProvider);
      final product = item.matchedProduct == null
          ? await products.createProduct(name: name, unit: unit, price: price)
          : await products.updateProduct(
              id: item.matchedProduct!.id,
              name: name,
              unit: unit,
              price: price,
            );

      final items = [...result.items];
      items[itemIndex] = item.copyWith(
        rawProductName: name,
        quantity: quantity,
        unit: unit,
        selectedProductId: product.id,
        needsReview: false,
        uncertaintyReason: null,
      );
      final resolved = await ref
          .read(orderIntakeRepositoryProvider)
          .resolveOrder(result.copyWith(items: items));
      ref.invalidate(productListProvider);
      state = state.copyWith(
        result: resolved,
        isUpdatingCatalog: false,
        updatingItemIndex: null,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        isUpdatingCatalog: false,
        updatingItemIndex: null,
        failure: ErrorHandler.from(error),
      );
      return false;
    }
  }

  Future<void> _resolve(
    OrderExtraction extraction, {
    required int itemIndex,
  }) async {
    state = state.copyWith(
      isUpdatingCatalog: true,
      updatingItemIndex: itemIndex,
      failure: null,
    );
    try {
      final resolved = await ref
          .read(orderIntakeRepositoryProvider)
          .resolveOrder(extraction);
      state = state.copyWith(
        result: resolved,
        isUpdatingCatalog: false,
        updatingItemIndex: null,
      );
    } catch (error) {
      state = state.copyWith(
        isUpdatingCatalog: false,
        updatingItemIndex: null,
        failure: ErrorHandler.from(error),
      );
    }
  }

  void cancelUpload() {
    if (!state.isUploading) return;
    _requestId++;
    _operation?.cancel();
    _operation = null;
    state = state.copyWith(
      isUploading: false,
      uploadProgress: 0,
      failure: null,
    );
  }
}

const _unset = Object();

class OrderIntakeState {
  const OrderIntakeState({
    this.imagePath,
    this.isPreparing = false,
    this.isUploading = false,
    this.uploadProgress = 0,
    this.isUpdatingCatalog = false,
    this.updatingItemIndex,
    this.result,
    this.failure,
  });

  final String? imagePath;
  final bool isPreparing;
  final bool isUploading;
  final double uploadProgress;
  final bool isUpdatingCatalog;
  final int? updatingItemIndex;
  final OrderExtraction? result;
  final Failure? failure;

  bool get canRetry => imagePath != null && (failure?.canRetry ?? false);

  OrderIntakeState copyWith({
    Object? imagePath = _unset,
    bool? isPreparing,
    bool? isUploading,
    double? uploadProgress,
    bool? isUpdatingCatalog,
    Object? updatingItemIndex = _unset,
    Object? result = _unset,
    Object? failure = _unset,
  }) {
    return OrderIntakeState(
      imagePath: identical(imagePath, _unset)
          ? this.imagePath
          : imagePath as String?,
      isPreparing: isPreparing ?? this.isPreparing,
      isUploading: isUploading ?? this.isUploading,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      isUpdatingCatalog: isUpdatingCatalog ?? this.isUpdatingCatalog,
      updatingItemIndex: identical(updatingItemIndex, _unset)
          ? this.updatingItemIndex
          : updatingItemIndex as int?,
      result: identical(result, _unset)
          ? this.result
          : result as OrderExtraction?,
      failure: identical(failure, _unset) ? this.failure : failure as Failure?,
    );
  }
}
