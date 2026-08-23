import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

enum OrderImageSource { camera, gallery }

abstract interface class OrderImagePicker {
  Future<String?> pickAndCompress(OrderImageSource source);
}

class OrderImagePickerImpl implements OrderImagePicker {
  OrderImagePickerImpl(this._picker);

  static const _maxUploadBytes = 8 * 1024 * 1024;
  final ImagePicker _picker;

  @override
  Future<String?> pickAndCompress(OrderImageSource source) async {
    final picked = await _picker.pickImage(
      source: source == OrderImageSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (picked == null) return null;

    final tempDirectory = await getTemporaryDirectory();
    final targetPath =
        '${tempDirectory.path}/order_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final compressed = await FlutterImageCompress.compressAndGetFile(
      picked.path,
      targetPath,
      minWidth: 2200,
      minHeight: 2200,
      quality: 82,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
    if (compressed == null) {
      throw const ImagePreparationException('Không thể nén ảnh đã chọn.');
    }

    final size = await File(compressed.path).length();
    if (size > _maxUploadBytes) {
      await File(compressed.path).delete();
      throw const ImagePreparationException(
        'Ảnh sau khi nén vẫn lớn hơn 8 MB. Hãy chọn ảnh khác.',
      );
    }
    return compressed.path;
  }
}

class ImagePreparationException implements Exception {
  const ImagePreparationException(this.message);

  final String message;
}
