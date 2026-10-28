import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

enum ImagePickStatus {
  success,
  cancelled,
  error,
}

class ImagePickResult {
  final ImagePickStatus status;
  final String? filePath;
  final String? errorMessage;

  const ImagePickResult({
    required this.status,
    this.filePath,
    this.errorMessage,
  });

  bool get isSuccess => status == ImagePickStatus.success && filePath != null;
  bool get isCancelled => status == ImagePickStatus.cancelled;
}

/// Service managing device gallery photo picker and camera capture with format and size validation.
class ImagePickerService {
  final ImagePicker _picker;

  ImagePickerService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  static const List<String> _supportedExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
  ];

  static const int _maxFileSizeBytes = 15 * 1024 * 1024; // 15 MB limit

  /// Picks an existing receipt or screenshot from the photo gallery.
  Future<ImagePickResult> pickFromGallery() async {
    return _pick(ImageSource.gallery);
  }

  /// Launches the camera to photograph a physical receipt or bill.
  Future<ImagePickResult> captureFromCamera() async {
    return _pick(ImageSource.camera);
  }

  Future<ImagePickResult> _pick(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 4096,
        maxHeight: 4096,
        imageQuality: 100,
      );

      if (pickedFile == null) {
        return const ImagePickResult(status: ImagePickStatus.cancelled);
      }

      final file = File(pickedFile.path);
      if (!await file.exists()) {
        return const ImagePickResult(
          status: ImagePickStatus.error,
          errorMessage: 'The selected image could not be located on device.',
        );
      }

      final length = await file.length();
      if (length == 0) {
        return const ImagePickResult(
          status: ImagePickStatus.error,
          errorMessage: 'The selected image file is empty or corrupted.',
        );
      }

      if (length > _maxFileSizeBytes) {
        return const ImagePickResult(
          status: ImagePickStatus.error,
          errorMessage: 'The image file exceeds the 15 MB size limit.',
        );
      }

      final ext = pickedFile.path.split('.').last.toLowerCase();
      if (!_supportedExtensions.contains(ext)) {
        return ImagePickResult(
          status: ImagePickStatus.error,
          errorMessage: 'Unsupported image format (.$ext). Please select a PNG or JPEG receipt.',
        );
      }

      return ImagePickResult(
        status: ImagePickStatus.success,
        filePath: pickedFile.path,
      );
    } catch (e) {
      debugPrint('[ImagePickerService] Error picking image: $e');
      return ImagePickResult(
        status: ImagePickStatus.error,
        errorMessage: 'Could not access ${source == ImageSource.camera ? "camera" : "gallery"}: $e',
      );
    }
  }

  /// Cleans up a temporary receipt image when no longer needed to maintain privacy.
  static Future<void> deleteTempImage(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('[ImagePickerService] Non-critical error deleting temp image: $e');
    }
  }
}
