import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Preprocessing configuration and results for optimizing receipt images prior to OCR.
class ImagePreprocessor {
  static const int maxDimension = 2048;
  static const int defaultQuality = 85;

  /// Optimizes receipt image for offline on-device OCR:
  /// 1. Bakes in EXIF orientation so rotated camera photos become upright.
  /// 2. Downscales oversized images (e.g. 48MP phone cameras) to max 2048px to prevent OOM errors and accelerate ML Kit.
  /// 3. Normalizes contrast and grayscale where beneficial for faint thermal receipts.
  /// Runs inside a background isolate via [compute] so the main UI thread never blocks.
  static Future<String> preprocessReceipt(
    String originalPath, {
    bool enhanceContrast = false,
  }) async {
    final originalFile = File(originalPath);
    if (!await originalFile.exists()) {
      return originalPath;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = p.join(
        tempDir.path,
        'ocr_prep_${DateTime.now().millisecondsSinceEpoch}_${p.basename(originalPath)}',
      );

      final resultPath = await compute(
        _isolatePreprocess,
        _PreprocessParams(
          inputPath: originalPath,
          outputPath: targetPath,
          maxDim: maxDimension,
          quality: defaultQuality,
          enhanceContrast: enhanceContrast,
        ),
      );

      if (resultPath != null && await File(resultPath).exists()) {
        return resultPath;
      }
    } catch (e) {
      debugPrint('[ImagePreprocessor] Preprocessing note (falling back to original): $e');
    }

    return originalPath;
  }

  /// Deletes a temporary preprocessed image file.
  static Future<void> cleanup(String? preprocessedPath, {String? originalPath}) async {
    if (preprocessedPath == null || preprocessedPath == originalPath) return;
    try {
      final file = File(preprocessedPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}

class _PreprocessParams {
  final String inputPath;
  final String outputPath;
  final int maxDim;
  final int quality;
  final bool enhanceContrast;

  const _PreprocessParams({
    required this.inputPath,
    required this.outputPath,
    required this.maxDim,
    required this.quality,
    required this.enhanceContrast,
  });
}

/// Work performed exclusively in a background isolate.
String? _isolatePreprocess(_PreprocessParams params) {
  try {
    final bytes = File(params.inputPath).readAsBytesSync();
    if (bytes.isEmpty) return null;

    img.Image? image = img.decodeImage(bytes);
    if (image == null) return null;

    // 1. Bake in EXIF orientation so vertical receipts are correctly oriented
    image = img.bakeOrientation(image);

    // 2. Downscale if dimensions exceed threshold while preserving aspect ratio
    if (image.width > params.maxDim || image.height > params.maxDim) {
      if (image.width > image.height) {
        image = img.copyResize(image, width: params.maxDim);
      } else {
        image = img.copyResize(image, height: params.maxDim);
      }
    }

    // 3. Contrast & lighting adjustment for faded thermal receipts if requested
    if (params.enhanceContrast) {
      image = img.grayscale(image);
      image = img.contrast(image, contrast: 120);
    }

    // Encode as high-quality JPEG for fastest decoding by ML Kit
    final encoded = img.encodeJpg(image, quality: params.quality);
    final outFile = File(params.outputPath);
    outFile.writeAsBytesSync(encoded, flush: true);
    return params.outputPath;
  } catch (e) {
    debugPrint('[ImagePreprocessor isolate] Processing note: $e');
    return null;
  }
}
