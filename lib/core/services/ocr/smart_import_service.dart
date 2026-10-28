import 'package:royal_spend/data/models/expense.dart';
import 'duplicate_detector.dart';
import 'image_picker_service.dart';
import 'ocr_service.dart';
import 'parsed_transaction.dart';
import 'receipt_parser.dart';

/// Orchestrates the entire Smart Import workflow: image selection, on-device OCR,
/// heuristic transaction parsing, and duplicate transaction checking.
class SmartImportService {
  final IOcrService _ocrService;
  final ImagePickerService _pickerService;

  SmartImportService({
    IOcrService? ocrService,
    ImagePickerService? pickerService,
  })  : _ocrService = ocrService ?? MlKitOcrService(),
        _pickerService = pickerService ?? ImagePickerService();

  ImagePickerService get picker => _pickerService;
  IOcrService get ocr => _ocrService;

  /// Processes an image from [imagePath] using on-device OCR and parsing heuristics,
  /// then cross-references [existingExpenses] for potential duplicates.
  Future<ParsedTransaction> processReceiptImage(
    String imagePath,
    List<Expense> existingExpenses,
  ) async {
    try {
      final ocrResult = await _ocrService.processImage(imagePath);
      final parsed = ReceiptParser.parse(
        ocrResult.fullText,
        imagePath: imagePath,
        ocrLines: ocrResult.lines,
      );
      final withDuplicateCheck = DuplicateDetector.checkDuplicate(parsed, existingExpenses);
      return withDuplicateCheck;
    } catch (e) {
      // Gracefully return a parsed transaction with the error noted so user can fall back to manual edit
      return ParsedTransaction(
        categoryId: 'other',
        rawText: '',
        imagePath: imagePath,
        duplicateReason: 'OCR scan note: $e',
      );
    }
  }

  void dispose() {
    _ocrService.dispose();
  }
}
