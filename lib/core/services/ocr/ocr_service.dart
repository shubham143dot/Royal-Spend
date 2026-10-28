import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Physical spatial line data extracted by on-device OCR, containing text and visual bounding box dimensions.
class OcrLineData {
  final String text;
  final double top;
  final double left;
  final double width;
  final double height;

  const OcrLineData({
    required this.text,
    required this.top,
    required this.left,
    required this.width,
    required this.height,
  });
}

/// Unmodified ML Kit text with physical bounding boxes for recognized lines.
class OcrResult {
  /// Raw transcript from ML Kit, before row reconstruction or parsing.
  final String fullText;
  final List<OcrLineData> lines;

  const OcrResult({required this.fullText, this.lines = const []});
}

/// Abstract contract for OCR text recognition, allowing dependency injection and test mocking.
abstract class IOcrService {
  Future<String> recognizeText(String imagePath);
  Future<OcrResult> processImage(String imagePath);
  void dispose();
}

/// Production implementation using Google ML Kit On-Device Text Recognition.
/// Works 100% offline with zero data sent over the internet and no paid API keys.
class MlKitOcrService implements IOcrService {
  TextRecognizer? _textRecognizer;

  TextRecognizer get _recognizer {
    _textRecognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
    return _textRecognizer!;
  }

  @override
  Future<OcrResult> processImage(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      throw const FileSystemException(
        'Receipt image file does not exist on disk.',
      );
    }

    // Google ML Kit runs on Android and iOS
    if (!kIsWeb && !Platform.isAndroid && !Platform.isIOS) {
      debugPrint(
        '[MlKitOcrService] Google ML Kit native OCR is only available on Android & iOS.',
      );
      throw UnsupportedError(
        'On-device Google ML Kit text recognition is supported on Android and iOS devices.',
      );
    }

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _recognizer.processImage(
        inputImage,
      );

      final List<OcrLineData> rawLines = [];
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          final trimmed = line.text.trim();
          if (trimmed.isNotEmpty) {
            rawLines.add(
              OcrLineData(
                text: trimmed,
                top: line.boundingBox.top.toDouble(),
                left: line.boundingBox.left.toDouble(),
                width: line.boundingBox.width.toDouble(),
                height: line.boundingBox.height.toDouble(),
              ),
            );
          }
        }
      }

      // Cluster lines that share the same horizontal band into natural reading rows
      final ocrLines = _clusterIntoVisualRows(rawLines);

      return OcrResult(
        // Keep ML Kit's original transcript; expose visual row grouping separately.
        fullText: recognizedText.text,
        lines: ocrLines,
      );
    } catch (e) {
      debugPrint('[MlKitOcrService] OCR recognition failed: $e');
      rethrow;
    }
  }

  /// Groups horizontally adjacent OCR text items (e.g. 'TOTAL AMOUNT' and 'Rs. 450.00' or '₹' and '500')
  /// into unified horizontal reading lines while maintaining true visual height and coordinates.
  static List<OcrLineData> _clusterIntoVisualRows(List<OcrLineData> rawLines) {
    if (rawLines.isEmpty) return [];

    // Sort primarily by vertical top coordinate
    final sorted = List<OcrLineData>.from(rawLines)
      ..sort((a, b) => a.top.compareTo(b.top));

    final List<List<OcrLineData>> rows = [];
    for (final line in sorted) {
      bool placed = false;
      for (final row in rows) {
        final rowTop = row.map((l) => l.top).reduce((a, b) => a < b ? a : b);
        final rowBottom = row
            .map((l) => l.top + l.height)
            .reduce((a, b) => a > b ? a : b);
        final lineBottom = line.top + line.height;

        final overlapTop = line.top > rowTop ? line.top : rowTop;
        final overlapBottom = lineBottom < rowBottom ? lineBottom : rowBottom;
        final overlap = overlapBottom - overlapTop;

        final rowHeight = rowBottom - rowTop;
        final minHeight = line.height < rowHeight ? line.height : rowHeight;

        // If elements overlap vertically by at least 40% of the shorter line's height
        if (overlap > 0 && overlap >= minHeight * 0.40) {
          row.add(line);
          placed = true;
          break;
        }
      }
      if (!placed) {
        rows.add([line]);
      }
    }

    // In each row, sort elements left-to-right, then compute bounding box
    final List<OcrLineData> clustered = [];
    for (final row in rows) {
      row.sort((a, b) => a.left.compareTo(b.left));

      final text = row.map((l) => l.text).join('   ');
      final top = row.map((l) => l.top).reduce((a, b) => a < b ? a : b);
      final left = row.map((l) => l.left).reduce((a, b) => a < b ? a : b);
      final maxBottom = row
          .map((l) => l.top + l.height)
          .reduce((a, b) => a > b ? a : b);
      final maxRight = row
          .map((l) => l.left + l.width)
          .reduce((a, b) => a > b ? a : b);

      clustered.add(
        OcrLineData(
          text: text,
          top: top,
          left: left,
          width: maxRight - left,
          height: maxBottom - top,
        ),
      );
    }

    // Final top-to-bottom sort
    clustered.sort((a, b) => a.top.compareTo(b.top));
    return clustered;
  }

  @override
  Future<String> recognizeText(String imagePath) async {
    final result = await processImage(imagePath);
    return result.fullText;
  }

  @override
  void dispose() {
    _textRecognizer?.close();
    _textRecognizer = null;
  }
}
