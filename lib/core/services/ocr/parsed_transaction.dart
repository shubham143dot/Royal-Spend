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

  /// Explicit invoice or bill number extracted from receipt header.
  final String? invoiceNumber;

  /// Pre-tax subtotal or taxable amount.
  final double? subtotal;

  /// Total Goods and Services Tax (GST) amount.
  final double? gstAmount;

  /// Central GST amount.
  final double? cgst;

  /// State GST amount.
  final double? sgst;

  /// Integrated GST amount.
  final double? igst;

  /// Applied tax rate percentage (e.g. 5.0 for 5%, 18.0 for 18%).
  final double? taxPercentage;

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
    this.invoiceNumber,
    this.subtotal,
    this.gstAmount,
    this.cgst,
    this.sgst,
    this.igst,
    this.taxPercentage,
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
    String? invoiceNumber,
    double? subtotal,
    double? gstAmount,
    double? cgst,
    double? sgst,
    double? igst,
    double? taxPercentage,
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
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      subtotal: subtotal ?? this.subtotal,
      gstAmount: gstAmount ?? this.gstAmount,
      cgst: cgst ?? this.cgst,
      sgst: sgst ?? this.sgst,
      igst: igst ?? this.igst,
      taxPercentage: taxPercentage ?? this.taxPercentage,
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

  Map<String, dynamic> toMap() {
    return {
      'merchant': merchant,
      'amount': amount,
      'is_income': isIncome,
      'amount_confidence': amountConfidence,
      'amount_status': amountStatus.name,
      'date': date?.millisecondsSinceEpoch,
      'has_confident_date': hasConfidentDate,
      'time_string': timeString,
      'category_id': categoryId,
      'payment_method': paymentMethod.name,
      'reference_id': referenceId,
      'invoice_number': invoiceNumber,
      'subtotal': subtotal,
      'gst_amount': gstAmount,
      'cgst': cgst,
      'sgst': sgst,
      'igst': igst,
      'tax_percentage': taxPercentage,
      'candidate_amounts': candidateAmounts,
      'image_path': imagePath,
      'is_duplicate': isDuplicate,
      'duplicate_reason': duplicateReason,
      'source_type': sourceType,
      'currency_symbol': currencySymbol,
    };
  }

  factory ParsedTransaction.fromMap(Map<String, dynamic> map, {String rawText = ''}) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is num) return DateTime.fromMillisecondsSinceEpoch(val.toInt());
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return ParsedTransaction(
      merchant: map['merchant'] as String?,
      amount: (map['amount'] as num?)?.toDouble(),
      isIncome: map['is_income'] == true,
      amountConfidence: (map['amount_confidence'] as num?)?.toDouble() ?? 0.0,
      amountStatus: AmountExtractionStatus.values.firstWhere(
        (s) => s.name == map['amount_status'],
        orElse: () => AmountExtractionStatus.missing,
      ),
      date: parseDate(map['date']),
      hasConfidentDate: map['has_confident_date'] == true,
      timeString: map['time_string'] as String?,
      categoryId: map['category_id']?.toString() ?? 'other',
      paymentMethod: PaymentMethod.values.firstWhere(
        (p) => p.name == map['payment_method'],
        orElse: () => PaymentMethod.upi,
      ),
      referenceId: map['reference_id'] as String?,
      invoiceNumber: map['invoice_number'] as String?,
      subtotal: (map['subtotal'] as num?)?.toDouble(),
      gstAmount: (map['gst_amount'] as num?)?.toDouble(),
      cgst: (map['cgst'] as num?)?.toDouble(),
      sgst: (map['sgst'] as num?)?.toDouble(),
      igst: (map['igst'] as num?)?.toDouble(),
      taxPercentage: (map['tax_percentage'] as num?)?.toDouble(),
      rawText: rawText.isNotEmpty ? rawText : (map['raw_text'] as String? ?? ''),
      candidateAmounts: (map['candidate_amounts'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [],
      imagePath: map['image_path'] as String?,
      isDuplicate: map['is_duplicate'] == true,
      duplicateReason: map['duplicate_reason'] as String?,
      sourceType: map['source_type'] as String? ?? 'Receipt / Screenshot',
      currencySymbol: map['currency_symbol'] as String? ?? '₹',
    );
  }
}
