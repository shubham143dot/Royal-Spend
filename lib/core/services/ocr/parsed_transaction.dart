import 'package:royal_spend/data/models/expense.dart';

enum AmountExtractionStatus { extracted, missing, invalid, ambiguous }

/// Represents the structured data extracted from an expense receipt or UPI screenshot.
class ParsedTransaction {
  /// Identified merchant, store, or payee name.
  final String? merchant;

  /// Primary identified transaction amount.
  final double? amount;

  /// True when the document explicitly describes incoming funds or a refund.
  final bool isIncome;

  /// Heuristic reliability score (0.0 to 1.0), not an ML Kit confidence value
  /// or calibrated probability.
  final double amountConfidence;

  /// Whether the parser selected an amount or needs user input.
  final AmountExtractionStatus amountStatus;

  /// Identified transaction date.
  final DateTime? date;

  /// Whether the date was identified with high confidence from the receipt.
  final bool hasConfidentDate;

  /// Optional identified time string (e.g. "10:45 AM").
  final String? timeString;

  /// Suggested expense category ID from [DefaultCategories].
  final String categoryId;

  /// Identified or inferred payment method.
  final PaymentMethod paymentMethod;

  /// UPI Reference number, UTR, or invoice/bill number if found.
  final String? referenceId;

  /// Full raw OCR text extracted from the image.
  final String rawText;

  /// List of alternative amounts detected in the document (useful for ambiguity resolution).
  final List<double> candidateAmounts;

  /// File path to the processed image on disk.
  final String? imagePath;

  /// Whether a possible duplicate was detected in the existing expense database.
  final bool isDuplicate;

  /// The existing matching expense if a duplicate was detected.
  final Expense? duplicateExpense;

  /// Human-readable explanation if a duplicate is flagged.
  final String? duplicateReason;

  /// Identified source type (e.g. "PhonePe UPI", "Google Pay", "Paytm", "Store Receipt").
  final String sourceType;

  /// Identified or inferred currency symbol ('₹', '$', '€', '£').
  final String currencySymbol;

  const ParsedTransaction({
    this.merchant,
    this.amount,
    this.isIncome = false,
    this.amountConfidence = 0.0,
    this.amountStatus = AmountExtractionStatus.missing,
    this.date,
    this.hasConfidentDate = false,
    this.timeString,
    required this.categoryId,
    this.paymentMethod = PaymentMethod.upi,
    this.referenceId,
    required this.rawText,
    this.candidateAmounts = const [],
    this.imagePath,
    this.isDuplicate = false,
    this.duplicateExpense,
    this.duplicateReason,
    this.sourceType = 'Receipt / Screenshot',
    this.currencySymbol = '₹',
  });

  /// Whether the detected amount is ambiguous (e.g. amount is null but candidates exist,
  /// or multiple valid candidates exist with close confidence scores).
  bool get isAmbiguous =>
      amountStatus == AmountExtractionStatus.ambiguous ||
      (amount == null && candidateAmounts.isNotEmpty);

  ParsedTransaction copyWith({
    String? merchant,
    double? amount,
    bool? isIncome,
    double? amountConfidence,
    AmountExtractionStatus? amountStatus,
    DateTime? date,
    bool? hasConfidentDate,
    String? timeString,
    String? categoryId,
    PaymentMethod? paymentMethod,
    String? referenceId,
    String? rawText,
    List<double>? candidateAmounts,
    String? imagePath,
    bool? isDuplicate,
    Expense? duplicateExpense,
    String? duplicateReason,
    String? sourceType,
    String? currencySymbol,
  }) {
    return ParsedTransaction(
      merchant: merchant ?? this.merchant,
      amount: amount ?? this.amount,
      isIncome: isIncome ?? this.isIncome,
      amountConfidence: amountConfidence ?? this.amountConfidence,
      amountStatus: amountStatus ?? this.amountStatus,
      date: date ?? this.date,
      hasConfidentDate: hasConfidentDate ?? this.hasConfidentDate,
      timeString: timeString ?? this.timeString,
      categoryId: categoryId ?? this.categoryId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      referenceId: referenceId ?? this.referenceId,
      rawText: rawText ?? this.rawText,
      candidateAmounts: candidateAmounts ?? this.candidateAmounts,
      imagePath: imagePath ?? this.imagePath,
      isDuplicate: isDuplicate ?? this.isDuplicate,
      duplicateExpense: duplicateExpense ?? this.duplicateExpense,
      duplicateReason: duplicateReason ?? this.duplicateReason,
      sourceType: sourceType ?? this.sourceType,
      currencySymbol: currencySymbol ?? this.currencySymbol,
    );
  }
}
