import 'dart:async';

import 'package:ai_order_assistant/features/order_intake/di/order_intake_providers.dart';
import 'package:ai_order_assistant/features/order_intake/domain/entities/order_extraction.dart';
import 'package:ai_order_assistant/features/order_intake/domain/repositories/order_intake_repository.dart';
import 'package:ai_order_assistant/features/order_intake/presentation/notifier/order_intake_notifier.dart';
import 'package:ai_order_assistant/features/order_intake/services/order_image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'selects compressed image and exposes upload progress and result',
    () async {
      final repository = _FakeOrderIntakeRepository();
      final container = _container(repository);
      addTearDown(container.dispose);

      await container
          .read(orderIntakeProvider.notifier)
          .selectImage(OrderImageSource.gallery);
      expect(container.read(orderIntakeProvider).imagePath, '/tmp/order.jpg');

      final analyze = container.read(orderIntakeProvider.notifier).analyze();
      repository.operations.single.reportProgress(0.4);
      expect(container.read(orderIntakeProvider).uploadProgress, 0.4);

      repository.operations.single.complete(_result);
      await analyze;
      expect(container.read(orderIntakeProvider).isUploading, isFalse);
      expect(
        container.read(orderIntakeProvider).result?.items.single.rawText,
        'Omo x2',
      );
    },
  );

  test('cancel stops the active upload without showing an error', () async {
    final repository = _FakeOrderIntakeRepository();
    final container = _container(repository);
    addTearDown(container.dispose);
    final notifier = container.read(orderIntakeProvider.notifier);

    await notifier.selectImage(OrderImageSource.camera);
    final analyze = notifier.analyze();
    notifier.cancelUpload();
    await analyze;

    expect(repository.operations.single.wasCancelled, isTrue);
    expect(container.read(orderIntakeProvider).isUploading, isFalse);
    expect(container.read(orderIntakeProvider).failure, isNull);
  });

  test('retry reuses the selected image after a retryable failure', () async {
    final repository = _FakeOrderIntakeRepository();
    final container = _container(repository);
    addTearDown(container.dispose);
    final notifier = container.read(orderIntakeProvider.notifier);

    await notifier.selectImage(OrderImageSource.gallery);
    final firstAnalyze = notifier.analyze();
    repository.operations.first.completeError(Exception('temporary'));
    await firstAnalyze;
    expect(container.read(orderIntakeProvider).canRetry, isTrue);

    final retry = notifier.retry();
    repository.operations.last.complete(_result);
    await retry;
    expect(repository.imagePaths, ['/tmp/order.jpg', '/tmp/order.jpg']);
    expect(container.read(orderIntakeProvider).result, same(_result));
  });
}

ProviderContainer _container(_FakeOrderIntakeRepository repository) {
  final container = ProviderContainer(
    overrides: [
      orderImagePickerProvider.overrideWithValue(const _FakeImagePicker()),
      orderIntakeRepositoryProvider.overrideWithValue(repository),
    ],
  );
  container.listen(orderIntakeProvider, (_, _) {});
  return container;
}

class _FakeImagePicker implements OrderImagePicker {
  const _FakeImagePicker();

  @override
  Future<String?> pickAndCompress(OrderImageSource source) async {
    return '/tmp/order.jpg';
  }
}

class _FakeOrderIntakeRepository implements OrderIntakeRepository {
  final operations = <_FakeOperation>[];
  final imagePaths = <String>[];

  @override
  OrderAnalysisOperation analyzeImage({
    required String imagePath,
    required UploadProgress onProgress,
  }) {
    imagePaths.add(imagePath);
    final operation = _FakeOperation(onProgress);
    operations.add(operation);
    return operation;
  }

  @override
  Future<OrderExtraction> resolveOrder(OrderExtraction extraction) async {
    return extraction;
  }
}

class _FakeOperation implements OrderAnalysisOperation {
  _FakeOperation(this._onProgress);

  final UploadProgress _onProgress;
  final _completer = Completer<OrderExtraction>();
  bool wasCancelled = false;

  @override
  Future<OrderExtraction> get result => _completer.future;

  void reportProgress(double progress) => _onProgress(progress);

  void complete(OrderExtraction value) => _completer.complete(value);

  void completeError(Object error) => _completer.completeError(error);

  @override
  void cancel() {
    wasCancelled = true;
    if (!_completer.isCompleted) {
      _completer.completeError(Exception('cancelled'));
    }
  }
}

const _result = OrderExtraction(
  items: [
    ExtractedOrderItem(
      rawText: 'Omo x2',
      rawProductName: 'Omo',
      quantity: 2,
      unit: 'gói',
      note: null,
      needsReview: false,
      uncertaintyReason: null,
      matchStatus: CatalogMatchStatus.missing,
      matchedProduct: null,
      candidates: [],
      lineTotal: null,
      selectedProductId: null,
    ),
  ],
  imageQuality: 'good',
  generalNote: null,
  allMatched: false,
  invoiceTotal: 0,
);
